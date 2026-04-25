import 'package:flutter/material.dart';
import '../../../services/auth_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String _selectedRole = 'customer';
  
  final _authService = AuthService();
  bool _isLoading = false;
  bool _obscurePassword = true;

  final Color primaryPurple = const Color(0xFFBF89F5);

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Vui lòng nhập mật khẩu';
    if (value.length < 8) return 'Mật khẩu tối thiểu 8 ký tự';
    if (!RegExp(r'[A-Z]').hasMatch(value)) return 'Cần ít nhất 1 chữ hoa';
    if (!RegExp(r'[0-9]').hasMatch(value)) return 'Cần ít nhất 1 số';
    return null;
  }

  void _handleRegister() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      final newUser = await _authService.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        fullName: _fullNameController.text.trim(),
        phone: _phoneController.text.trim(),
        role: _selectedRole,
      );

      setState(() => _isLoading = false);

      if (newUser != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đăng ký thành công!')),
          );
          Navigator.pop(context); 
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đăng ký thất bại. Email có thể đã tồn tại.')),
          );
        }
      }
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Đăng ký tài khoản', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        foregroundColor: primaryPurple,
      ),
      body: SingleChildScrollView( 
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Icon(Icons.person_add_alt_1, size: 60, color: primaryPurple.withOpacity(0.5)),
              const SizedBox(height: 24),
              TextFormField(
                controller: _fullNameController,
                decoration: InputDecoration(
                  labelText: 'Họ và tên', 
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: Icon(Icons.person, color: primaryPurple),
                ),
                validator: (value) => value!.isEmpty ? 'Vui lòng nhập họ tên' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                decoration: InputDecoration(
                  labelText: 'Số điện thoại', 
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: Icon(Icons.phone, color: primaryPurple),
                ),
                keyboardType: TextInputType.phone,
                validator: (value) => value!.isEmpty ? 'Vui lòng nhập số điện thoại' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: 'Email', 
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: Icon(Icons.email, color: primaryPurple),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) => value!.isEmpty ? 'Vui lòng nhập email' : null,
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
                validator: _validatePassword,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _selectedRole,
                decoration: InputDecoration(
                  labelText: 'Bạn là:', 
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: Icon(Icons.assignment_ind, color: primaryPurple),
                ),
                items: const [
                  DropdownMenuItem(value: 'customer', child: Text('Khách hàng (Tìm sân)')),
                  DropdownMenuItem(value: 'owner', child: Text('Chủ sân (Quản lý sân)')),
                ],
                onChanged: (value) {
                  setState(() => _selectedRole = value!);
                },
              ),
              const SizedBox(height: 32),
              _isLoading
                  ? CircularProgressIndicator(color: primaryPurple)
                  : ElevatedButton(
                      onPressed: _handleRegister,
                      style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 55)),
                      child: const Text('Đăng ký', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}