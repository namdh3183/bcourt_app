import 'package:flutter/material.dart';
import '../../../models/court_model.dart';
import '../../../models/user_model.dart';
import '../../../services/database_service.dart';
import '../../../services/auth_service.dart';
import '../../auth/views/login_screen.dart';
import 'booking_history_screen.dart';
import 'sub_court_selection_screen.dart';

class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({super.key});

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  final DatabaseService _dbService = DatabaseService();
  final AuthService _authService = AuthService();
  
  UserModel? _currentUser;
  String _searchQuery = "";
  String _priceRange = "Tất cả"; // Mốc lọc giá
  
  final Color primaryPurple = const Color(0xFFBF89F5);

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = await _authService.getCurrentUserData();
    if (mounted) {
      setState(() {
        _currentUser = user;
      });
    }
  }

  void _handleLogout() async {
    await _authService.signOut();
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  // --- HÀM HỖ TRỢ: LOẠI BỎ DẤU TIẾNG VIỆT ---
  String _removeDiacritics(String str) {
    const withDiacritics = 'áàảãạăắằẳẵặâấầẩẫậéèẻẽẹêếềểễệíìỉĩịóòỏõọôốồổỗộơớờởỡợúùủũụưứừửữựýỳỷỹỵđÁÀẢÃẠĂẮẰẲẴẶÂẤẦẨẪẬÉÈẺẼẸÊẾỀỂỄỆÍÌỈĨỊÓÒỎÕỌÔỐỒỔỖỘƠỚỜỞỠỢÚÙỦŨỤƯỨỪỬỮỰÝỲỶỸỴĐ';
    const withoutDiacritics = 'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyydAAAAAAAAAAAAAAAAAEEEEEEEEEEEIIIIIOOOOOOOOOOOOOOOOOUUUUUUUUUUUYYYYYD';
    String result = str;
    for (int i = 0; i < withDiacritics.length; i++) {
      result = result.replaceAll(withDiacritics[i], withoutDiacritics[i]);
    }
    return result;
  }

  // --- HÀM LỌC TÌM KIẾM THÔNG MINH ---
  List<CourtModel> _filterCourts(List<CourtModel> allCourts) {
    // 1. Chuẩn hóa từ khóa tìm kiếm (bỏ dấu, in thường, xóa khoảng trắng thừa)
    String normalizedQuery = _removeDiacritics(_searchQuery.toLowerCase().trim());
    List<String> queryWords = normalizedQuery.split(' '); // Tách thành các từ lẻ

    return allCourts.where((court) {
      // Chuẩn hóa tên sân
      String normalizedCourtName = _removeDiacritics(court.name.toLowerCase());
      
      // Kiểm tra xem tên sân có chứa TẤT CẢ các từ khóa người dùng gõ không
      bool matchesName = queryWords.every((word) => normalizedCourtName.contains(word));
      
      // 2. Lọc theo khoảng giá mới
      bool matchesPrice = true;
      if (_priceRange == "50k - 70k") {
        matchesPrice = court.pricePerHour >= 50000 && court.pricePerHour <= 70000;
      } else if (_priceRange == "70k - 100k") {
        matchesPrice = court.pricePerHour > 70000 && court.pricePerHour <= 100000;
      } else if (_priceRange == "100k - 200k") {
        matchesPrice = court.pricePerHour > 100000 && court.pricePerHour <= 200000;
      } else if (_priceRange == "Trên 200k") {
        matchesPrice = court.pricePerHour > 200000;
      }

      return matchesName && matchesPrice;
    }).toList();
  }

  // Modal hiển thị chi tiết thông tin sân
  void _showCourtDetailsModal(CourtModel court) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          maxChildSize: 0.9,
          minChildSize: 0.5,
          expand: false,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: Container(width: 50, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)))),
                  const SizedBox(height: 20),
                  Text(court.name, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('${court.pricePerHour.toStringAsFixed(0)} VNĐ/giờ', style: TextStyle(fontSize: 20, color: primaryPurple, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  const Text('Hình ảnh sân:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 200,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: court.images.length,
                      itemBuilder: (context, i) => Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(court.images[i], width: 300, fit: BoxFit.cover),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: const [
                      Icon(Icons.location_on, size: 20),
                      SizedBox(width: 6),
                      Text('Địa chỉ:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    court.address?.isNotEmpty == true ? court.address! : 'Chưa cập nhật địa chỉ',
                    style: TextStyle(
                      fontSize: 16,
                      height: 1.5,
                      color: court.address?.isNotEmpty == true ? Colors.black87 : Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 30),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context); // Đóng modal
                      Navigator.push(context, MaterialPageRoute(builder: (context) => SubCourtSelectionScreen(court: court)));
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryPurple,
                      minimumSize: const Size(double.infinity, 55),
                    ),
                    child: const Text('Đặt lịch', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: primaryPurple,
        foregroundColor: Colors.white,
        title: Text(_currentUser?.fullName ?? 'Đang tải...'),
        elevation: 0,
      ),
      drawer: Drawer(
        child: Column(
          children: [
            UserAccountsDrawerHeader(
              decoration: BoxDecoration(color: primaryPurple),
              currentAccountPicture: const CircleAvatar(backgroundColor: Colors.white, child: Icon(Icons.person, size: 40)),
              accountName: Text(_currentUser?.fullName ?? ''),
              accountEmail: Text(_currentUser?.email ?? ''),
            ),
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text('Lịch sử đặt sân'),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const BookingHistoryScreen())),
            ),
            const Spacer(),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Đăng xuất', style: TextStyle(color: Colors.red)),
              onTap: _handleLogout,
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
      body: Column(
        children: [
          // Thanh tìm kiếm và Lọc
          Container(
            padding: const EdgeInsets.all(16),
            color: primaryPurple,
            child: Column(
              children: [
                TextField(
                  onChanged: (val) => setState(() => _searchQuery = val),
                  decoration: InputDecoration(
                    hintText: 'Tìm tên sân...',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Khoảng giá: $_priceRange',
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                ),
                const SizedBox(height: 4),
                DropdownButtonFormField<String>(
                  value: _priceRange,
                  dropdownColor: Colors.white,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                  // CẬP NHẬT MỐC GIÁ MỚI VÀO ĐÂY
                  items: ["Tất cả", "50k - 70k", "70k - 100k", "100k - 200k", "Trên 200k"]
                      .map((label) => DropdownMenuItem(value: label, child: Text(label)))
                      .toList(),
                  onChanged: (val) => setState(() => _priceRange = val!),
                ),
              ],
            ),
          ),
          
          Expanded(
            child: StreamBuilder<List<CourtModel>>(
              stream: _dbService.getActiveCourtsStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                if (!snapshot.hasData || snapshot.data!.isEmpty) return const Center(child: Text('Không có sân nào.'));

                final filteredList = _filterCourts(snapshot.data!);

                if (filteredList.isEmpty) {
                  return const Center(child: Text('Không tìm thấy sân nào phù hợp.', style: TextStyle(color: Colors.grey, fontSize: 16)));
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredList.length,
                  itemBuilder: (context, index) {
                    final court = filteredList[index];
                    return Card(
                      elevation: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      child: InkWell(
                        onTap: () => _showCourtDetailsModal(court),
                        borderRadius: BorderRadius.circular(15),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                              child: court.images.isNotEmpty 
                                ? Image.network(court.images.first, height: 180, width: double.infinity, fit: BoxFit.cover)
                                : Container(height: 180, color: Colors.grey[200], child: const Icon(Icons.image, size: 50, color: Colors.grey)),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      court.name,
                                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Text(
                                    '${(court.pricePerHour / 1000).toStringAsFixed(0)}k/h',
                                    style: TextStyle(fontSize: 20, color: primaryPurple, fontWeight: FontWeight.bold)
                                  ),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
                              child: Row(
                                children: [
                                  Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      court.address?.isNotEmpty == true
                                          ? court.address!
                                          : 'Chưa cập nhật địa chỉ',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: court.address?.isNotEmpty == true
                                            ? Colors.black87
                                            : Colors.grey[500],
                                        fontStyle: court.address?.isNotEmpty == true
                                            ? FontStyle.normal
                                            : FontStyle.italic,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}