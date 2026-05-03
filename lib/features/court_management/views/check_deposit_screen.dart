import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/court_model.dart';
import '../../../models/booking_model.dart';
import '../../../models/user_model.dart';
import '../../../services/database_service.dart';
import '../../../services/auth_service.dart';

class CheckDepositScreen extends StatefulWidget {
  final BookingModel booking;
  final CourtModel court;

  const CheckDepositScreen({
    super.key,
    required this.booking,
    required this.court,
  });

  @override
  State<CheckDepositScreen> createState() => _CheckDepositScreenState();
}

class _CheckDepositScreenState extends State<CheckDepositScreen> {
  final DatabaseService _dbService = DatabaseService();
  final AuthService _authService = AuthService();

  UserModel? _customer;
  bool _isLoadingCustomer = true;

  final Color primaryPurple = const Color(0xFFBF89F5);

  @override
  void initState() {
    super.initState();
    _loadCustomer();
  }

  Future<void> _loadCustomer() async {
    final customer = await _authService.getUserFromFirestore(widget.booking.customerId);
    if (mounted) {
      setState(() {
        _customer = customer;
        _isLoadingCustomer = false;
      });
    }
  }

  bool get _hasImage =>
      widget.booking.depositProofImageUrl != null &&
      widget.booking.depositProofImageUrl!.isNotEmpty;

  // Nút approve disabled khi đang load customer hoặc không có ảnh bill
  bool get _canApprove => !_isLoadingCustomer && _hasImage;

  String get _transferContent {
    if (_isLoadingCustomer || _customer == null) return 'Đang tải...';
    final lastName = _customer!.fullName.isNotEmpty
        ? _customer!.fullName.split(' ').last.toUpperCase()
        : 'KHÁCH';
    final date = DateFormat('ddMM').format(widget.booking.bookingDate.toDate());
    return 'BCOURT $lastName $date';
  }

