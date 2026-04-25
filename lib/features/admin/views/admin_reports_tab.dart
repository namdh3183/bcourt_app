import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../../models/report_model.dart';
import '../../../models/user_model.dart';
import '../../../models/booking_model.dart';
import '../../../models/court_model.dart';
import '../../../services/database_service.dart';
import '../../../core/constants/report_reasons.dart';

class AdminReportsTab extends StatefulWidget {
  const AdminReportsTab({super.key});

  @override
  State<AdminReportsTab> createState() => _AdminReportsTabState();
}

class _AdminReportsTabState extends State<AdminReportsTab> {
  final DatabaseService _dbService = DatabaseService();
  ReportModel? _selectedReport;
  String _filterStatus = 'all';

  static const Color primaryPurple = Color(0xFFBF89F5);

  List<ReportModel> _applyFilter(List<ReportModel> reports) {
    if (_filterStatus == 'pending') {
      return reports.where((r) => r.status == 'pending').toList();
    }
    if (_filterStatus == 'resolved') {
      return reports.where((r) => r.status != 'pending').toList();
    }
    return reports;
  }

  String _getBadgeText(ReportModel report) {
    final from = report.reporterRole == 'owner' ? 'Owner' : 'Customer';
    final to = report.reportedUserRole == 'owner' ? 'Owner' : 'Customer';
    return '$from→$to';
  }

  String _formatDateTime(dynamic ts) {
    if (ts == null) return '';
    return DateFormat('HH:mm dd/MM/yyyy').format(ts.toDate());
  }

  String _formatDateOnly(dynamic ts) {
    if (ts == null) return '';
    return DateFormat('dd/MM/yyyy').format(ts.toDate());
  }

  String _formatTimeOnly(dynamic ts) {
    if (ts == null) return '';
    return DateFormat('HH:mm').format(ts.toDate());
  }

