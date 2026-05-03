import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'features/auth/views/login_screen.dart';
import 'features/booking/views/customer_home_screen.dart';
import 'features/court_management/views/owner_home_screen.dart';
import 'features/admin/views/admin_home_screen.dart';
import 'models/user_model.dart';
import 'services/auth_service.dart';
import 'services/notification_service.dart';
import 'features/auth/views/ban_check_wrapper.dart';

// Xử lý FCM message khi app đang ở background/đóng (bắt buộc là top-level function)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Đăng ký background message handler trước khi runApp
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Khởi tạo notification service (xin quyền, tạo channel, lắng nghe foreground)
  if (!kIsWeb) {
    await NotificationService().initialize();
  }

  runApp(const BCourtApp());
}

class BCourtApp extends StatelessWidget {
  const BCourtApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BCourt',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color.fromARGB(255, 139, 50, 227)),
        useMaterial3: true,
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color.fromARGB(255, 139, 50, 227),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          if (snapshot.hasData) {
            return FutureBuilder<UserModel?>(
              future: AuthService().getCurrentUserData(),
              builder: (context, userSnapshot) {
                if (userSnapshot.connectionState == ConnectionState.waiting) {
                  return const Scaffold(body: Center(child: CircularProgressIndicator()));
                }
                final user = userSnapshot.data;
                if (user == null) return const LoginScreen();
                if (user.role == 'owner' && user.status == 'pending_approval') {
                  AuthService().signOut();
                  return const LoginScreen();
                }
                if (user.isBanned) {
                  AuthService().signOut();
                  return const LoginScreen();
                }
                if (kIsWeb && user.role != 'admin') {
                  AuthService().signOut();
                  return Scaffold(
                    body: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.phone_android, size: 80, color: Colors.grey),
                          const SizedBox(height: 16),
                          const Text(
                            'Vui lòng đăng nhập trên thiết bị di động',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Trang web chỉ dành cho quản trị viên',
                            style: TextStyle(color: Colors.grey),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton(
                            onPressed: () => AuthService().signOut(),
                            child: const Text('Quay lại đăng nhập'),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                switch (user.role) {
                  case 'admin':
                    return const AdminHomeScreen();
                  case 'owner':
                    return const BanCheckWrapper(child: OwnerHomeScreen());
                  default:
                    return const BanCheckWrapper(child: CustomerHomeScreen());
                }
              },
            );
          }
          return const LoginScreen();
        },
      ),
    );
  }
}
