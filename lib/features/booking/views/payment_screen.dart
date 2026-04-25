import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../../models/court_model.dart';
import '../../../models/booking_model.dart';
import '../../../models/user_model.dart';
import '../../../services/database_service.dart';
import 'booking_success_screen.dart';

class PaymentScreen extends StatefulWidget {
  final CourtModel court;
  final BookingModel booking;
  final UserModel customer;
  final String bookingId;

  const PaymentScreen({
    super.key,
    required this.court,
    required this.booking,
    required this.customer,
    required this.bookingId,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final DatabaseService _dbService = DatabaseService();
  final ImagePicker _picker = ImagePicker();

  File? _billImage;
  bool _isLoading = false;

  late Timer _countdownTimer;
  int _remainingSeconds = 300; // 5 phút

  final Color primaryPurple = const Color(0xFFBF89F5);

  double get _depositAmount => widget.booking.totalPrice * 0.3;

  bool get _hasBankInfo =>
      (widget.court.bankName?.isNotEmpty ?? false) &&
      (widget.court.bankAccountNumber?.isNotEmpty ?? false) &&
      (widget.court.bankAccountName?.isNotEmpty ?? false);

  String get _transferContent =>
      'BCOURT ${widget.customer.fullName.split(' ').last.toUpperCase()} ${DateFormat('ddMM').format(widget.booking.bookingDate.toDate())}';

  @override
  void initState() {
    super.initState();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() => _remainingSeconds--);
      if (_remainingSeconds <= 0) {
        timer.cancel();
        _handleTimeout();
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer.cancel();
    super.dispose();
  }

  void _handleTimeout() async {
    await _dbService.autoCancelExpiredUnpaidBooking(widget.bookingId);
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          title: const Text('Hết thời gian'),
          content: const Text('Bạn đã quá 5 phút chưa upload bill. Lịch đặt đã bị hủy tự động.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.popUntil(context, (r) => r.isFirst),
              child: const Text('Về trang chủ'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _pickBillImage() async {
    final XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );
    if (pickedFile != null) {
      setState(() => _billImage = File(pickedFile.path));
    }
  }

  void _handleConfirmPayment() async {
    if (_billImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chụp/chọn ảnh bill chuyển khoản!'), backgroundColor: Colors.red),
      );
      return;
    }
    if (_remainingSeconds <= 0) return;

    setState(() => _isLoading = true);

    String? proofUrl = await _dbService.uploadDepositProof(_billImage!, widget.customer.uid);

    if (proofUrl == null) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lỗi upload ảnh. Vui lòng thử lại!'), backgroundColor: Colors.red),
        );
      }
      return;
    }

    bool ok = await _dbService.updateBookingPayment(widget.bookingId, 'deposit_paid', proofUrl);

    setState(() => _isLoading = false);

    if (ok && mounted) {
      _countdownTimer.cancel();

      BookingModel updatedBooking = BookingModel(
        id: widget.bookingId,
        customerId: widget.booking.customerId,
        courtId: widget.booking.courtId,
        subCourtName: widget.booking.subCourtName,
        bookingDate: widget.booking.bookingDate,
        startTime: widget.booking.startTime,
        endTime: widget.booking.endTime,
        totalPrice: widget.booking.totalPrice,
        paymentStatus: 'deposit_paid',
        bookingStatus: 'pending',
        createdAt: widget.booking.createdAt,
        depositProofImageUrl: proofUrl,
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => BookingSuccessScreen(
            court: widget.court,
            booking: updatedBooking,
            customer: widget.customer,
          ),
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lỗi cập nhật thanh toán. Vui lòng thử lại!'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Thanh toán đặt cọc', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: primaryPurple,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildCountdownBanner(),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _buildSummaryCard(),
                  const SizedBox(height: 20),
                  _hasBankInfo ? _buildBankInfoCard() : _buildNoBankInfoCard(),
                  const SizedBox(height: 20),
                  _buildUploadBillCard(),
                  const SizedBox(height: 32),
                  _isLoading
                      ? CircularProgressIndicator(color: primaryPurple)
                      : ElevatedButton(
                          onPressed: (_isLoading || !_hasBankInfo || _remainingSeconds <= 0)
                              ? null
                              : _handleConfirmPayment,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryPurple,
                            disabledBackgroundColor: Colors.grey[300],
                            minimumSize: const Size(double.infinity, 55),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text(
                            'XÁC NHẬN ĐÃ CHUYỂN KHOẢN',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ),
                  const SizedBox(height: 12),
                  Text(
                    'Lịch sẽ được chủ sân duyệt sau khi xác nhận ảnh bill',
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCountdownBanner() {
    final mm = (_remainingSeconds ~/ 60).toString().padLeft(2, '0');
    final ss = (_remainingSeconds % 60).toString().padLeft(2, '0');
    final Color bannerColor = _remainingSeconds < 60
        ? Colors.red
        : _remainingSeconds < 180
            ? Colors.orange
            : Colors.orange.shade700;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: bannerColor.withOpacity(0.12),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.timer, color: bannerColor, size: 20),
              const SizedBox(width: 6),
              Text(
                'Thời gian còn lại: $mm:$ss',
                style: TextStyle(fontWeight: FontWeight.bold, color: bannerColor, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Vui lòng hoàn tất chuyển khoản và upload bill trong 5 phút. Quá thời gian, lịch sẽ bị hủy tự động.',
            style: TextStyle(color: bannerColor, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ---- WIDGET: Tóm tắt đặt sân ----
  Widget _buildSummaryCard() {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardHeader(Icons.receipt_long, 'Tóm tắt đặt sân', primaryPurple),
          const Divider(height: 24),
          _buildInfoRow('Sân:', widget.court.name),
          _buildInfoRow('Vị trí:', widget.booking.subCourtName),
          _buildInfoRow('Ngày:', DateFormat('dd/MM/yyyy').format(widget.booking.bookingDate.toDate())),
          _buildInfoRow(
            'Giờ chơi:',
            '${DateFormat('HH:mm').format(widget.booking.startTime.toDate())} - ${DateFormat('HH:mm').format(widget.booking.endTime.toDate())}',
          ),
          const Divider(height: 24),
          _buildInfoRow('Tổng tiền:', '${widget.booking.totalPrice.toStringAsFixed(0)} VNĐ'),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: primaryPurple.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: primaryPurple.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Tiền cọc cần chuyển', style: TextStyle(fontSize: 13, color: Colors.grey)),
                    Text('(30% tổng tiền)', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
                Text(
                  '${_depositAmount.toStringAsFixed(0)} VNĐ',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: primaryPurple),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoBankInfoCard() {
    return _buildCard(
      child: Column(
        children: [
          _buildCardHeader(Icons.account_balance, 'Thông tin chuyển khoản', Colors.grey),
          const Divider(height: 24),
          const Icon(Icons.warning_amber_rounded, size: 48, color: Colors.orange),
          const SizedBox(height: 12),
          const Text('Chủ sân chưa cập nhật thông tin thanh toán.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15), textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text('Vui lòng liên hệ chủ sân hoặc thử lại sau.', style: TextStyle(color: Colors.grey[600], fontSize: 13), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildBankInfoCard() {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardHeader(Icons.account_balance, 'Thông tin chuyển khoản', Colors.blue),
          const Divider(height: 24),
          Row(
            children: [
              Icon(Icons.account_balance_wallet, size: 20, color: Colors.grey[600]),
              const SizedBox(width: 8),
              Text('Ngân hàng: ', style: TextStyle(color: Colors.grey[600])),
              Text(widget.court.bankName!, style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 14),
          _buildCopyableRow('Số tài khoản', widget.court.bankAccountNumber!),
          const SizedBox(height: 14),
          Row(
            children: [
              Icon(Icons.person, size: 20, color: Colors.grey[600]),
              const SizedBox(width: 8),
              Text('Chủ TK: ', style: TextStyle(color: Colors.grey[600])),
              Text(widget.court.bankAccountName!, style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 14),
          _buildCopyableRow('Nội dung CK', _transferContent),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.orange.withOpacity(0.3)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, color: Colors.orange, size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Chuyển đúng số tiền và nội dung để chủ sân xác nhận nhanh hơn. Trả 70% còn lại khi đến sân.',
                    style: TextStyle(color: Colors.orange, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadBillCard() {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardHeader(Icons.upload_file, 'Upload ảnh xác nhận', Colors.green),
          const SizedBox(height: 8),
          Text('Chụp màn hình hoặc chọn ảnh bill chuyển khoản từ thư viện.', style: TextStyle(color: Colors.grey[600], fontSize: 14)),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: _pickBillImage,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: double.infinity,
              height: _billImage != null ? 220 : 130,
              decoration: BoxDecoration(
                color: _billImage != null ? Colors.transparent : Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _billImage != null ? Colors.green : Colors.grey[300]!, width: 2),
              ),
              child: _billImage != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.file(_billImage!, fit: BoxFit.cover),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.all(5),
                              decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                              child: const Icon(Icons.check, color: Colors.white, size: 16),
                            ),
                          ),
                        ],
                      ),
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_photo_alternate, size: 44, color: Colors.grey[400]),
                        const SizedBox(height: 8),
                        Text('Nhấn để chọn ảnh bill', style: TextStyle(color: Colors.grey[500], fontSize: 15)),
                      ],
                    ),
            ),
          ),
          if (_billImage != null) ...[
            const SizedBox(height: 8),
            Center(
              child: TextButton.icon(
                onPressed: _pickBillImage,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Chọn ảnh khác'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      padding: const EdgeInsets.all(20),
      child: child,
    );
  }

  Widget _buildCardHeader(IconData icon, String title, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(width: 10),
        Text(title, style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600])),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildCopyableRow(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          IconButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: value));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Đã sao chép: $value'), duration: const Duration(seconds: 1)),
              );
            },
            icon: Icon(Icons.copy, size: 20, color: primaryPurple),
            tooltip: 'Sao chép',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}
