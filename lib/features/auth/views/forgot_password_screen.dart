import 'package:flutter/material.dart';
import '../../../services/auth_service.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  final _authService = AuthService();
  bool _isLoading = false;

  final Color primaryPurple = const Color(0xFFBF89F5);

  void _handleResetPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập email của bạn!')),
      );
      return;
    }

    setState(() => _isLoading = true);
    
    bool success = await _authService.resetPassword(email);
    
    setState(() => _isLoading = false);

    if (mounted) {
      if (success) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text('Thành công', style: TextStyle(color: primaryPurple, fontWeight: FontWeight.bold)),
            content: const Text('Một email chứa liên kết đặt lại mật khẩu đã được gửi đến hộp thư của bạn. Vui lòng kiểm tra (cả trong mục Spam).'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context); // Đóng Dialog
                  Navigator.pop(context); // Quay về trang đăng nhập
                },
                child: Text('Đã hiểu', style: TextStyle(color: primaryPurple)),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không thể gửi email. Vui lòng kiểm tra lại địa chỉ email!')),
        );
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Khôi phục mật khẩu', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        foregroundColor: primaryPurple,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(Icons.lock_reset, size: 80, color: primaryPurple.withOpacity(0.5)),
            const SizedBox(height: 24),
            const Text(
              'Nhập email bạn đã đăng ký để nhận liên kết đặt lại mật khẩu.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.black87),
            ),
            const SizedBox(height: 32),
            TextFormField(
              controller: _emailController,
              decoration: InputDecoration(
                labelText: 'Email của bạn',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: Icon(Icons.email, color: primaryPurple),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 32),
            _isLoading
                ? CircularProgressIndicator(color: primaryPurple)
                : ElevatedButton(
                    onPressed: _handleResetPassword,
                    style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 55)),
                    child: const Text('Gửi yêu cầu', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
          ],
        ),
      ),
    );
  }
}