import 'package:flutter/material.dart';
import '../../../models/court_model.dart';
import '../../../services/database_service.dart';

class EditCourtBankScreen extends StatefulWidget {
  final CourtModel court;

  const EditCourtBankScreen({super.key, required this.court});

  @override
  State<EditCourtBankScreen> createState() => _EditCourtBankScreenState();
}

class _EditCourtBankScreenState extends State<EditCourtBankScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _bankNameController;
  late TextEditingController _accountNumberController;
  late TextEditingController _accountNameController;

  final DatabaseService _dbService = DatabaseService();
  bool _isLoading = false;

  final Color primaryPurple = const Color(0xFFBF89F5);

  @override
  void initState() {
    super.initState();
    // Pre-fill nếu sân đã có thông tin ngân hàng từ trước
    _bankNameController =
        TextEditingController(text: widget.court.bankName ?? '');
    _accountNumberController =
        TextEditingController(text: widget.court.bankAccountNumber ?? '');
    _accountNameController =
        TextEditingController(text: widget.court.bankAccountName ?? '');
  }

  @override
  void dispose() {
    _bankNameController.dispose();
    _accountNumberController.dispose();
    _accountNameController.dispose();
    super.dispose();
  }

  void _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    // Tên chủ TK luôn lưu chữ HOA (bill chuyển khoản in hoa tên)
    final bool success = await _dbService.updateCourtBankInfo(
      widget.court.id,
      _bankNameController.text.trim(),
      _accountNumberController.text.trim(),
      _accountNameController.text.trim().toUpperCase(),
    );

    setState(() => _isLoading = false);

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã lưu thông tin ngân hàng thành công!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lưu thất bại, vui lòng thử lại!'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'Thông tin TK: ${widget.court.name}',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: primaryPurple,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Ghi chú hướng dẫn
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: primaryPurple.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: primaryPurple.withOpacity(0.3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, color: primaryPurple, size: 20),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Thông tin này sẽ hiển thị cho khách khi họ đặt cọc tại sân này. '
                        'Hãy đảm bảo thông tin chính xác.',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Tên ngân hàng
              TextFormField(
                controller: _bankNameController,
                decoration: const InputDecoration(
                  labelText: 'Tên ngân hàng',
                  hintText: 'VD: MB Bank, Vietcombank, Techcombank...',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.account_balance),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty)
                        ? 'Vui lòng nhập tên ngân hàng'
                        : null,
              ),
              const SizedBox(height: 16),

              // Số tài khoản
              TextFormField(
                controller: _accountNumberController,
                decoration: const InputDecoration(
                  labelText: 'Số tài khoản',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.credit_card),
                ),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Vui lòng nhập số tài khoản';
                  }
                  if (!RegExp(r'^[0-9]+$').hasMatch(v.trim())) {
                    return 'Số tài khoản chỉ được chứa chữ số';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Tên chủ tài khoản
              TextFormField(
                controller: _accountNameController,
                decoration: const InputDecoration(
                  labelText: 'Tên chủ tài khoản',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                  helperText: 'Sẽ tự động chuyển thành CHỮ HOA khi lưu',
                ),
                textCapitalization: TextCapitalization.characters,
                validator: (v) =>
                    (v == null || v.trim().isEmpty)
                        ? 'Vui lòng nhập tên chủ tài khoản'
                        : null,
              ),
              const SizedBox(height: 32),

              // Nút lưu
              _isLoading
                  ? Center(
                      child: CircularProgressIndicator(color: primaryPurple))
                  : ElevatedButton(
                      onPressed: _handleSave,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryPurple,
                        minimumSize: const Size(double.infinity, 55),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'LƯU THÔNG TIN',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
