import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../models/court_model.dart';
import '../../../models/user_model.dart';
import '../../../services/auth_service.dart';
import '../../../services/database_service.dart';
import '../../auth/views/login_screen.dart';
import 'add_court_screen.dart';
import 'owner_court_detail_screen.dart';
import 'select_court_for_bank_screen.dart';

class OwnerHomeScreen extends StatefulWidget {
  const OwnerHomeScreen({super.key});

  @override
  State<OwnerHomeScreen> createState() => _OwnerHomeScreenState();
}

class _OwnerHomeScreenState extends State<OwnerHomeScreen> {
  final DatabaseService _dbService = DatabaseService();
  final AuthService _authService = AuthService();
  final String currentUserId = FirebaseAuth.instance.currentUser!.uid;

  UserModel? _currentUser;
  final Color primaryPurple = const Color(0xFFBF89F5);

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  // Tải thông tin Chủ sân để hiển thị lên AppBar và Drawer
  Future<void> _loadUserData() async {
    final user = await _authService.getCurrentUserData();
    if (mounted) {
      setState(() => _currentUser = user);
    }
  }

  void _handleLogout(BuildContext context) async {
    await _authService.signOut();
    if (context.mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: primaryPurple,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Quản lý hệ thống Câu lạc bộ',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.normal,
                  color: Colors.white70),
            ),
            Text(
              _currentUser != null
                  ? 'Xin chào, ${_currentUser!.fullName}'
                  : 'Đang tải...',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _handleLogout(context),
            tooltip: 'Đăng xuất',
          ),
        ],
      ),
      drawer: Drawer(
        child: Column(
          children: [
            UserAccountsDrawerHeader(
              decoration: BoxDecoration(color: primaryPurple),
              currentAccountPicture: const CircleAvatar(
                backgroundColor: Colors.white,
                child: Icon(Icons.store, size: 40, color: Color(0xFFBF89F5)),
              ),
              accountName: Text(
                _currentUser?.fullName ?? '',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              accountEmail: Text(_currentUser?.email ?? ''),
            ),
            ListTile(
              leading: const Icon(Icons.account_balance),
              title: const Text('Chỉnh thông tin ngân hàng'),
              onTap: () {
                Navigator.pop(context); // Đóng drawer trước
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SelectCourtForBankScreen(
                      ownerId: currentUserId,
                    ),
                  ),
                );
              },
            ),
            const Spacer(),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Đăng xuất',
                  style: TextStyle(color: Colors.red)),
              onTap: () => _handleLogout(context),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
      body: StreamBuilder<List<CourtModel>>(
        stream: _dbService.getOwnerCourtsStream(currentUserId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
                child: CircularProgressIndicator(color: primaryPurple));
          }

          if (snapshot.hasError) {
            return const Center(
                child: Text('Đã xảy ra lỗi khi tải dữ liệu.'));
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.storefront_outlined,
                      size: 80, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  const Text(
                    'Bạn chưa tạo sân nào.\nHãy bấm nút "Thêm sân" bên dưới để bắt đầu!',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          final courts = snapshot.data!;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: courts.length,
            itemBuilder: (context, index) {
              final court = courts[index];
              return Card(
                elevation: 4,
                margin: const EdgeInsets.only(bottom: 20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(15),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            OwnerCourtDetailScreen(court: court),
                      ),
                    );
                  },
                  child: Row(
                    children: [
                      // Hình ảnh sân
                      ClipRRect(
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(15),
                          bottomLeft: Radius.circular(15),
                        ),
                        child: SizedBox(
                          width: 130,
                          height: 110,
                          child: court.images.isNotEmpty
                              ? Image.network(
                                  court.images.first,
                                  fit: BoxFit.cover,
                                  loadingBuilder: (context, child, progress) {
                                    if (progress == null) return child;
                                    return Center(
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: primaryPurple));
                                  },
                                  errorBuilder: (context, error, stackTrace) =>
                                      Container(
                                          color: Colors.grey[200],
                                          child: const Icon(
                                              Icons.image_not_supported,
                                              color: Colors.grey)),
                                )
                              : Container(
                                  color: Colors.grey[200],
                                  child: const Icon(Icons.image,
                                      color: Colors.grey, size: 40),
                                ),
                        ),
                      ),

                      // Thông tin sân
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                court.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 18),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: primaryPurple.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Quy mô: ${court.subCourts.length} sân',
                                  style: TextStyle(
                                      color: primaryPurple,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${(court.pricePerHour / 1000).toStringAsFixed(0)}k/giờ',
                                style: const TextStyle(
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Icon chỉ dẫn
                      Padding(
                        padding: const EdgeInsets.only(right: 16),
                        child: Icon(Icons.arrow_forward_ios,
                            size: 18, color: primaryPurple),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddCourtScreen()),
          );
        },
        backgroundColor: primaryPurple,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Thêm sân',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }
}
