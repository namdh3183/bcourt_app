import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/court_model.dart';
import '../../../models/booking_model.dart';
import '../../../models/user_model.dart';
import 'booking_history_screen.dart';

class BookingSuccessScreen extends StatelessWidget {
  final CourtModel court;
  final BookingModel booking;
  final UserModel customer;

  const BookingSuccessScreen({
    super.key,
    required this.court,
    required this.booking,
    required this.customer,
  });

  static const Color primaryPurple = Color(0xFFBF89F5);

  @override
  Widget build(BuildContext context) {
    final bool isDepositPaid = booking.paymentStatus == 'deposit_paid';
    final double depositAmount = booking.totalPrice * 0.3;
    final double remainingAmount = booking.totalPrice * 0.7;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Thông tin lịch đặt', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: primaryPurple,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 20),

            // Icon + tiêu đề theo trạng thái thanh toán
            if (isDepositPaid) ...[
              const Icon(Icons.pending_actions, color: Colors.orange, size: 100),
              const SizedBox(height: 10),
              const Text(
                'ĐÃ GỬI YÊU CẦU ĐẶT SÂN',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.orange),
              ),
              const SizedBox(height: 6),
              Text(
                'Chủ sân đang kiểm tra bill chuyển khoản của bạn...',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
            ] else ...[
              const Icon(Icons.bookmark_added, color: Colors.blue, size: 100),
              const SizedBox(height: 10),
              const Text(
                'ĐÃ GIỮ CHỖ — VUI LÒNG THANH TOÁN',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blue),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                'Lịch đã được giữ. Vui lòng upload bill trong 5 phút để xác nhận.',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 30),

            // Thông tin sân
            _buildSectionCard(
              title: 'Thông tin sân',
              icon: Icons.location_on,
              content: [
                _buildInfoRow('Tên sân:', court.name),
                _buildInfoRow('Địa chỉ:', court.address ?? 'Chưa cập nhật địa chỉ'),
              ],
            ),
            const SizedBox(height: 20),

            // Chi tiết đặt lịch
            _buildSectionCard(
              title: 'Chi tiết đặt lịch',
              icon: Icons.event_available,
              content: [
                _buildInfoRow('Khách hàng:', customer.fullName),
                _buildInfoRow('Vị trí:', booking.subCourtName),
                _buildInfoRow('Ngày đặt:', DateFormat('dd/MM/yyyy').format(booking.bookingDate.toDate())),
                _buildInfoRow(
                  'Khung giờ:',
                  '${DateFormat('HH:mm').format(booking.startTime.toDate())} - ${DateFormat('HH:mm').format(booking.endTime.toDate())}',
                ),
                _buildInfoRow(
                  'Tổng giờ:',
                  '${(booking.endTime.toDate().difference(booking.startTime.toDate()).inMinutes / 60).toStringAsFixed(1)} giờ',
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Thông tin thanh toán — chỉ hiện chi tiết khi đã cọc
            if (isDepositPaid) ...[
              _buildSectionCard(
                title: 'Thông tin thanh toán',
                icon: Icons.payments,
                content: [
                  _buildInfoRow('Tổng tiền:', '${booking.totalPrice.toStringAsFixed(0)} VNĐ', isBold: true),
                  const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider(thickness: 1)),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Đã đặt cọc (30%):', style: TextStyle(fontWeight: FontWeight.w500)),
                            Text(
                              '${depositAmount.toStringAsFixed(0)} VNĐ',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange, fontSize: 16),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: Colors.orange.withOpacity(0.2), borderRadius: BorderRadius.circular(6)),
                          child: const Text('Đã chuyển khoản — chờ duyệt', style: TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Còn lại (70%):', style: TextStyle(fontWeight: FontWeight.w500)),
                            Text(
                              '${remainingAmount.toStringAsFixed(0)} VNĐ',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue, fontSize: 16),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: Colors.blue.withOpacity(0.2), borderRadius: BorderRadius.circular(6)),
                          child: const Text('Trả khi đến sân', style: TextStyle(color: Colors.blue, fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),
            ] else ...[
              const SizedBox(height: 20),
            ],

            // Nút chính
            ElevatedButton(
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const BookingHistoryScreen()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: isDepositPaid ? primaryPurple : Colors.blue,
                minimumSize: const Size(double.infinity, 55),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                isDepositPaid ? 'XEM LỊCH SỬ ĐẶT SÂN' : 'CHUYỂN ĐẾN THANH TOÁN',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
            const SizedBox(height: 12),

            // Nút phụ: về trang chủ
            OutlinedButton(
              onPressed: () => Navigator.popUntil(context, (route) => route.isFirst),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 55),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                side: BorderSide(color: primaryPurple),
              ),
              child: Text(
                'VỀ TRANG CHỦ',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryPurple),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({required String title, required IconData icon, required List<Widget> content}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: primaryPurple, size: 28),
                const SizedBox(width: 12),
                Text(title, style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: primaryPurple)),
              ],
            ),
            const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider()),
            ...content,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 110, child: Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 15))),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
                fontSize: isBold ? 20 : 16,
                color: color ?? Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