  void _showFullScreenImage(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogCtx) => Dialog(
        insetPadding: EdgeInsets.zero,
        backgroundColor: Colors.black,
        child: Stack(
          fit: StackFit.loose,
          alignment: Alignment.center,
          children: [
            InteractiveViewer(
              child: Image.network(
                widget.booking.depositProofImageUrl!,
                fit: BoxFit.contain,
              ),
            ),
            Positioned(
              top: 40,
              right: 16,
              child: GestureDetector(
                onTap: () => Navigator.pop(dialogCtx),
                child: const Icon(Icons.close, color: Colors.white, size: 32),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleReject() {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text(
          'Xác nhận từ chối?',
          style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
        ),
        content: const Text('Bạn đã kiểm tra kỹ và thấy số tiền/nội dung không đúng?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Đóng', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogCtx);
              bool success = await _dbService.cancelBooking(widget.booking.id);
              if (success && mounted) {
                await _dbService.sendNotification(
                  recipientId: widget.booking.customerId,
                  title: 'Lịch đặt đã bị từ chối',
                  body: 'Chủ sân đã từ chối bill cọc. Vui lòng kiểm tra lại và liên hệ chủ sân.',
                  type: 'booking_cancelled_by_owner',
                  relatedId: widget.booking.id,
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Đã từ chối lịch đặt. Khung giờ đã được mở lại.'),
                    backgroundColor: Colors.red,
                  ),
                );
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Từ chối', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _handleApprove() {
    final double depositAmount = widget.booking.totalPrice * 0.3;
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text(
          'Xác nhận đã nhận đúng?',
          style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Số tiền cọc ${depositAmount.toStringAsFixed(0)} VNĐ đã được nhận đúng. Tiếp tục duyệt lịch?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Hủy', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogCtx);
              bool success = await _dbService.approveBooking(widget.booking.id);
              if (success && mounted) {
                await _dbService.sendNotification(
                  recipientId: widget.booking.customerId,
                  title: 'Lịch đặt đã được xác nhận',
                  body: 'Chủ sân đã duyệt bill cọc. Hãy đến sân đúng giờ và thanh toán phần còn lại.',
                  type: 'booking_confirmed',
                  relatedId: widget.booking.id,
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Đã duyệt lịch! Chờ khách đến sân trả phần còn lại.'),
                    backgroundColor: Colors.orange,
                  ),
                );
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Đã nhận đúng', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double depositAmount = widget.booking.totalPrice * 0.3;
    final String bookingDateStr = DateFormat('dd/MM/yyyy').format(widget.booking.bookingDate.toDate());
    final String startTimeStr = DateFormat('HH:mm').format(widget.booking.startTime.toDate());
    final String endTimeStr = DateFormat('HH:mm').format(widget.booking.endTime.toDate());

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Kiểm tra bill chuyển khoản'),
        backgroundColor: primaryPurple,
        foregroundColor: Colors.white,
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, -3))
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _handleReject,
                  icon: const Icon(Icons.cancel, color: Colors.red, size: 18),
                  label: const Text(
                    'Từ chối lịch',
                    style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _canApprove ? _handleApprove : null,
                  icon: const Icon(Icons.check_circle, color: Colors.white, size: 18),
                  label: const Text(
                    'Đã nhận đúng',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    disabledBackgroundColor: Colors.grey[300],
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section A: Số tiền cọc nổi bật
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: primaryPurple.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: primaryPurple.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'SỐ TIỀN CỌC CẦN NHẬN',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: primaryPurple),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${depositAmount.toStringAsFixed(0)} VNĐ',
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: primaryPurple),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '= 30% × ${widget.booking.totalPrice.toStringAsFixed(0)} VNĐ (tổng tiền)',
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: primaryPurple.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.info_outline, size: 16, color: primaryPurple),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'Nội dung CK dự kiến: $_transferContent',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: primaryPurple,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Section B: Thông tin đặt lịch
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6, offset: const Offset(0, 2))
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Thông tin đặt lịch',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: primaryPurple),
                  ),
                  const SizedBox(height: 10),
                  const Divider(height: 1),
                  const SizedBox(height: 10),
                  _buildInfoRow(
                    'Khách:',
                    _isLoadingCustomer ? 'Đang tải...' : (_customer?.fullName ?? 'Không rõ'),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 80,
                          child: Text('SĐT:', style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                        ),
                        Expanded(
                          child: Text(
                            _isLoadingCustomer ? 'Đang tải...' : (_customer?.phone ?? 'Không có'),
                            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
                          ),
                        ),
                        Icon(Icons.phone, size: 16, color: Colors.grey[400]),
                      ],
                    ),
                  ),
                  _buildInfoRow('Sân:', widget.court.name),
                  _buildInfoRow('Vị trí:', widget.booking.subCourtName),
                  _buildInfoRow('Ngày:', bookingDateStr),
                  _buildInfoRow('Giờ:', '$startTimeStr - $endTimeStr'),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Section C: Ảnh bill
            Text(
              'Ảnh bill chuyển khoản',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: primaryPurple),
            ),
            const SizedBox(height: 10),

            if (!_hasImage)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning_amber, color: Colors.red, size: 24),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Không có ảnh bill. Vui lòng liên hệ khách hàng hoặc từ chối lịch này.',
                        style: TextStyle(color: Colors.red, fontSize: 14),
                      ),
                    ),
                  ],
                ),
              )
            else
              GestureDetector(
                onTap: () => _showFullScreenImage(context),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    widget.booking.depositProofImageUrl!,
                    width: double.infinity,
                    height: 400,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return SizedBox(
                        height: 400,
                        child: Center(child: CircularProgressIndicator(color: primaryPurple)),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) => const SizedBox(
                      height: 200,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.broken_image, size: 48, color: Colors.grey),
                          SizedBox(height: 8),
                          Text('Không tải được ảnh', style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
