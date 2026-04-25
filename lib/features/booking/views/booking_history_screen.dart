import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../../models/booking_model.dart';
import '../../../models/court_model.dart';
import '../../../models/user_model.dart';
import '../../../services/auth_service.dart';
import '../../../services/database_service.dart';
import '../../reporting/views/report_submission_screen.dart';
import 'payment_screen.dart';

class BookingHistoryScreen extends StatefulWidget {
  const BookingHistoryScreen({super.key});

  @override
  State<BookingHistoryScreen> createState() => _BookingHistoryScreenState();
}

class _BookingHistoryScreenState extends State<BookingHistoryScreen> {
  final DatabaseService _dbService = DatabaseService();
  final AuthService _authService = AuthService();
  final String currentUserId = FirebaseAuth.instance.currentUser!.uid;

  UserModel? _currentCustomer;

  // Cache tránh gọi Firestore lặp lại cho cùng một courtId / bookingId
  final Map<String, Future<CourtModel?>> _courtFutures = {};
  final Map<String, Future<bool>> _cancelCheckFutures = {};

  // ignore: unused_field
  static const Color primaryPurple = Color(0xFFBF89F5);

  @override
  void initState() {
    super.initState();
    _loadCurrentCustomer();
  }

  Future<void> _loadCurrentCustomer() async {
    final user = await _authService.getCurrentUserData();
    if (mounted) setState(() => _currentCustomer = user);
  }

  Future<CourtModel?> _getCourtFuture(String courtId) {
    return _courtFutures.putIfAbsent(courtId, () => _dbService.getCourtById(courtId));
  }

  Future<bool> _getAutoCancelFuture(String bookingId) {
    return _cancelCheckFutures.putIfAbsent(
      bookingId,
      () => _dbService.autoCancelExpiredUnpaidBooking(bookingId),
    );
  }

  bool _canReportOwner(BookingModel booking) {
    final isCancelledRecently = booking.bookingStatus == 'cancelled' &&
        booking.createdAt.toDate().isAfter(DateTime.now().subtract(const Duration(days: 30)));
    final isNoshowSuspect = booking.bookingStatus == 'confirmed' &&
        booking.paymentStatus == 'deposit_paid' &&
        booking.endTime.toDate().isBefore(DateTime.now());
    return isCancelledRecently || isNoshowSuspect;
  }

