import 'package:flutter/material.dart';
import '../../../models/court_model.dart';
import '../../../services/database_service.dart'; // Thêm import này
import 'edit_court_screen.dart';
import 'owner_court_schedule_screen.dart';
import 'owner_revenue_screen.dart';

class OwnerCourtDetailScreen extends StatefulWidget {
  final CourtModel court;

  const OwnerCourtDetailScreen({super.key, required this.court});

  @override
  State<OwnerCourtDetailScreen> createState() => _OwnerCourtDetailScreenState();
}

class _OwnerCourtDetailScreenState extends State<OwnerCourtDetailScreen> {
  final DatabaseService _dbService = DatabaseService();

  // Hàm xử lý xóa ngay tại màn hình này
  void _showDeleteDialog() {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Xác nhận xóa'),
          content: Text('Bạn có chắc chắn muốn xóa "${widget.court.name}" không?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Hủy'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(dialogContext); // 1. Đóng popup xác nhận

                bool success = await _dbService.deleteCourt(widget.court.id);

                if (success && mounted) {
                  // 2. Thông báo thành công
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Đã xóa sân thành công!')),
                  );

                  // 3. QUAN TRỌNG: Đóng màn hình chi tiết để quay về trang chủ
                  Navigator.of(context).pop(); 
                }
              },
              child: const Text('Xóa', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMenuButton({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: color),
            const SizedBox(height: 12),
            Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.court.name)),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quản lý hệ thống: ${widget.court.subCourts.length} sân nhỏ',
              style: const TextStyle(fontSize: 18, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                children: [
                  _buildMenuButton(
                    title: 'Xem lịch đặt',
                    icon: Icons.calendar_month,
                    color: Colors.green,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => OwnerCourtScheduleScreen(court: widget.court))),
                  ),
                  _buildMenuButton(
                    title: 'Doanh thu',
                    icon: Icons.bar_chart,
                    color: Colors.orange,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => OwnerRevenueScreen(court: widget.court))),
                  ),
                  _buildMenuButton(
                    title: 'Sửa thông tin',
                    icon: Icons.edit,
                    color: Colors.blue,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => EditCourtScreen(court: widget.court))),
                  ),
                  _buildMenuButton(
                    title: 'Xóa sân',
                    icon: Icons.delete,
                    color: Colors.red,
                    onTap: _showDeleteDialog, // Gọi hàm xóa tại chỗ
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}