  String _getReasonText(ReportModel report) {
    if (report.reportedUserRole == 'customer') {
      return ReportReasons.forCustomer[report.reason] ?? report.reason;
    }
    return ReportReasons.forOwner[report.reason] ?? report.reason;
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'resolved_warning':
        return 'Đã cảnh báo';
      case 'resolved_banned_temp':
        return 'Đã ban tạm thời';
      case 'resolved_banned_permanent':
        return 'Đã ban vĩnh viễn';
      case 'rejected':
        return 'Đã bỏ qua';
      default:
        return status;
    }
  }

  Future<Map<String, dynamic>?> _fetchBookingWithCourt(String bookingId) async {
    final booking = await _dbService.getBookingById(bookingId);
    if (booking == null) return null;
    final court = await _dbService.getCourtById(booking.courtId);
    return {'booking': booking, 'court': court};
  }

  // ---- Dialogs ----

  Future<void> _showWarningDialog(ReportModel report) async {
    final noteController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Gửi cảnh báo'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: noteController,
            decoration: const InputDecoration(
              labelText: 'Ghi chú admin',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Vui lòng nhập ghi chú' : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
            onPressed: () {
              if (formKey.currentState!.validate()) Navigator.pop(ctx, true);
            },
            child: const Text('Xác nhận', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final adminId = FirebaseAuth.instance.currentUser?.uid ?? '';
      final ok = await _dbService.resolveReport(
        reportId: report.id,
        newReportStatus: 'resolved_warning',
        reportedUserId: report.reportedUserId,
        adminNote: noteController.text.trim(),
        adminId: adminId,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(ok ? 'Đã gửi cảnh báo thành công' : 'Có lỗi xảy ra, vui lòng thử lại'),
          backgroundColor: ok ? Colors.green : Colors.red,
        ));
        if (ok) setState(() => _selectedReport = null);
      }
    }
    noteController.dispose();
  }

  Future<void> _showBanTempDialog(ReportModel report) async {
    final banReasonController = TextEditingController();
    final noteController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ban tài khoản 7 ngày'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: banReasonController,
                decoration: const InputDecoration(
                  labelText: 'Lý do ban (hiển thị cho người dùng)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Vui lòng nhập lý do ban' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: noteController,
                decoration: const InputDecoration(
                  labelText: 'Ghi chú admin (tuỳ chọn)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () {
              if (formKey.currentState!.validate()) Navigator.pop(ctx, true);
            },
            child: const Text('Xác nhận ban', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final adminId = FirebaseAuth.instance.currentUser?.uid ?? '';
      final note = noteController.text.trim();
      final ok = await _dbService.resolveReport(
        reportId: report.id,
        newReportStatus: 'resolved_banned_temp',
        reportedUserId: report.reportedUserId,
        banReason: banReasonController.text.trim(),
        adminNote: note.isEmpty ? null : note,
        banDays: 7,
        adminId: adminId,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(ok ? 'Đã ban tài khoản 7 ngày thành công' : 'Có lỗi xảy ra, vui lòng thử lại'),
          backgroundColor: ok ? Colors.green : Colors.red,
        ));
        if (ok) setState(() => _selectedReport = null);
      }
    }
    banReasonController.dispose();
    noteController.dispose();
  }

  Future<void> _showBanPermanentDialog(ReportModel report) async {
    final banReasonController = TextEditingController();
    final noteController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.red),
            SizedBox(width: 8),
            Text('Ban vĩnh viễn', style: TextStyle(color: Colors.red)),
          ],
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Hành động không thể hoàn tác',
                        style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: banReasonController,
                decoration: const InputDecoration(
                  labelText: 'Lý do ban (hiển thị cho người dùng)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Vui lòng nhập lý do ban' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: noteController,
                decoration: const InputDecoration(
                  labelText: 'Ghi chú admin (tuỳ chọn)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              if (formKey.currentState!.validate()) Navigator.pop(ctx, true);
            },
            child: const Text('Ban vĩnh viễn', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final adminId = FirebaseAuth.instance.currentUser?.uid ?? '';
      final note = noteController.text.trim();
      final ok = await _dbService.resolveReport(
        reportId: report.id,
        newReportStatus: 'resolved_banned_permanent',
        reportedUserId: report.reportedUserId,
        banReason: banReasonController.text.trim(),
        adminNote: note.isEmpty ? null : note,
        adminId: adminId,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(ok ? 'Đã ban vĩnh viễn tài khoản thành công' : 'Có lỗi xảy ra, vui lòng thử lại'),
          backgroundColor: ok ? Colors.green : Colors.red,
        ));
        if (ok) setState(() => _selectedReport = null);
      }
    }
    banReasonController.dispose();
    noteController.dispose();
  }

  Future<void> _showRejectDialog(ReportModel report) async {
    final noteController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Bỏ qua báo cáo này?'),
        content: TextFormField(
          controller: noteController,
          decoration: const InputDecoration(
            labelText: 'Lý do bỏ qua (tuỳ chọn)',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Bỏ qua', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final adminId = FirebaseAuth.instance.currentUser?.uid ?? '';
      final note = noteController.text.trim();
      final ok = await _dbService.resolveReport(
        reportId: report.id,
        newReportStatus: 'rejected',
        reportedUserId: report.reportedUserId,
        adminNote: note.isEmpty ? null : note,
        adminId: adminId,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(ok ? 'Đã bỏ qua báo cáo thành công' : 'Có lỗi xảy ra, vui lòng thử lại'),
          backgroundColor: ok ? Colors.green : Colors.red,
        ));
        if (ok) setState(() => _selectedReport = null);
      }
    }
    noteController.dispose();
  }

  void _showImageZoom(String imageUrl) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(24),
        child: Stack(
          children: [
            InteractiveViewer(
              child: Image.network(imageUrl, fit: BoxFit.contain),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                onPressed: () => Navigator.pop(ctx),
                icon: const Icon(Icons.close, color: Colors.white),
                style: IconButton.styleFrom(backgroundColor: Colors.black54),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---- UI helpers ----

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 4),
      child: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
    );
  }

  Widget _infoRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(label, style: TextStyle(color: Colors.grey[600])),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontWeight: FontWeight.w500, color: valueColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: child,
    );
  }

  // ---- Detail sections ----

  Widget _buildSectionA(ReportModel report) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('Thông tin báo cáo'),
          _infoRow('Ngày báo cáo:', _formatDateTime(report.createdAt)),
          _infoRow('Lý do:', _getReasonText(report)),
          _infoRow('Mô tả:', report.description),
          if (report.evidenceImageUrl != null) ...[
            const SizedBox(height: 10),
            Text('Ảnh bằng chứng:', style: TextStyle(color: Colors.grey[600])),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => _showImageZoom(report.evidenceImageUrl!),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  report.evidenceImageUrl!,
                  height: 160,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 160,
                    color: Colors.grey[200],
                    child: const Center(child: Icon(Icons.broken_image)),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionB(ReportModel report) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('Người báo cáo'),
          FutureBuilder<UserModel?>(
            future: _dbService.getUserById(report.reporterId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final user = snapshot.data;
              if (user == null) return const Text('Không tìm thấy thông tin người báo cáo');
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _infoRow('Tên:', user.fullName),
                  _infoRow('Email:', user.email),
                  _infoRow('Số điện thoại:', user.phone),
                  _infoRow('Vai trò:', user.role == 'owner' ? 'Chủ sân' : 'Khách hàng'),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSectionC(ReportModel report) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('Người bị báo cáo'),
          FutureBuilder<UserModel?>(
            future: _dbService.getUserById(report.reportedUserId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final user = snapshot.data;
              if (user == null) return const Text('Không tìm thấy thông tin người bị báo cáo');

              Color statusColor = user.status == 'active' ? Colors.green : Colors.red;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _infoRow('Tên:', user.fullName),
                  _infoRow('Email:', user.email),
                  _infoRow('Số điện thoại:', user.phone),
                  _infoRow('Vai trò:', user.role == 'owner' ? 'Chủ sân' : 'Khách hàng'),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Lịch sử vi phạm',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Đã bị báo cáo ${user.reportCount} lần, bị cảnh báo ${user.warningCount} lần',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  _infoRow('Trạng thái:', user.status, valueColor: statusColor),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSectionD(ReportModel report) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('Booking liên quan'),
          FutureBuilder<Map<String, dynamic>?>(
            future: _fetchBookingWithCourt(report.bookingId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.data == null) {
                return const Text('Không tìm thấy thông tin đặt sân');
              }
              final booking = snapshot.data!['booking'] as BookingModel;
              final court = snapshot.data!['court'] as CourtModel?;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _infoRow('Tên sân:', court?.name ?? booking.courtId),
                  _infoRow('Sân con:', booking.subCourtName),
                  _infoRow('Ngày đặt:', _formatDateOnly(booking.bookingDate)),
                  _infoRow(
                    'Khung giờ:',
                    '${_formatTimeOnly(booking.startTime)} - ${_formatTimeOnly(booking.endTime)}',
                  ),
                  _infoRow('Trạng thái:', booking.bookingStatus),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSectionE(ReportModel report) {
    if (report.status != 'pending') {
      return _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeader('Kết quả xử lý'),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Đã xử lý: ${_statusLabel(report.status)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  if (report.adminNote != null && report.adminNote!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text('Ghi chú: ${report.adminNote}',
                        style: TextStyle(color: Colors.grey[700])),
                  ],
                  if (report.resolvedAt != null) ...[
                    const SizedBox(height: 4),
                    Text('Thời gian xử lý: ${_formatDateTime(report.resolvedAt)}',
                        style: TextStyle(color: Colors.grey[700])),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
    }

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('Hành động xử lý'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                onPressed: () => _showRejectDialog(report),
                style: OutlinedButton.styleFrom(foregroundColor: Colors.grey[700]),
                child: const Text('Bỏ qua'),
              ),
              ElevatedButton(
                onPressed: () => _showWarningDialog(report),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
                child: const Text('Cảnh báo', style: TextStyle(color: Colors.white)),
              ),
              ElevatedButton(
                onPressed: () => _showBanTempDialog(report),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                child: const Text('Ban 7 ngày', style: TextStyle(color: Colors.white)),
              ),
              ElevatedButton(
                onPressed: () => _showBanPermanentDialog(report),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Ban vĩnh viễn', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailContent(ReportModel report) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.assignment, size: 22),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Chi tiết báo cáo',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: report.status == 'pending'
                      ? Colors.orange.shade100
                      : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  report.status == 'pending' ? 'Chờ xử lý' : _statusLabel(report.status),
                  style: TextStyle(
                    color: report.status == 'pending'
                        ? Colors.orange.shade800
                        : Colors.grey[700],
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildSectionA(report),
          _buildSectionB(report),
          _buildSectionC(report),
          _buildSectionD(report),
          _buildSectionE(report),
        ],
      ),
    );
  }

  // ---- Main build ----

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Panel trái — danh sách báo cáo
        Expanded(
          flex: 2,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Danh sách báo cáo',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        children: [
                          FilterChip(
                            label: const Text('Tất cả'),
                            selected: _filterStatus == 'all',
                            onSelected: (_) =>
                                setState(() => _filterStatus = 'all'),
                            selectedColor: primaryPurple.withOpacity(0.25),
                          ),
                          FilterChip(
                            label: const Text('Chờ xử lý'),
                            selected: _filterStatus == 'pending',
                            onSelected: (_) =>
                                setState(() => _filterStatus = 'pending'),
                            selectedColor: Colors.orange.withOpacity(0.25),
                          ),
                          FilterChip(
                            label: const Text('Đã xử lý'),
                            selected: _filterStatus == 'resolved',
                            onSelected: (_) =>
                                setState(() => _filterStatus = 'resolved'),
                            selectedColor: Colors.green.withOpacity(0.25),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: StreamBuilder<List<ReportModel>>(
                    stream: _dbService.getAllReportsStream(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final reports = _applyFilter(snapshot.data!);
                      if (reports.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.inbox, size: 48, color: Colors.grey[400]),
                              const SizedBox(height: 8),
                              Text(
                                'Không có báo cáo nào',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        );
                      }
                      return ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: reports.length,
                        itemBuilder: (context, index) {
                          final report = reports[index];
                          final isPending = report.status == 'pending';
                          final isSelected = _selectedReport?.id == report.id;
                          return Card(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 4),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: BorderSide(
                                color: isSelected
                                    ? primaryPurple
                                    : isPending
                                        ? Colors.orange.shade300
                                        : Colors.grey.shade300,
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap: () =>
                                  setState(() => _selectedReport = report),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: isPending
                                                ? Colors.orange.shade100
                                                : Colors.grey.shade200,
                                            borderRadius:
                                                BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            _getBadgeText(report),
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: isPending
                                                  ? Colors.orange.shade800
                                                  : Colors.grey[700],
                                            ),
                                          ),
                                        ),
                                        Text(
                                          _formatDateTime(report.createdAt),
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey[600]),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      _getReasonText(report),
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      report.description,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                          color: Colors.grey[700], fontSize: 13),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        // Panel phải — chi tiết
        Expanded(
          flex: 3,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: _selectedReport == null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.assignment_outlined,
                            size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          'Chọn một báo cáo để xem chi tiết',
                          style:
                              TextStyle(color: Colors.grey[600], fontSize: 15),
                        ),
                      ],
                    ),
                  )
                : KeyedSubtree(
                    key: ValueKey(_selectedReport!.id),
                    child: _buildDetailContent(_selectedReport!),
                  ),
          ),
        ),
      ],
    );
  }
}
