import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import '../../../models/court_model.dart';
import '../../../services/database_service.dart';

class AddCourtScreen extends StatefulWidget {
  const AddCourtScreen({super.key});

  @override
  State<AddCourtScreen> createState() => _AddCourtScreenState();
}

class _AddCourtScreenState extends State<AddCourtScreen> {
  final _formKey = GlobalKey<FormState>();

  // SECTION 1: Thông tin sân
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _subCourtCountController = TextEditingController();
  final _addressController = TextEditingController();

  // SECTION 2: Thông tin thanh toán
  final _bankNameController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _accountNameController = TextEditingController();

  final DatabaseService _dbService = DatabaseService();
  final ImagePicker _picker = ImagePicker();

  List<File> _selectedImages = [];
  bool _isLoading = false;

  final Color primaryPurple = const Color(0xFFBF89F5);

  Future<void> _pickImages() async {
    try {
      final List<XFile> pickedFiles = await _picker.pickMultiImage();
      if (pickedFiles.isNotEmpty) {
        setState(() {
          _selectedImages
              .addAll(pickedFiles.map((xFile) => File(xFile.path)).toList());
          if (_selectedImages.length > 3) {
            _selectedImages = _selectedImages.sublist(0, 3);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Chỉ được chọn tối đa 3 ảnh.')),
            );
          }
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Lỗi khi chọn ảnh, vui lòng thử lại!'),
            backgroundColor: Colors.red),
      );
    }
  }

  void _removeImage(int index) {
    setState(() => _selectedImages.removeAt(index));
  }

  void _handleAddCourt() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final String ownerId = FirebaseAuth.instance.currentUser!.uid;

    int subCourtCount = int.parse(_subCourtCountController.text.trim());
    List<String> subCourtsList =
        List.generate(subCourtCount, (index) => 'Sân ${index + 1}');

    CourtModel tempCourt = CourtModel(
      id: '',
      name: _nameController.text.trim(),
      ownerId: ownerId,
      address: _addressController.text.trim(),
      pricePerHour: double.parse(_priceController.text.trim()),
      images: [],
      status: 'pending',
      subCourts: subCourtsList,
      bankName: _bankNameController.text.trim(),
      bankAccountNumber: _accountNumberController.text.trim(),
      bankAccountName: _accountNameController.text.trim().toUpperCase(),
    );

    bool success =
        await _dbService.addCourtWithImages(tempCourt, _selectedImages);

    setState(() => _isLoading = false);

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Thêm sân thành công! Chờ admin duyệt.'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Có lỗi xảy ra, vui lòng thử lại!'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _subCourtCountController.dispose();
    _addressController.dispose();
    _bankNameController.dispose();
    _accountNumberController.dispose();
    _accountNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Thêm CLB / Sân mới',
            style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: primaryPurple,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ===== SECTION 1: THÔNG TIN SÂN =====
              _buildSectionHeader('THÔNG TIN SÂN'),
              const SizedBox(height: 12),

              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Tên cơ sở / CLB',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.storefront),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Vui lòng nhập tên' : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _priceController,
                decoration: const InputDecoration(
                  labelText: 'Giá thuê / giờ (VNĐ)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.attach_money),
                ),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Vui lòng nhập giá thuê';
                  if (double.tryParse(v.trim()) == null) return 'Giá thuê phải là số hợp lệ';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _subCourtCountController,
                decoration: const InputDecoration(
                  labelText: 'Số lượng sân nhỏ bên trong',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.grid_view),
                ),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Vui lòng nhập số lượng sân';
                  if (int.tryParse(v.trim()) == null || int.parse(v.trim()) <= 0) {
                    return 'Số lượng phải lớn hơn 0';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(
                  labelText: 'Địa chỉ',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.location_on),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Vui lòng nhập địa chỉ' : null,
              ),
              const SizedBox(height: 16),

              // Hình ảnh sân
              Text('Hình ảnh sân (tối đa 3 ảnh):',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700])),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (_selectedImages.length < 3)
                    GestureDetector(
                      onTap: _pickImages,
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child:
                            const Icon(Icons.add_a_photo, size: 40, color: Colors.grey),
                      ),
                    ),
                  ...List.generate(_selectedImages.length, (index) {
                    return Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(_selectedImages[index],
                              width: 100, height: 100, fit: BoxFit.cover),
                        ),
                        Positioned(
                          right: 0,
                          top: 0,
                          child: GestureDetector(
                            onTap: () => _removeImage(index),
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                  color: Colors.red, shape: BoxShape.circle),
                              child: const Icon(Icons.close,
                                  size: 16, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    );
                  }),
                ],
              ),
              const SizedBox(height: 32),

              // ===== SECTION 2: THÔNG TIN THANH TOÁN =====
              _buildSectionHeader('THÔNG TIN THANH TOÁN'),
              const SizedBox(height: 4),
              Text(
                'Thông tin này sẽ hiển thị cho khách khi đặt cọc.',
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _bankNameController,
                decoration: const InputDecoration(
                  labelText: 'Tên ngân hàng',
                  hintText: 'VD: MB Bank, Vietcombank...',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.account_balance),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Vui lòng nhập tên ngân hàng' : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _accountNumberController,
                decoration: const InputDecoration(
                  labelText: 'Số tài khoản',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.credit_card),
                ),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Vui lòng nhập số tài khoản';
                  if (!RegExp(r'^[0-9]+$').hasMatch(v.trim())) {
                    return 'Số tài khoản chỉ được chứa chữ số';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

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
                    (v == null || v.trim().isEmpty) ? 'Vui lòng nhập tên chủ tài khoản' : null,
              ),
              const SizedBox(height: 32),

              // Nút lưu
              _isLoading
                  ? Center(
                      child: CircularProgressIndicator(color: primaryPurple))
                  : ElevatedButton(
                      onPressed: _handleAddCourt,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryPurple,
                        minimumSize: const Size(double.infinity, 55),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('LƯU THÔNG TIN',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white)),
                    ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: primaryPurple,
        letterSpacing: 0.5,
      ),
    );
  }
}
