import 'package:flutter/material.dart';
import '../../../services/database_service.dart';

class AdminDashboardTab extends StatefulWidget {
  const AdminDashboardTab({super.key});

  @override
  State<AdminDashboardTab> createState() => _AdminDashboardTabState();
}

class _AdminDashboardTabState extends State<AdminDashboardTab> {
  final DatabaseService _dbService = DatabaseService();
  late Future<Map<String, int>> _statsFuture;

  @override
  void initState() {
    super.initState();
    _statsFuture = _dbService.getDashboardStats();
  }

  void _refresh() {
    setState(() => _statsFuture = _dbService.getDashboardStats());
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Tổng quan hệ thống',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            IconButton(
              onPressed: _refresh,
              icon: const Icon(Icons.refresh),
              tooltip: 'Làm mới',
            ),
          ],
        ),
        const SizedBox(height: 24),
        Expanded(
          child: FutureBuilder<Map<String, int>>(
            future: _statsFuture,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Lỗi tải dữ liệu: ${snapshot.error}'));
              }

              final stats = snapshot.data!;
              final cards = [
                _StatCardData(
                  icon: Icons.people,
                  color: Colors.blue,
                  label: 'Tổng người dùng',
                  value: stats['totalUsers'] ?? 0,
                ),
                _StatCardData(
                  icon: Icons.check_circle,
                  color: Colors.green,
                  label: 'Sân đang hoạt động',
                  value: stats['activeCourts'] ?? 0,
                ),
                _StatCardData(
                  icon: Icons.pending,
                  color: Colors.orange,
                  label: 'Sân chờ duyệt',
                  value: stats['pendingCourts'] ?? 0,
                  hasBadge: (stats['pendingCourts'] ?? 0) > 0,
                ),
                _StatCardData(
                  icon: Icons.report,
                  color: Colors.red,
                  label: 'Báo cáo chờ xử lý',
                  value: stats['pendingReports'] ?? 0,
                  hasBadge: (stats['pendingReports'] ?? 0) > 0,
                ),
                _StatCardData(
                  icon: Icons.block,
                  color: Colors.red.shade300,
                  label: 'Tài khoản bị ban',
                  value: stats['bannedUsers'] ?? 0,
                ),
                _StatCardData(
                  icon: Icons.event,
                  color: const Color(0xFFBF89F5),
                  label: 'Đặt sân tháng này',
                  value: stats['monthlyBookings'] ?? 0,
                ),
              ];

              return GridView.count(
                crossAxisCount: 3,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 2.2,
                children: cards.map((c) => _StatCard(data: c)).toList(),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _StatCardData {
  final IconData icon;
  final Color color;
  final String label;
  final int value;
  final bool hasBadge;

  const _StatCardData({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    this.hasBadge = false,
  });
}

class _StatCard extends StatelessWidget {
  final _StatCardData data;

  const _StatCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: data.color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(data.icon, size: 40, color: data.color),
              ),
              if (data.hasBadge)
                Positioned(
                  top: -4,
                  right: -4,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${data.value}',
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  data.label,
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
