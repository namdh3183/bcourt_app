import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../../../models/user_model.dart';
import '../../../models/court_model.dart';
import '../../../services/database_service.dart';
import '../../../services/auth_service.dart';
import '../../../services/notification_service.dart';
import '../../auth/views/login_screen.dart';
import 'admin_dashboard_tab.dart';
import 'admin_reports_tab.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  final DatabaseService _dbService = DatabaseService();
  int _selectedIndex = 0;
  int _pendingReportCount = 0;
  int _pendingCourtCount = 0;
  int _pendingOwnerCount = 0;
  StreamSubscription? _reportSubscription;
  StreamSubscription? _courtSubscription;
  StreamSubscription? _ownerSubscription;

  static const Color primaryPurple = Color(0xFFBF89F5);

  @override
  void initState() {
    super.initState();
    _reportSubscription = _dbService.getAllReportsStream().listen((reports) {
      if (mounted) {
        setState(() {
          _pendingReportCount = reports.where((r) => r.status == 'pending').length;
        });
      }
    });
    _courtSubscription = _dbService.getAllCourtsForAdminStream().listen((courts) {
      if (mounted) {
        setState(() {
          _pendingCourtCount = courts.where((c) => c.status == 'pending').length;
        });
      }
    });
    _ownerSubscription = _dbService.getAllUsersStream().listen((users) {
      if (mounted) {
        setState(() {
          _pendingOwnerCount = users.where((u) => u.status == 'pending_approval').length;
        });
      }
    });
  }

  @override
  void dispose() {
    _reportSubscription?.cancel();
    _courtSubscription?.cancel();
    _ownerSubscription?.cancel();
    super.dispose();
  }

  void _handleLogout() async {
    if (!kIsWeb) await NotificationService().clearToken();
    await AuthService().signOut();
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  // ---- Layout mobile bị chặn ----

  Widget _buildMobileBlock() {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.desktop_windows, size: 80, color: Colors.grey),
              const SizedBox(height: 24),
              const Text(
                'Vui lòng truy cập trang quản trị trên trình duyệt web',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Dùng thiết bị có màn hình rộng từ 900px trở lên',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: _handleLogout,
                icon: const Icon(Icons.logout),
                label: const Text('Đăng xuất'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---- Sidebar ----

  Widget _buildSidebarItem({
    required IconData icon,
    required String label,
    required int index,
    bool hasBadge = false,
  }) {
    final isSelected = _selectedIndex == index;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: ListTile(
        leading: Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(icon, color: Colors.white),
            if (hasBadge)
              Positioned(
                top: -4,
                right: -4,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
        title: Text(label, style: const TextStyle(color: Colors.white)),
        selected: isSelected,
        selectedTileColor: Colors.white.withOpacity(0.2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        onTap: () => setState(() => _selectedIndex = index),
        dense: true,
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 240,
      color: primaryPurple,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.sports_tennis, color: Colors.white, size: 28),
              SizedBox(width: 10),
              Text(
                'BCourt Admin',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(color: Colors.white.withOpacity(0.3), thickness: 1),
          const SizedBox(height: 8),
          _buildSidebarItem(icon: Icons.dashboard, label: 'Dashboard', index: 0),
          _buildSidebarItem(icon: Icons.sports_tennis, label: 'Quản lý sân', index: 1, hasBadge: _pendingCourtCount > 0),
          _buildSidebarItem(icon: Icons.people, label: 'Người dùng', index: 2, hasBadge: _pendingOwnerCount > 0),
          _buildSidebarItem(
            icon: Icons.report,
            label: 'Báo cáo',
            index: 3,
            hasBadge: _pendingReportCount > 0,
          ),
          const Spacer(),
          Divider(color: Colors.white.withOpacity(0.3), thickness: 1),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.white),
            title: const Text('Đăng xuất', style: TextStyle(color: Colors.white)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            onTap: _handleLogout,
            dense: true,
          ),
        ],
      ),
    );
  }

  // ---- Tab Courts (code cũ giữ nguyên) ----

  Widget _buildCourtsTab() {
    return StreamBuilder<List<CourtModel>>(
      stream: _dbService.getAllCourtsForAdminStream(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final courts = snapshot.data!;
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: courts.length,
          itemBuilder: (context, index) {
            final court = courts[index];
            bool isPending = court.status == 'pending';
            bool isBanned = court.status == 'banned';
            return Card(
              child: ListTile(
                title: Text(court.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('Trạng thái: ${court.status.toUpperCase()}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isPending || isBanned)
                      IconButton(
                        icon: const Icon(Icons.check_circle, color: Colors.green),
                        tooltip: 'Duyệt / Mở hoạt động',
                        onPressed: () async {
                          final ok = await _dbService.updateCourtStatus(court.id, 'active');
                          if (ok && isPending) {
                            await _dbService.sendNotification(
                              recipientId: court.ownerId,
                              title: 'Sân đã được admin duyệt',
                              body: 'Câu lạc bộ "${court.name}" đã được phê duyệt và hiển thị cho khách hàng.',
                              type: 'court_approved',
                              relatedId: court.id,
                            );
                          }
                        },
                      ),
                    if (!isBanned)
                      IconButton(
                        icon: const Icon(Icons.block, color: Colors.red),
                        tooltip: 'Đình chỉ sân',
                        onPressed: () => _dbService.updateCourtStatus(court.id, 'banned'),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ---- Tab Users (code cũ giữ nguyên) ----

  Widget _buildUsersTab() {
    return StreamBuilder<List<UserModel>>(
      stream: _dbService.getAllUsersStream(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final users = snapshot.data!;
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: users.length,
          itemBuilder: (context, index) {
            final user = users[index];
            if (user.role == 'admin') return const SizedBox.shrink();
            final isPendingApproval = user.status == 'pending_approval';
            final isBanned = user.status == 'banned' ||
                user.status == 'banned_permanent' ||
                user.status == 'banned_temporary';
            return Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: user.role == 'owner' ? Colors.orange : Colors.blue,
                  child: Icon(
                    user.role == 'owner' ? Icons.store : Icons.person,
                    color: Colors.white,
                  ),
                ),
                title: Row(
                  children: [
                    Flexible(child: Text(user.fullName, style: const TextStyle(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
                    if (isPendingApproval) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(4)),
                        child: const Text('Chờ duyệt', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ],
                ),
                subtitle: Text('${user.email}\nVai trò: ${user.role.toUpperCase()} | ${user.status}'),
                isThreeLine: true,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isPendingApproval)
                      IconButton(
                        icon: const Icon(Icons.check_circle, color: Colors.green),
                        tooltip: 'Duyệt tài khoản',
                        onPressed: () => _dbService.updateUserStatus(user.uid, 'active'),
                      ),
                    if (!isPendingApproval)
                      IconButton(
                        icon: Icon(isBanned ? Icons.lock_open : Icons.lock, color: isBanned ? Colors.green : Colors.red),
                        tooltip: isBanned ? 'Mở khóa tài khoản' : 'Khóa tài khoản',
                        onPressed: () => _dbService.updateUserStatus(user.uid, isBanned ? 'active' : 'banned'),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ---- Web layout ----

  Widget _buildWebLayout() {
    return Scaffold(
      body: Row(
        children: [
          _buildSidebar(),
          Expanded(
            child: Container(
              color: Colors.grey[100],
              padding: const EdgeInsets.all(24),
              child: IndexedStack(
                index: _selectedIndex,
                children: [
                  const AdminDashboardTab(),
                  _buildCourtsTab(),
                  _buildUsersTab(),
                  const AdminReportsTab(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 900) return _buildMobileBlock();
        return _buildWebLayout();
      },
    );
  }
}
