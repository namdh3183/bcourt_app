import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:developer';
import '../models/user_model.dart';
import '../services/database_service.dart';
import 'package:google_sign_in/google_sign_in.dart' as g_auth;

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final g_auth.GoogleSignIn _googleSignIn = g_auth.GoogleSignIn();
  final DatabaseService _dbService = DatabaseService();

  // 1. Hàm Đăng ký (Sign Up) bằng Email & Password
  Future<UserModel?> signUp({
    required String email,
    required String password,
    required String fullName,
    required String phone,
    required String role, 
  }) async {
    try {
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      String uid = userCredential.user!.uid;

      UserModel newUser = UserModel(
        uid: uid,
        fullName: fullName,
        email: email,
        phone: phone,
        role: role,
        status: role == 'owner' ? 'pending_approval' : 'active',
        createdAt: Timestamp.now(),
      );

      await _firestore.collection('users').doc(uid).set(newUser.toMap());

      return newUser;
    } catch (e) {
      log("Lỗi khi đăng ký: $e"); 
      return null; 
    }
  }

  // 2. Hàm Đăng nhập (Sign In) bằng Email & Password
  Future<User?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return result.user;
    } catch (e) {
      log("Lỗi khi đăng nhập: $e"); 
      return null;
    }
  }

  // 3. Hàm Đăng xuất (Sign Out)
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      log("Lỗi khi đăng xuất: $e"); 
    }
  }

  // 4. Hàm lấy thông tin chi tiết của User đang đăng nhập
  // Tự động gỡ ban nếu hết hạn, tính toán flag isBanned
  Future<UserModel?> getCurrentUserData() async {
    try {
      User? currentUser = _auth.currentUser;
      if (currentUser == null) return null;

      // Kiểm tra và gỡ ban tạm thời nếu đã hết hạn
      await _dbService.checkAndUnbanIfExpired(currentUser.uid);

      // Re-fetch sau khi có thể đã gỡ ban
      DocumentSnapshot doc = await _firestore.collection('users').doc(currentUser.uid).get();
      if (!doc.exists) return null;

      UserModel user = UserModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);

      // Tính toán isBanned dựa trên status và bannedUntil
      bool banned = _calculateIsBanned(user);
      if (banned) {
        // Trả về user với isBanned = true để LoginScreen xử lý
        return UserModel(
          uid: user.uid,
          fullName: user.fullName,
          email: user.email,
          phone: user.phone,
          role: user.role,
          createdAt: user.createdAt,
          status: user.status,
          bannedUntil: user.bannedUntil,
          reportCount: user.reportCount,
          warningCount: user.warningCount,
          isBanned: true,
        );
      }
      return user;
    } catch (e) {
      log("Lỗi khi lấy dữ liệu user: $e");
      return null;
    }
  }

  // Tính toán trạng thái bị ban (hỗ trợ cả giá trị 'banned' cũ)
  bool _calculateIsBanned(UserModel user) {
    if (user.status == 'banned_permanent' || user.status == 'banned') {
      return true;
    }
    if (user.status == 'banned_temporary' && user.bannedUntil != null) {
      return user.bannedUntil!.toDate().isAfter(DateTime.now());
    }
    return false;
  }

  // 5. Hàm Đăng nhập bằng Google (Chỉ xử lý phần Firebase Auth)
  Future<User?> signInWithGoogleBase() async {
    try {
      final g_auth.GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null; // Người dùng hủy đăng nhập

      // Đã thêm await và prefix g_auth.
      final g_auth.GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      UserCredential userCredential = await _auth.signInWithCredential(credential);
      return userCredential.user;
    } catch (e) {
      log("Lỗi xác thực Google: $e");
      return null;
    }
  }

  // 6. Kiểm tra user đã tồn tại trong Firestore chưa (Dùng cho luồng Google)
  Future<UserModel?> getUserFromFirestore(String uid) async {
    try {
      DocumentSnapshot doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        return UserModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }
      return null;
    } catch (e) {
      log("Lỗi khi lấy thông tin user từ Firestore: $e");
      return null;
    }
  }

  // 7. Tạo mới user sau khi đã chọn Role từ Popup (Dùng cho luồng Google)
  Future<UserModel?> createGoogleUserInFirestore(User user, String role) async {
    try {
      UserModel newUser = UserModel(
        uid: user.uid,
        fullName: user.displayName ?? 'Người dùng Google',
        email: user.email ?? '',
        phone: user.phoneNumber ?? '',
        role: role,
        status: role == 'owner' ? 'pending_approval' : 'active',
        createdAt: Timestamp.now(),
      );
      
      await _firestore.collection('users').doc(user.uid).set(newUser.toMap());
      return newUser;
    } catch (e) {
      log("Lỗi khi tạo user Google mới trên Firestore: $e");
      return null;
    }
  }

  // 8. Hàm gửi Email khôi phục mật khẩu
  Future<bool> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return true;
    } catch (e) {
      log("Lỗi khi gửi email khôi phục mật khẩu: $e");
      return false;
    }
  }

}