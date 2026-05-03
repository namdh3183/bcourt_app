import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../../models/notification_model.dart';
import '../../../services/database_service.dart';

class NotificationScreen extends StatelessWidget {
  const NotificationScreen({super.key});

  static const Color _primaryPurple = Color(0xFFBF89F5);

  @override
  Widget build(BuildContext context) {
    final String? uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Scaffold(body: Center(child: Text('Chưa đăng nhập')));
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: _primaryPurple,
        foregroundColor: Colors.white,
        title: const Text('Thông báo'),
        elevation: 0,
      ),
      body: StreamBuilder<List<NotificationModel>>(
        stream: DatabaseService().getNotificationsStream(uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 12),
                    const Text(
                      'Không thể tải thông báo',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${snapshot.error}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          final notifications = snapshot.data ?? [];
          if (notifications.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_none, size: 64, color: Colors.grey),
                  SizedBox(height: 12),
                  Text(
                    'Chưa có thông báo nào',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: notifications.length,
            separatorBuilder: (_, __) =>
                const Divider(height: 1, indent: 72),
            itemBuilder: (context, index) {
              final notif = notifications[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: _primaryPurple.withOpacity(0.15),
                  child: Icon(
                    _iconForType(notif.type),
                    color: _primaryPurple,
                    size: 22,
                  ),
                ),
                title: Text(
                  notif.title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 2),
                    Text(notif.body),
                    const SizedBox(height: 4),
                    Text(
                      _relativeTime(notif.createdAt),
                      style: const TextStyle(
                          fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
                isThreeLine: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              );
            },
          );
        },
      ),
    );
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'booking_confirmed':
        return Icons.check_circle_outline;
      case 'booking_cancelled_by_owner':
      case 'booking_cancelled_by_customer':
        return Icons.cancel_outlined;
      case 'deposit_uploaded':
        return Icons.payment;
      case 'new_booking':
        return Icons.fiber_new;
      case 'fully_paid':
        return Icons.monetization_on_outlined;
      case 'admin_warning':
        return Icons.warning_amber_rounded;
      case 'admin_ban':
        return Icons.block;
      case 'court_approved':
        return Icons.sports_tennis;
      default:
        return Icons.notifications_outlined;
    }
  }

  /// Hiển thị thời gian tương đối: "vừa xong", "5 phút trước", "hôm qua"...
  String _relativeTime(Timestamp timestamp) {
    final DateTime dt = timestamp.toDate();
    final Duration diff = DateTime.now().difference(dt);

    if (diff.inSeconds < 60) return 'Vừa xong';
    if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
    if (diff.inHours < 24) return '${diff.inHours} giờ trước';
    if (diff.inDays == 1) return 'Hôm qua';
    if (diff.inDays < 7) return '${diff.inDays} ngày trước';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