  void _handleCancelBooking(BookingModel booking) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận hủy'),
        content: const Text('Bạn có chắc chắn muốn hủy lịch đặt này không?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Không')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              bool success = await _dbService.cancelBooking(booking.id);
              if (success && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Đã hủy lịch thành công!')),
                );
              }
            },
            child: const Text('Hủy lịch', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _handleUploadBill(BookingModel booking) async {
    if (_currentCustomer == null) return;
    final court = await _dbService.getCourtById(booking.courtId);
    if (!mounted) return;
    if (court == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không tải được thông tin sân. Thử lại sau.'), backgroundColor: Colors.orange),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PaymentScreen(
          court: court,
          booking: booking,
          customer: _currentCustomer!,
          bookingId: booking.id,
        ),
      ),
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
    );
  }

  Widget _buildUploadBillSection(BookingModel booking) {
    return FutureBuilder<bool>(
      key: ValueKey('cancel_${booking.id}'),
      future: _getAutoCancelFuture(booking.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.only(top: 8),
            child: SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }

        if (snapshot.data == true) {
          // Đã bị hủy — stream sẽ cập nhật trạng thái trong giây lát
          return Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Đã hủy tự động (quá 5 phút chưa thanh toán)',
              style: TextStyle(color: Colors.red[700], fontSize: 13, fontStyle: FontStyle.italic),
            ),
          );
        }

        // Chưa quá hạn — hiện countdown và nút upload
        final elapsed = DateTime.now().difference(booking.createdAt.toDate()).inSeconds;
        final remaining = (300 - elapsed).clamp(0, 300);
        final mm = (remaining ~/ 60).toString().padLeft(2, '0');
        final ss = (remaining % 60).toString().padLeft(2, '0');

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.timer, size: 14, color: Colors.orange),
                const SizedBox(width: 4),
                Text(
                  'Còn $mm:$ss để upload bill',
                  style: const TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.w500),
                ),
              ],
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _handleUploadBill(booking),
                icon: const Icon(Icons.upload_file, size: 18),
                label: const Text('Upload bill thanh toán'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lịch sử đặt sân')),
      body: StreamBuilder<List<BookingModel>>(
        stream: _dbService.getCustomerBookingsStream(currentUserId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('Đã xảy ra lỗi tải dữ liệu.'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text('Bạn chưa có lịch đặt nào.', style: TextStyle(color: Colors.grey, fontSize: 16)),
            );
          }

          final bookings = snapshot.data!;

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: bookings.length,
            itemBuilder: (context, index) {
              final booking = bookings[index];
              final isCancelled = booking.bookingStatus == 'cancelled';
              final isPending = booking.bookingStatus == 'pending';
              final isConfirmed = booking.bookingStatus == 'confirmed';
              final isUnpaid = booking.paymentStatus == 'unpaid';
              final isDepositPaid = booking.paymentStatus == 'deposit_paid';
              final isFullyPaid = booking.paymentStatus == 'fully_paid';

              // Badge trạng thái đặt sân
              final Color bookingBadgeColor = isCancelled
                  ? Colors.red
                  : isPending
                      ? Colors.orange
                      : Colors.green;
              final String bookingBadgeText = isCancelled
                  ? 'Đã hủy'
                  : isPending
                      ? 'Chờ xác nhận'
                      : 'Đã xác nhận';

              // Badge trạng thái thanh toán
              final Color paymentBadgeColor = isFullyPaid
                  ? Colors.green
                  : isDepositPaid
                      ? Colors.blue
                      : Colors.red;
              final String paymentBadgeText = isFullyPaid
                  ? 'Đã thanh toán đủ'
                  : isDepositPaid
                      ? 'Đã cọc 30%'
                      : 'Chưa thanh toán';

              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Tên sân + badge trạng thái đặt
                      FutureBuilder<CourtModel?>(
                        future: _getCourtFuture(booking.courtId),
                        builder: (context, courtSnapshot) {
                          final courtName = courtSnapshot.data?.name ?? '...';
                          return Row(
                            children: [
                              Expanded(
                                child: Text(
                                  courtName,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              _buildBadge(bookingBadgeText, bookingBadgeColor),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 6),

                      // Sân con
                      Row(
                        children: [
                          Icon(Icons.sports_tennis, size: 14, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(booking.subCourtName, style: TextStyle(color: Colors.grey[700], fontSize: 13)),
                        ],
                      ),
                      const SizedBox(height: 4),

                      // Ngày + giờ
                      Row(
                        children: [
                          Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(
                            '${DateFormat('dd/MM/yyyy').format(booking.bookingDate.toDate())}  •  '
                            '${DateFormat('HH:mm').format(booking.startTime.toDate())} – '
                            '${DateFormat('HH:mm').format(booking.endTime.toDate())}',
                            style: TextStyle(color: Colors.grey[700], fontSize: 13),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      const Divider(height: 1),
                      const SizedBox(height: 10),

                      // Tổng tiền + badge thanh toán
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${booking.totalPrice.toStringAsFixed(0)} VNĐ',
                            style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          if (!isCancelled) _buildBadge(paymentBadgeText, paymentBadgeColor),
                        ],
                      ),

                      // Còn lại X VNĐ (khi confirmed + deposit_paid)
                      if (isConfirmed && isDepositPaid) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Còn lại ${(booking.totalPrice * 0.7).toStringAsFixed(0)} VNĐ — trả tại sân',
                          style: const TextStyle(color: Colors.blue, fontSize: 13),
                        ),
                      ],

                      // Upload bill (khi pending + unpaid)
                      if (isPending && isUnpaid) _buildUploadBillSection(booking),

                      const SizedBox(height: 10),

                      // Nút hủy sân
                      if (!isCancelled && booking.startTime.toDate().isAfter(DateTime.now()))
                        Align(
                          alignment: Alignment.centerRight,
                          child: OutlinedButton.icon(
                            onPressed: () => _handleCancelBooking(booking),
                            icon: const Icon(Icons.cancel, color: Colors.red, size: 18),
                            label: const Text('Hủy sân', style: TextStyle(color: Colors.red)),
                            style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red)),
                          ),
                        ),

                      // Nút báo cáo chủ sân
                      if (_currentCustomer != null && _canReportOwner(booking))
                        Align(
                          alignment: Alignment.centerRight,
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final owner = await _dbService.getOwnerOfCourt(booking.courtId);
                              if (!mounted) return;
                              if (owner == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Không tải được thông tin chủ sân. Thử lại sau.'),
                                    backgroundColor: Colors.orange,
                                  ),
                                );
                                return;
                              }
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ReportSubmissionScreen(
                                    booking: booking,
                                    reporter: _currentCustomer!,
                                    reportedUser: owner,
                                    reporterRole: 'customer',
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.report, color: Colors.deepOrange, size: 18),
                            label: const Text('Báo cáo chủ sân', style: TextStyle(color: Colors.deepOrange)),
                            style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.deepOrange)),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
