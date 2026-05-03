import 'package:flutter/material.dart';
import '../../../models/court_model.dart';
import '../../../services/database_service.dart';

class EditCourtScreen extends StatefulWidget {
  final CourtModel court;

  const EditCourtScreen({super.key, required this.court});

  @override
  State<EditCourtScreen> createState() => _EditCourtScreenState();
}

class _EditCourtScreenState extends State<EditCourtScreen> {
  final _formKey = GlobalKey<FormState>();

  // SECTION 1: Thông tin sân
  late TextEditingController _nameController;
  late TextEditingController _priceController;
  late TextEditingController _subCourtCountController;
  late TextEditingController _addressController;
  late String _status;

  final DatabaseService _dbService = DatabaseService();
  bool _isLoading = false;

  final Color primaryPurple = const Color(0xFFBF89F5);

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.court.name);
    _priceController =
        TextEditingController(text: widget.court.pricePerHour.toString());
    _subCourtCountController =
        TextEditingController(text: widget.court.subCourts.length.toString());
    _addressController =
        TextEditingController(text: widget.court.address ?? '');
    _status = ['active', 'inactive'].contains(widget.court.status)
        ? widget.court.status
        : 'active';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _subCourtCountController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  void _handleUpdateCourt() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    int count = int.parse(_subCourtCountController.text.trim());
    List<String> updatedSubCourts = [];

    // Giữ tên cũ nếu có, tạo mới nếu tăng số lượng
    for (int i = 0; i < count; i++) {
      if (i < widget.court.subCourts.length) {
        updatedSubCourts.add(widget.court.subCourts[i]);
      } else {
        updatedSubCourts.add('Sân ${i + 1}');
      }
    }

    CourtModel updatedCourt = CourtModel(
      id: widget.court.id,
      name: _nameController.text.trim(),
      ownerId: widget.court.ownerId,
      address: _addressController.text.trim().isNotEmpty
          ? _addressController.text.trim()
          : null,
      pricePerHour: double.parse(_priceController.text.trim()),
      images: widget.court.images,
      status: _status,
      subCourts: updatedSubCourts,
      // Giữ nguyên bank info — chỉnh qua màn hình riêng
      bankName: widget.court.bankName,
      bankAccountNumber: widget.court.bankAccountNumber,
      bankAccountName: widget.court.bankAccountName,
    );

    bool success = await _dbService.updateCourt(updatedCourt);

    setState(() => _isLoading = false);

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cập nhật thành công!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cập nhật thất bại, vui lòng thử lại!'),
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
        title: const Text('Sửa thông tin CLB',
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
                  labelText: 'Số lượng sân nhỏ',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.grid_view),
                ),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Vui lòng nhập số lượng';
                  if (int.tryParse(v.trim()) == null || int.parse(v.trim()) <= 0) {
                    return 'Phải lớn hơn 0';
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

              DropdownButtonFormField<String>(
                initialValue: _status,
                decoration: const InputDecoration(
                  labelText: 'Trạng thái',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.toggle_on),
                ),
                items: const [
                  DropdownMenuItem(value: 'active', child: Text('Đang hoạt động')),
                  DropdownMenuItem(value: 'inactive', child: Text('Tạm nghỉ')),
                ],
                onChanged: (value) => setState(() => _status = value!),
              ),
              const SizedBox(height: 32),

              // Nút lưu
              _isLoading
                  ? Center(
                      child: CircularProgressIndicator(color: primaryPurple))
                  : ElevatedButton(
                      onPressed: _handleUpdateCourt,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryPurple,
                        minimumSize: const Size(double.infinity, 55),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('LƯU THAY ĐỔI',
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
