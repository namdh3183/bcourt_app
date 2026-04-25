import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/report_reasons.dart';
import '../../../models/booking_model.dart';
import '../../../models/report_model.dart';
import '../../../models/user_model.dart';
import '../../../services/database_service.dart';

class ReportSubmissionScreen extends StatefulWidget {
  final BookingModel booking;
  final UserModel reporter;       // người đang đăng nhập (người báo cáo)
  final UserModel reportedUser;   // người bị báo cáo
  final String reporterRole;      // 'customer' | 'owner'

  const ReportSubmissionScreen({
    super.key,
    required this.booking,
    required this.reporter,
    required this.reportedUser,
    required this.reporterRole,
  });

  @override
  State<ReportSubmissionScreen> createState() => _ReportSubmissionScreenState();
}

class _ReportSubmissionScreenState extends State<ReportSubmissionScreen> {
  final _formKey = GlobalKey<FormState>();
  final DatabaseService _dbService = DatabaseService();
  final ImagePicker _picker = ImagePicker();

  String? _selectedReason;
  final _descriptionController = TextEditingController();
  File? _evidenceImage;
  bool _isLoading = false;

  final Color primaryPurple = const Color(0xFFBF89F5);

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Map<String, String> get _reasonOptions {
    return widget.reporterRole == 'owner'
        ? ReportReasons.forCustomer
        : ReportReasons.forOwner;
  }

