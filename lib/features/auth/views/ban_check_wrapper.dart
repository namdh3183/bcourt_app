import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../../services/auth_service.dart';
import 'login_screen.dart';

/// Bọc quanh home screen — lắng nghe Firestore real-time để phát hiện ban ngay lập tức
class BanCheckWrapper extends StatefulWidget {
  final Widget child;
  const BanCheckWrapper({super.key, required this.child});

  @override
  State<BanCheckWrapper> createState() => _BanCheckWrapperState();
}

class _BanCheckWrapperState extends State<BanCheckWrapper> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();
  bool _dialogShowing = false;

  @override
  Widget build(BuildContext context) {
    final String? uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return widget.child;

    return StreamBuilder<DocumentSnapshot>(
      stream: _firestore.collection('users').doc(uid).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>;
          final String status = data['status'] ?? 'active';
          final String banReason = data['banReason'] as String? ?? 'Vi phạm quy định';

          bool isBanned = false;
          String banType = '';

          if (status == 'banned_permanent' || status == 'banned') {
            isBanned = true;
            banType = 'vĩnh viễn';
          } else if (status == 'banned_temporary') {
            final Timestamp? bannedUntil = data['bannedUntil'] as Timestamp?;
            if (bannedUntil != null && bannedUntil.toDate().isAfter(DateTime.now())) {
              isBanned = true;
              final dt = bannedUntil.toDate();
              banType = 'tạm thời (hết hạn: ${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')})';
            }
          }

          if (isBanned && !_dialogShowing) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _showBanDialog(banReason, banType);
            });
          }
        }
        return widget.child;
      },
    );
  }

  void _showBanDialog(String reason, String banType) {
    if (_dialogShowing || !mounted) return;
    _dialogShowing = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.block, color: Colors.red),
            SizedBox(width: 8),
            Text('Tài khoản bị khóa', style: TextStyle(color: Colors.red)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Loại: Ban $banType'),
            const SizedBox(height: 8),
            Text('Lý do: $reason'),
            const SizedBox(height: 12),
            const Text('Bạn sẽ bị đăng xuất ngay sau khi đóng thông báo này.'),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              await _authService.signOut();
              if (mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
            child: const Text('Đã hiểu', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
