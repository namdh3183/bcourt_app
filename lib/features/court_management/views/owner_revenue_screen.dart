import 'package:flutter/material.dart';
import '../../../models/court_model.dart';
import '../../../services/database_service.dart';

class OwnerRevenueScreen extends StatefulWidget {
  final CourtModel court;

  const OwnerRevenueScreen({super.key, required this.court});

  @override
  State<OwnerRevenueScreen> createState() => _OwnerRevenueScreenState();
}

class _OwnerRevenueScreenState extends State<OwnerRevenueScreen> {
  final DatabaseService _dbService = DatabaseService();
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;

  // Widget vẽ thẻ hiển thị số liệu
  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 16, color: Colors.grey[700])),
                  const SizedBox(height: 4),
                  Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Doanh thu: ${widget.court.name}')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Row chọn Tháng và Năm
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Tháng: ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                DropdownButton<int>(
                  value: _selectedMonth,
                  items: List.generate(12, (index) => index + 1)
                      .map((m) => DropdownMenuItem(value: m, child: Text(m.toString())))
                      .toList(),
                  onChanged: (val) => setState(() => _selectedMonth = val!),
                ),
                const SizedBox(width: 24),
                const Text('Năm: ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                DropdownButton<int>(
                  value: _selectedYear,
                  items: [_selectedYear - 1, _selectedYear, _selectedYear + 1]
                      .map((y) => DropdownMenuItem(value: y, child: Text(y.toString())))
                      .toList(),
                  onChanged: (val) => setState(() => _selectedYear = val!),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // FutureBuilder gọi database để lấy số liệu
            Expanded(
              child: FutureBuilder<Map<String, dynamic>>(
                // Mỗi khi _selectedMonth hoặc _selectedYear đổi, Future này sẽ chạy lại
                future: _dbService.getMonthlyStatistics(widget.court.id, _selectedYear, _selectedMonth),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return const Center(child: Text('Đã xảy ra lỗi khi tải dữ liệu.'));
                  }

                  final data = snapshot.data ?? {'revenue': 0.0, 'successful': 0, 'cancelled': 0};

                  return ListView(
                    children: [
                      _buildStatCard(
                        'Tổng doanh thu dự kiến',
                        '${(data['revenue'] as double).toStringAsFixed(0)} VNĐ',
                        Icons.monetization_on,
                        Colors.green,
                      ),
                      const SizedBox(height: 12),
                      _buildStatCard(
                        'Số ca đặt thành công',
                        '${data['successful']} ca',
                        Icons.check_circle,
                        Colors.blue,
                      ),
                      const SizedBox(height: 12),
                      _buildStatCard(
                        'Số ca bị khách hủy',
                        '${data['cancelled']} ca',
                        Icons.cancel,
                        Colors.red,
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}