  Future<void> _pickEvidenceImage() async {
    final XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );
    if (pickedFile != null) {
      setState(() {
        _evidenceImage = File(pickedFile.path);
      });
    }
  }

  void _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    // Kiểm tra đã báo cáo booking này chưa
    bool isDuplicate = await _dbService.hasReportedBooking(
      widget.reporter.uid,
      widget.booking.id,
    );

    if (isDuplicate) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bạn đã báo cáo booking này rồi!'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    ReportModel report = ReportModel(
      id: '',
      reporterId: widget.reporter.uid,
      reporterRole: widget.reporterRole,
      reportedUserId: widget.reportedUser.uid,
      reportedUserRole: widget.reporterRole == 'owner' ? 'customer' : 'owner',
      bookingId: widget.booking.id,
      reason: _selectedReason!,
      description: _descriptionController.text.trim(),
      createdAt: Timestamp.now(),
    );

    String result = await _dbService.createReport(
      report,
      evidenceImage: _evidenceImage,
    );

    setState(() => _isLoading = false);

    if (!mounted) return;

    if (result == 'success') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã gửi báo cáo. Admin sẽ xem xét và xử lý.'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    } else if (result == 'duplicate') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bạn đã báo cáo booking này rồi!'),
          backgroundColor: Colors.red,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lỗi hệ thống, vui lòng thử lại!'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Gửi báo cáo vi phạm',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: primaryPurple,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // PHẦN A: Thông tin booking liên quan
              _buildSectionLabel('Thông tin booking liên quan'),
              _buildBookingCard(),
              const SizedBox(height: 8),
              _buildReportedUserCard(),
              const SizedBox(height: 20),

              // PHẦN B: Lý do báo cáo
              _buildSectionLabel('Lý do báo cáo *'),
              _buildCard(
                child: DropdownButtonFormField<String>(
                  value: _selectedReason,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Chọn lý do',
                    hintStyle: TextStyle(color: Colors.grey),
                  ),
                  items: _reasonOptions.entries.map((entry) {
                    return DropdownMenuItem<String>(
                      value: entry.key,
                      child: Text(entry.value, style: const TextStyle(fontSize: 14)),
                    );
                  }).toList(),
                  onChanged: (value) => setState(() => _selectedReason = value),
                  validator: (value) =>
                      value == null ? 'Vui lòng chọn lý do báo cáo' : null,
                ),
              ),
              const SizedBox(height: 20),

              // PHẦN C: Mô tả chi tiết
              _buildSectionLabel('Mô tả chi tiết *'),
              _buildCard(
                child: TextFormField(
                  controller: _descriptionController,
                  maxLines: 5,
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Mô tả cụ thể sự việc, thời gian, hậu quả...',
                    hintStyle: TextStyle(color: Colors.grey[400]),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().length < 20) {
                      return 'Mô tả phải có ít nhất 20 ký tự';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(height: 20),

              // PHẦN D: Ảnh bằng chứng (tuỳ chọn)
              _buildSectionLabel('Ảnh bằng chứng (tuỳ chọn)'),
              _buildCard(child: _buildEvidenceUpload()),
              const SizedBox(height: 32),

              // PHẦN E: Nút gửi
              _isLoading
                  ? Center(child: CircularProgressIndicator(color: primaryPurple))
                  : ElevatedButton.icon(
                      onPressed: _handleSubmit,
                      icon: const Icon(Icons.send, color: Colors.white),
                      label: const Text(
                        'GỬI BÁO CÁO',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryPurple,
                        minimumSize: const Size(double.infinity, 55),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'Báo cáo sẽ được admin xem xét trong vòng 24h',
                  style: TextStyle(color: Colors.grey[500], fontSize: 13),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // ---- WIDGET: Tóm tắt booking ----
  Widget _buildBookingCard() {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.receipt_long, color: primaryPurple, size: 20),
              const SizedBox(width: 8),
              Text(
                'Chi tiết booking',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: primaryPurple,
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          _buildInfoRow('Ngày chơi:', DateFormat('dd/MM/yyyy').format(widget.booking.bookingDate.toDate())),
          _buildInfoRow(
            'Giờ:',
            '${DateFormat('HH:mm').format(widget.booking.startTime.toDate())} - ${DateFormat('HH:mm').format(widget.booking.endTime.toDate())}',
          ),
          _buildInfoRow('Sân con:', widget.booking.subCourtName),
          _buildInfoRow('Tổng tiền:', '${widget.booking.totalPrice.toStringAsFixed(0)} VNĐ'),
        ],
      ),
    );
  }

  // ---- WIDGET: Thông tin người bị báo cáo ----
  Widget _buildReportedUserCard() {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.person, color: Colors.deepOrange, size: 20),
              const SizedBox(width: 8),
              Text(
                widget.reporterRole == 'owner' ? 'Khách hàng bị báo cáo' : 'Chủ sân bị báo cáo',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: Colors.deepOrange,
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          _buildInfoRow('Tên:', widget.reportedUser.fullName),
          _buildInfoRow('SĐT:', widget.reportedUser.phone.isNotEmpty ? widget.reportedUser.phone : 'Không có'),
        ],
      ),
    );
  }

  // ---- WIDGET: Upload ảnh bằng chứng ----
  Widget _buildEvidenceUpload() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Chọn ảnh từ thư viện để làm bằng chứng (không bắt buộc)',
          style: TextStyle(color: Colors.grey[600], fontSize: 13),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: _pickEvidenceImage,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: double.infinity,
            height: _evidenceImage != null ? 200 : 110,
            decoration: BoxDecoration(
              color: _evidenceImage != null ? Colors.transparent : Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _evidenceImage != null ? Colors.deepOrange : Colors.grey[300]!,
                width: 2,
              ),
            ),
            child: _evidenceImage != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.file(_evidenceImage!, fit: BoxFit.cover),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.all(5),
                            decoration: const BoxDecoration(
                              color: Colors.deepOrange,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.check, color: Colors.white, size: 16),
                          ),
                        ),
                      ],
                    ),
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_photo_alternate, size: 40, color: Colors.grey[400]),
                      const SizedBox(height: 8),
                      Text(
                        'Nhấn để chọn ảnh bằng chứng',
                        style: TextStyle(color: Colors.grey[500], fontSize: 14),
                      ),
                    ],
                  ),
          ),
        ),
        if (_evidenceImage != null) ...[
          const SizedBox(height: 8),
          Center(
            child: TextButton.icon(
              onPressed: _pickEvidenceImage,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Chọn ảnh khác'),
            ),
          ),
        ],
      ],
    );
  }

  // ---- HELPER WIDGETS ----

  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: child,
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
        ],
      ),
    );
  }
}
