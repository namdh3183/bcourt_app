import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/court_model.dart';
import '../../../models/booking_model.dart';
import '../../../models/user_model.dart';
import '../../../services/database_service.dart';
import '../../../services/auth_service.dart';
import '../../reporting/views/report_submission_screen.dart';
import 'check_deposit_screen.dart';

class OwnerCourtScheduleScreen extends StatefulWidget {
  final CourtModel court;

  const OwnerCourtScheduleScreen({super.key, required this.court});

  @override
  State<OwnerCourtScheduleScreen> createState() => _OwnerCourtScheduleScreenState();
}

class _OwnerCourtScheduleScreenState extends State<OwnerCourtScheduleScreen> {
  final DatabaseService _dbService = DatabaseService();
  final AuthService _authService = AuthService();

  UserModel? _currentOwner;

  DateTimeRange _selectedDateRange = DateTimeRange(
    start: DateTime.now(),
    end: DateTime.now(),
  );

  final Color primaryPurple = const Color(0xFFBF89F5);

  @override
  void initState() {
    super.initState();
    _loadCurrentOwner();
  }

  Future<void> _loadCurrentOwner() async {
    final user = await _authService.getCurrentUserData();
    if (mounted) setState(() => _currentOwner = user);
  }

  Future<void> _selectDateRange(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 60)),
      initialDateRange: _selectedDateRange,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: primaryPurple,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDateRange) {
      setState(() {
        _selectedDateRange = picked;
      });
    }
  }

  // Hàm hủy lịch — 2 ngữ cảnh: từ chối (pending) và bom sân (confirmed + deposit_paid)
  void _handleCancelBooking(BookingModel booking, {bool isAfterDeposit = false}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Text(
          isAfterDeposit ? 'Hủy lịch đã nhận cọc' : 'Từ chối lịch đặt',
          style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
        ),
        content: isAfterDeposit
            ? Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Khách đã chuyển tiền cọc 30%. Việc hủy có thể gây tranh chấp và bạn cần chủ động hoàn trả tiền cọc cho khách. Bạn đã thỏa thuận với khách chưa?',
                  style: TextStyle(color: Colors.red),
                ),
              )
            : const Text('Sau khi từ chối, khung giờ này sẽ được mở lại cho khách khác đặt.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đóng', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              bool success = await _dbService.cancelBooking(booking.id);
              if (success && mounted) {
                await _dbService.sendNotification(
                  recipientId: booking.customerId,
                  title: 'Lịch đặt đã bị hủy bởi chủ sân',
                  body: 'Chủ sân đã hủy lịch đặt tại ${widget.court.name}. Vui lòng liên hệ chủ sân nếu cần.',
                  type: 'booking_cancelled_by_owner',
                  relatedId: booking.id,
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      isAfterDeposit
                          ? 'Đã hủy lịch. Nhớ hoàn trả tiền cọc cho khách!'
                          : 'Đã từ chối lịch đặt! Khung giờ đã được mở lại.',
                    ),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(
              isAfterDeposit ? 'Xác nhận hủy' : 'Từ chối',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  // Hàm xác nhận đã nhận đủ 100% — khách đến sân trả 70% còn lại
  void _handleMarkAsFullyPaid(BookingModel booking, UserModel? customer) {
    final double remainingAmount = booking.totalPrice * 0.7;
    final String bookingDate = DateFormat('dd/MM/yyyy').format(booking.startTime.toDate());
    final String customerName = customer?.fullName ?? 'khách';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text(
          'Xác nhận đã nhận đủ tiền',
          style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Xác nhận đã nhận đủ ${remainingAmount.toStringAsFixed(0)} VNĐ từ khách $customerName cho lịch ngày $bookingDate?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              bool success = await _dbService.markAsFullyPaid(booking.id);
              if (success && mounted) {
                await _dbService.sendNotification(
                  recipientId: booking.customerId,
                  title: 'Đã xác nhận thanh toán đủ',
                  body: 'Chủ sân xác nhận bạn đã thanh toán đầy đủ cho lịch đặt tại ${widget.court.name}.',
                  type: 'fully_paid',
                  relatedId: booking.id,
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Đã xác nhận nhận đủ tiền! Lịch hoàn tất.'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Đã nhận đủ', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  String _getDateRangeText() {
    if (_selectedDateRange.start.day == _selectedDateRange.end.day &&
        _selectedDateRange.start.month == _selectedDateRange.end.month) {
      return 'Ngày: ${DateFormat('dd/MM/yyyy').format(_selectedDateRange.start)}';
    } else {
      return 'Từ ${DateFormat('dd/MM').format(_selectedDateRange.start)} đến ${DateFormat('dd/MM/yyyy').format(_selectedDateRange.end)}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text('Lịch: ${widget.court.name}', style: const TextStyle(fontSize: 18)),
        backgroundColor: primaryPurple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range),
            onPressed: () => _selectDateRange(context),
            tooltip: 'Chọn khoảng ngày',
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            color: primaryPurple.withOpacity(0.1),
            width: double.infinity,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.calendar_month, color: primaryPurple, size: 20),
                const SizedBox(width: 8),
                Text(
                  _getDateRangeText(),
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: primaryPurple),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<BookingModel>>(
              stream: _dbService.getBookingsForCourtByDateRange(
                widget.court.id,
                _selectedDateRange.start,
                _selectedDateRange.end,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator(color: primaryPurple));
                }
                if (snapshot.hasError) {
                  return const Center(child: Text('Đã xảy ra lỗi khi tải dữ liệu.'));
                }

                final bookings = snapshot.data ?? [];

                if (bookings.isEmpty) {
                  return const Center(
                    child: Text(
                      'Không có lịch đặt nào trong khoảng thời gian này.',
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  );
                }

                bookings.sort((a, b) {
                  int timeCmp = a.startTime.compareTo(b.startTime);
                  if (timeCmp != 0) return timeCmp;
                  return a.subCourtName.compareTo(b.subCourtName);
                });

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: bookings.length,
                  itemBuilder: (context, index) {
                    final booking = bookings[index];

                    final bool isCancelled = booking.bookingStatus == 'cancelled';
                    final bool isConfirmed = booking.bookingStatus == 'confirmed';
                    final bool isPending = booking.bookingStatus == 'pending';
                    final bool isDepositPaid = booking.paymentStatus == 'deposit_paid';
                    final bool isFullyPaid = booking.paymentStatus == 'fully_paid';

                    // Badge thống nhất — tính từ cả bookingStatus + paymentStatus
                    Color statusColor;
                    String statusText;
                    if (isCancelled) {
                      statusColor = Colors.red;
                      statusText = 'Khách đã hủy';
                    } else if (isPending) {
                      statusColor = Colors.orange;
                      statusText = 'Chờ duyệt';
                    } else if (isConfirmed && isDepositPaid) {
                      statusColor = Colors.orange;
                      statusText = 'Chờ thu đủ';
                    } else if (isConfirmed && isFullyPaid) {
                      statusColor = Colors.green;
                      statusText = 'Hoàn tất';
                    } else if (isConfirmed && booking.paymentStatus == 'unpaid') {
                      statusColor = Colors.amber;
                      statusText = 'Cần kiểm tra';
                    } else {
                      statusColor = Colors.grey;
                      statusText = 'Không rõ';
                    }

                    // Viền cam khi card cần owner action
                    final bool needsAction = isPending ||
                        (isConfirmed &&
                            isDepositPaid &&
                            booking.endTime.toDate().isBefore(DateTime.now()));

                    return Card(
                      elevation: 3,
                      margin: const EdgeInsets.only(bottom: 16),
                      shape: RoundedRectangleBorder(
                        side: needsAction
                            ? const BorderSide(color: Colors.orange, width: 2.5)
                            : BorderSide(color: statusColor.withOpacity(0.5), width: 1.5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header: tên sân + ngày giờ | badge
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        booking.subCourtName,
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: primaryPurple,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Ngày: ${DateFormat('dd/MM/yyyy').format(booking.startTime.toDate())}',
                                        style: const TextStyle(fontWeight: FontWeight.w500),
                                      ),
                                      Text(
                                        'Giờ: ${DateFormat('HH:mm').format(booking.startTime.toDate())} - ${DateFormat('HH:mm').format(booking.endTime.toDate())}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          decoration: isCancelled ? TextDecoration.lineThrough : null,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: statusColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    statusText,
                                    style: TextStyle(
                                      color: statusColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Divider(),
                            ),

                            // Thông tin khách + nút hành động (trong FutureBuilder để có customer)
                            FutureBuilder<UserModel?>(
                              future: _authService.getUserFromFirestore(booking.customerId),
                              builder: (context, userSnapshot) {
                                final customer = userSnapshot.connectionState == ConnectionState.done
                                    ? userSnapshot.data
                                    : null;

                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (userSnapshot.connectionState == ConnectionState.waiting)
                                      const Text(
                                        'Đang tải thông tin khách...',
                                        style: TextStyle(color: Colors.grey, fontSize: 13),
                                      )
                                    else
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Khách: ${customer?.fullName ?? "Không rõ"}',
                                                style: const TextStyle(fontWeight: FontWeight.bold),
                                              ),
                                              Text(
                                                'SĐT: ${customer?.phone ?? "Không có"}',
                                                style: TextStyle(color: Colors.grey[700], fontSize: 13),
                                              ),
                                            ],
                                          ),
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.end,
                                            children: [
                                              Text(
                                                '${booking.totalPrice.toStringAsFixed(0)} VNĐ',
                                                style: TextStyle(
                                                  color: isCancelled ? Colors.grey : Colors.green,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                  decoration: isCancelled ? TextDecoration.lineThrough : null,
                                                ),
                                              ),
                                              if (isConfirmed && isDepositPaid)
                                                Text(
                                                  'Đã cọc 30%',
                                                  style: TextStyle(
                                                    color: Colors.orange[700],
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              if (isConfirmed && isFullyPaid)
                                                const Text(
                                                  'Đã thanh toán đủ',
                                                  style: TextStyle(
                                                    color: Colors.green,
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ],
                                      ),

                                    // Nút hành động theo bảng logic
                                    if (isPending) ...[
                                      const SizedBox(height: 16),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: ElevatedButton.icon(
                                              onPressed: () => Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) => CheckDepositScreen(
                                                    booking: booking,
                                                    court: widget.court,
                                                  ),
                                                ),
                                              ),
                                              icon: const Icon(Icons.receipt_long, color: Colors.white, size: 18),
                                              label: const Text(
                                                'Kiểm tra thanh toán cọc',
                                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                              ),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: primaryPurple,
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: OutlinedButton.icon(
                                              onPressed: () => _handleCancelBooking(booking),
                                              icon: const Icon(Icons.cancel, color: Colors.red, size: 18),
                                              label: const Text(
                                                'Từ chối',
                                                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 13),
                                              ),
                                              style: OutlinedButton.styleFrom(
                                                side: const BorderSide(color: Colors.red),
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],

                                    if (isConfirmed && isDepositPaid) ...[
                                      const SizedBox(height: 16),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: ElevatedButton.icon(
                                              onPressed: () => _handleMarkAsFullyPaid(booking, customer),
                                              icon: const Icon(Icons.payments, color: Colors.white, size: 18),
                                              label: const Text(
                                                'Đã nhận đủ tiền',
                                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                              ),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.green,
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: OutlinedButton.icon(
                                              onPressed: () => _handleCancelBooking(booking, isAfterDeposit: true),
                                              icon: const Icon(Icons.cancel, color: Colors.red, size: 18),
                                              label: const Text(
                                                'Bom sân (Hủy)',
                                                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 13),
                                              ),
                                              style: OutlinedButton.styleFrom(
                                                side: const BorderSide(color: Colors.red),
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                    // Nút Báo cáo khách khi: đã hủy HOẶC nghi bom sân
                                    if (_currentOwner != null && (
                                        isCancelled ||
                                        (isConfirmed &&
                                            isDepositPaid &&
                                            booking.endTime.toDate().isBefore(DateTime.now()))
                                    )) ...[
                                      const SizedBox(height: 10),
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: OutlinedButton.icon(
                                          onPressed: customer == null
                                              ? null
                                              : () => Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder: (_) => ReportSubmissionScreen(
                                                        booking: booking,
                                                        reporter: _currentOwner!,
                                                        reportedUser: customer,
                                                        reporterRole: 'owner',
                                                      ),
                                                    ),
                                                  ),
                                          icon: const Icon(Icons.report, color: Colors.deepOrange, size: 18),
                                          label: const Text(
                                            'Báo cáo khách',
                                            style: TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.bold, fontSize: 13),
                                          ),
                                          style: OutlinedButton.styleFrom(
                                            side: const BorderSide(color: Colors.deepOrange),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                );
                              },
                            ),
                          ],
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
    );
  }
}
