import 'dart:developer';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotif = FlutterLocalNotificationsPlugin();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Gọi 1 lần duy nhất trong main.dart sau Firebase.initializeApp
  Future<void> initialize() async {
    // Xin quyền thông báo
    await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Khởi tạo local notifications (hiển thị khi app foreground)
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    await _localNotif.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
    );

    // Tạo notification channel Android
    const channel = AndroidNotificationChannel(
      'bcourt_notifications',
      'Thông báo BCourt',
      description: 'Thông báo từ ứng dụng BCourt',
      importance: Importance.high,
    );
    await _localNotif
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    // Đăng ký sẵn listener onTokenRefresh ngay từ đầu:
    // - Covers lần đầu token được cấp (kể cả khi getToken() trả null lúc login)
    // - Covers khi FCM rotate token định kỳ
    _fcm.onTokenRefresh.listen((newToken) async {
      final String? uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await _firestore
            .collection('users')
            .doc(uid)
            .update({'fcmToken': newToken});
        log('FCM token tự động cập nhật cho user $uid');
      }
    });

    // Lắng nghe message khi app đang mở (foreground)
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Lắng nghe khi user bấm vào notification để mở app
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);
  }

  /// Lấy FCM token và lưu vào Firestore document của user.
  /// Nếu token chưa sẵn sàng (null), onTokenRefresh sẽ tự lưu khi token được cấp.
  Future<void> saveTokenToFirestore() async {
    try {
      final String? uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      final String? token = await _fcm.getToken();

      if (token != null) {
        await _firestore.collection('users').doc(uid).update({'fcmToken': token});
        log('Đã lưu FCM token cho user $uid');
      } else {
        // Token chưa sẵn sàng — onTokenRefresh (đã đăng ký trong initialize) sẽ lưu sau
        log('FCM token chưa sẵn sàng, sẽ tự động lưu khi token được cấp');
      }
    } catch (e) {
      log('Lỗi lưu FCM token: $e');
    }
  }

  /// Xóa FCM token khi đăng xuất
  Future<void> clearToken() async {
    try {
      final String? uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await _firestore
            .collection('users')
            .doc(uid)
            .update({'fcmToken': FieldValue.delete()});
        log('Đã xóa FCM token cho user $uid');
      }
    } catch (e) {
      log('Lỗi xóa FCM token: $e');
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    final RemoteNotification? notification = message.notification;
    if (notification != null) {
      _localNotif.show(
        notification.hashCode,
        notification.title,
        notification.body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'bcourt_notifications',
            'Thông báo BCourt',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
      );
    }
  }

  void _handleMessageOpenedApp(RemoteMessage message) {
    log('Mở app từ notification: ${message.data}');
  }
}
