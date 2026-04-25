import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../../models/user_model.dart';
import '../../../services/auth_service.dart';
import '../../booking/views/customer_home_screen.dart';
import '../../court_management/views/owner_home_screen.dart';
import 'register_screen.dart';
import '../../admin/views/admin_home_screen.dart';
import 'forgot_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  bool _isLoading = false;
  bool _obscurePassword = true;

  final Color primaryPurple = const Color(0xFFBF89F5);

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleLogin() async {
    setState(() => _isLoading = true);

    final user = await _authService.signIn(
      email: _emailController.text.trim(),
      password: _passwordController.text.trim(),
    );

    if (user != null) {
      final userModel = await _authService.getCurrentUserData();
      setState(() => _isLoading = false);

      if (userModel != null && mounted) {
        if (userModel.role == 'owner' && userModel.status == 'pending_approval') {
          await _authService.signOut();
          if (mounted) _showPendingApprovalDialog();
          return;
        }
        if (userModel.isBanned) {
          await _authService.signOut();
          if (mounted) _showBannedDialog(userModel);
          return;
        }
        _navigateToHome(userModel.role);
      }
    } else {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đăng nhập thất bại. Vui lòng kiểm tra lại!')),
        );
      }
    }
  }

  void _showPendingApprovalDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.hourglass_top, color: Colors.orange),
            SizedBox(width: 8),
            Text('Tài khoản chờ duyệt', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'Tài khoản chủ sân của bạn đang chờ admin duyệt. Vui lòng chờ.',
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Đóng', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showBannedDialog(UserModel user) {
    String message;
    if (user.status == 'banned_permanent' || user.status == 'banned') {
      message = 'Tài khoản đã bị khóa vĩnh viễn. Liên hệ admin để biết thêm chi tiết.';
    } else {
      String deadline = user.bannedUntil != null
          ? DateFormat('HH:mm dd/MM/yyyy').format(user.bannedUntil!.toDate())
          : 'không xác định';
      message = 'Tài khoản bị khóa đến $deadline. Vui lòng thử lại sau.';
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.block, color: Colors.red),
            SizedBox(width: 8),
            Text('Tài khoản bị khóa', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            if (user.banReason != null && user.banReason!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Lý do: ${user.banReason}',
                style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w500),
              ),
            ],
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Đóng', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _handleGoogleSignIn() async {
    setState(() => _isLoading = true);

    final User? firebaseUser = await _authService.signInWithGoogleBase();

    if (firebaseUser != null) {
      var userModel = await _authService.getUserFromFirestore(firebaseUser.uid);

      if (userModel == null) {
        if (mounted) {
          String? selectedRole = await _showRoleSelectionDialog(context);
          if (selectedRole != null) {
            userModel = await _authService.createGoogleUserInFirestore(firebaseUser, selectedRole);
          }
        }
      }

      setState(() => _isLoading = false);

      if (mounted && userModel != null) {
        if (userModel.role == 'owner' && userModel.status == 'pending_approval') {
          await _authService.signOut();
          if (mounted) _showPendingApprovalDialog();
          return;
        }
        if (userModel.isBanned) {
          await _authService.signOut();
          if (mounted) _showBannedDialog(userModel);
          return;
        }
        _navigateToHome(userModel.role);
      }
    } else {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã hủy đăng nhập Google.')),
        );
      }
    }
  }

  Future<String?> _showRoleSelectionDialog(BuildContext context) async {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Chào mừng đến BCourt!', style: TextStyle(color: primaryPurple, fontWeight: FontWeight.bold)),
          content: const Text('Vui lòng chọn vai trò để tiếp tục:'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, 'customer'),
              child: Text('Khách hàng', style: TextStyle(color: primaryPurple)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, 'owner'),
              child: Text('Chủ sân', style: TextStyle(color: primaryPurple)),
            ),
          ],
        );
      },
    );
  }

  void _navigateToHome(String role) async {
    if (kIsWeb && role != 'admin') {
      await _authService.signOut();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Trang web chỉ dành cho admin. Vui lòng dùng ứng dụng di động.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }
    if (role == 'customer') {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const CustomerHomeScreen()));
    } else if (role == 'owner') {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const OwnerHomeScreen()));
    } else if (role == 'admin') {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const AdminHomeScreen()));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tài khoản chưa được phân quyền.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Loại bỏ AppBar, dùng SafeArea để không lẹm vào tai thỏ/đảo động
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // --- PHẦN LOGO & TIÊU ĐỀ ---
                Icon(
                  Icons.sports_tennis, // Icon tạm thời, có thể đổi sang Image.asset nếu có PNG
                  size: 100,
                  color: Color.fromARGB(255, 139, 50, 227),
                ),
                const SizedBox(height: 8),
                Text(
                  'BCourt',
                  style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.w900,
                    color: primaryPurple,
                    letterSpacing: 1.5,
                  ),
                ),
                Text(
                  'Đặt sân cầu lông nhanh chóng',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
                const SizedBox(height: 48),

                // --- PHẦN FORM NHẬP LIỆU ---
                TextFormField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: Icon(Icons.email, color: primaryPurple),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: 'Mật khẩu',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: Icon(Icons.lock, color: primaryPurple),
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: primaryPurple),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  obscureText: _obscurePassword,
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const ForgotPasswordScreen()),
                      );
                    },
                    child: Text(
                      'Quên mật khẩu?',
                      style: TextStyle(color: primaryPurple, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // --- NÚT ĐĂNG NHẬP ---
                _isLoading
                    ? CircularProgressIndicator(color: primaryPurple)
                    : ElevatedButton(
                        onPressed: _handleLogin,
                        style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 55)),
                        child: const Text('Đăng nhập', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
                const SizedBox(height: 16),

                // Nút chuyển sang Đăng ký
                TextButton(
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const RegisterScreen()));
                  },
                  child: RichText(
                    text: TextSpan(
                      text: 'Chưa có tài khoản? ',
                      style: TextStyle(color: Colors.grey[600], fontSize: 15),
                      children: [
                        TextSpan(
                          text: 'Đăng ký ngay',
                          style: TextStyle(color: primaryPurple, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Row(
                    children: [
                      Expanded(child: Divider(thickness: 1, color: Colors.grey[300])),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text('Hoặc', style: TextStyle(fontSize: 14, color: Colors.grey[500])),
                      ),
                      Expanded(child: Divider(thickness: 1, color: Colors.grey[300])),
                    ],
                  ),
                ),

                // --- NÚT GOOGLE ---
                OutlinedButton.icon(
                  onPressed: _isLoading ? null : _handleGoogleSignIn,
                  icon: const Icon(Icons.g_mobiledata, size: 36, color: Colors.red),
                  label: const Text(
                    'Đăng nhập bằng Google',
                    style: TextStyle(color: Colors.black87, fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 55),
                    side: BorderSide(color: Colors.grey[300]!),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}