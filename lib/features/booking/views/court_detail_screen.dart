import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../models/court_model.dart';
import '../../../models/booking_model.dart';
import '../../../models/user_model.dart';
import '../../../services/database_service.dart';
import '../../../services/auth_service.dart';
import 'payment_screen.dart';

class CourtDetailScreen extends StatefulWidget {
  final CourtModel court;
  final String subCourtName;

  const CourtDetailScreen({super.key, required this.court, required this.subCourtName});

  @override
  State<CourtDetailScreen> createState() => _CourtDetailScreenState();
}

class _CourtDetailScreenState extends State<CourtDetailScreen> {
  final DatabaseService _dbService = DatabaseService();
  final AuthService _authService = AuthService();
  
  UserModel? _currentUser;
  DateTime _selectedDate = DateTime.now();
  double? _startPoint;
  double? _endPoint;
  bool _isBooking = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = await _authService.getCurrentUserData();
    if (mounted) setState(() => _currentUser = user);
  }
  
  // Format số thành chuỗi hiển thị
  String _formatTime(double time) {
    int hour = time.floor();
    int minute = time.toString().endsWith('.5') ? 30 : 0;
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }

  // Thuật toán kiểm tra 2 khoảng thời gian có đè lên nhau không
  bool _checkOverlap(double start, double end, List<BookingModel> bookings) {
    for (var booking in bookings) {
      double bStart = booking.startTime.toDate().hour + (booking.startTime.toDate().minute / 60.0);
      double bEnd = booking.endTime.toDate().hour + (booking.endTime.toDate().minute / 60.0);
      
      // Công thức giao nhau: start < bEnd VÀ end > bStart
      if (start < bEnd && end > bStart) {
        return true;
      }
    }
    return false;
  }

  // Kiểm tra xem nút có bị vô hiệu hóa (grey out) không
  bool _isSlotDisabled(double t, List<BookingModel> bookings) {
    // 1. Quá khứ thì luôn khóa
    bool isPast = _selectedDate.day == DateTime.now().day && 
                  _selectedDate.month == DateTime.now().month && 
                  (t < DateTime.now().hour + (DateTime.now().minute / 60.0));
    if (isPast) return true;

    // 2. Logic Khóa động
    if (_startPoint == null || (_startPoint != null && _endPoint != null)) {
      // Đang ở chế độ tìm Điểm bắt đầu -> Khóa nếu khối 30p ngay liền sau nó đã bị đặt
      return _checkOverlap(t, t + 0.5, bookings);
    } else {
      // Đang ở chế độ tìm Điểm kết thúc
      if (t <= _startPoint!) {
        // Bấm ngược về trước (hoặc bấm lại chính nó) -> Coi như chọn lại điểm đầu
        return _checkOverlap(t, t + 0.5, bookings);
      }
      // Bấm về sau -> Kiểm tra xem từ điểm bắt đầu đến điểm T này có vướng lịch ai không
      return _checkOverlap(_startPoint!, t, bookings);
    }
  }

  // Xử lý khi bấm vào dải thời gian
  void _handleSlotTap(double t, List<BookingModel> bookings) {
    setState(() {
      if (_startPoint == null || (_startPoint != null && _endPoint != null)) {
        _startPoint = t;
        _endPoint = null; // Bắt đầu chu kỳ chọn mới
      } else {
        if (t < _startPoint!) {
          _startPoint = t; // Chọn ngược thời gian -> Cập nhật lại điểm đầu
        } else if (t > _startPoint!) {
          // Double check để đảm bảo an toàn không bị lọt lịch
          if (!_checkOverlap(_startPoint!, t, bookings)) {
            _endPoint = t; // Chốt điểm cuối
          }
        }
      }
    });
  }

  // Mở lịch chọn ngày
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _startPoint = null;
        _endPoint = null;
      });
    }
  }

  // Tạo booking ngay lập tức rồi chuyển sang PaymentScreen để upload bill
  Future<void> _handleGoToPayment() async {
    if (_currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đang tải dữ liệu khách hàng...')));
      return;
    }
    if (_startPoint == null || _endPoint == null) return;

    DateTime startTime = DateTime(
      _selectedDate.year, _selectedDate.month, _selectedDate.day,
      _startPoint!.floor(), _startPoint!.toString().endsWith('.5') ? 30 : 0,
    );
    DateTime endTime = DateTime(
      _selectedDate.year, _selectedDate.month, _selectedDate.day,
      _endPoint!.floor(), _endPoint!.toString().endsWith('.5') ? 30 : 0,
    );

    double duration = _endPoint! - _startPoint!;
    double price = (widget.court.pricePerHour / 60) * (duration * 60).round();

    const Color primaryPurple = Color(0xFFBF89F5);
    bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text(
          'Xác nhận đặt sân',
          style: TextStyle(color: primaryPurple, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sân: ${widget.court.name}'),
            Text('Vị trí: ${widget.subCourtName}'),
            Text('Ngày: ${DateFormat("dd/MM/yyyy").format(_selectedDate)}'),
            Text('Giờ: ${_formatTime(_startPoint!)} - ${_formatTime(_endPoint!)}'),
            const Divider(),
            Text(
              'Tổng tiền: ${price.toStringAsFixed(0)} VNĐ',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.timer, color: Colors.orange, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Sau khi xác nhận, bạn có 5 phút để chuyển khoản và upload bill.',
                      style: TextStyle(color: Colors.orange, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: primaryPurple),
            child: const Text('Xác nhận đặt', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    BookingModel pendingBooking = BookingModel(
      id: '',
      customerId: _currentUser!.uid,
      courtId: widget.court.id,
      subCourtName: widget.subCourtName,
      bookingDate: Timestamp.fromDate(_selectedDate),
      startTime: Timestamp.fromDate(startTime),
      endTime: Timestamp.fromDate(endTime),
      totalPrice: price,
      paymentStatus: 'unpaid',
      bookingStatus: 'pending',
      createdAt: Timestamp.now(),
    );

    setState(() => _isBooking = true);
    String result = await _dbService.createBooking(pendingBooking);
    setState(() => _isBooking = false);

    if (!mounted) return;

    if (result == 'overlap') {
      List<String> available = await _dbService.getAvailableSubCourts(
        courtId: widget.court.id,
        allSubCourts: widget.court.subCourts,
        excludeSubCourt: widget.subCourtName,
        startTime: startTime,
        endTime: endTime,
      );

      if (!mounted) return;

      if (available.isEmpty) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Khung giờ đã được đặt'),
            content: const Text(
              'Khung giờ này đã có người đặt trước và '
              'không còn sân nào trống trong câu lạc bộ. '
              'Vui lòng chọn khung giờ khác.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Đã hiểu'),
              ),
            ],
          ),
        );
      } else {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            title: const Text(
              'Sân đã được đặt',
              style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${widget.subCourtName} đã có người đặt trước khung giờ này.'),
                const SizedBox(height: 12),
                const Text('Các sân còn trống:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ...available.map((name) => ListTile(
                  dense: true,
                  leading: const Icon(Icons.sports_tennis, color: Colors.green),
                  title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CourtDetailScreen(
                          court: widget.court,
                          subCourtName: name,
                        ),
                      ),
                    );
                  },
                )),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Đóng', style: TextStyle(color: Colors.grey)),
              ),
            ],
          ),
        );
      }
      return;
    }
    if (result == 'error') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lỗi hệ thống, vui lòng thử lại!'), backgroundColor: Colors.red),
      );
      return;
    }

    // Thông báo chủ sân có khách đặt mới
    await _dbService.sendNotification(
      recipientId: widget.court.ownerId,
      title: 'Có khách đặt sân mới',
      body: '${_currentUser!.fullName} đã đặt ${widget.court.name} - ${widget.subCourtName}. Chờ khách thanh toán cọc.',
      type: 'new_booking',
      relatedId: result,
    );

    // result là bookingId thực tế đã lưu vào Firestore
    BookingModel savedBooking = BookingModel(
      id: result,
      customerId: _currentUser!.uid,
      courtId: widget.court.id,
      subCourtName: widget.subCourtName,
      bookingDate: Timestamp.fromDate(_selectedDate),
      startTime: Timestamp.fromDate(startTime),
      endTime: Timestamp.fromDate(endTime),
      totalPrice: price,
      paymentStatus: 'unpaid',
      bookingStatus: 'pending',
      createdAt: Timestamp.now(),
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PaymentScreen(
          court: widget.court,
          booking: savedBooking,
          customer: _currentUser!,
          bookingId: result,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.court.name} - ${widget.subCourtName}')),
      body: Column(
        children: [
          // Phần hình ảnh
          SizedBox(
            height: 200,
            width: double.infinity,
            child: widget.court.images.isNotEmpty
                ? Image.network(widget.court.images.first, fit: BoxFit.cover)
                : Container(color: Colors.grey[300], child: const Icon(Icons.image, size: 50)),
          ),
          
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(widget.court.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                Text('${widget.court.pricePerHour.toStringAsFixed(0)} VNĐ / giờ', style: const TextStyle(fontSize: 18, color: Colors.green)),
                const Divider(),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Chọn ngày chơi:', style: TextStyle(fontSize: 16,fontWeight: FontWeight.bold)),
                    TextButton.icon(
                      onPressed: () => _selectDate(context),
                      icon: const Icon(Icons.calendar_month),
                      label: Text(DateFormat('dd/MM/yyyy').format(_selectedDate)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                const Text('Chọn thời gian:', style: TextStyle(fontSize: 16,fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),

                // Lưới dải băng thời gian
                StreamBuilder<List<BookingModel>>(
                  stream: _dbService.getBookingsForSubCourtByDate(widget.court.id, widget.subCourtName, _selectedDate),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    List<BookingModel> currentBookings = snapshot.data ?? [];

                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 5, // Chia 5 mốc một dòng
                        childAspectRatio: 2.0,
                        crossAxisSpacing: 0, // Dải băng liền nhau ngang
                        mainAxisSpacing: 0,  // Dải băng liền nhau dọc
                      ),
                      itemCount: 35, // Từ 05:00 đến 22:00 (35 điểm)
                      itemBuilder: (context, index) {
                        double t = 5.0 + (index * 0.5); 
                        
                        bool isDisabled = _isSlotDisabled(t, currentBookings);
                        bool isSelected = false;

                        // Bôi xanh dải thời gian đã chọn
                        if (_startPoint != null && _endPoint != null) {
                          isSelected = t >= _startPoint! && t <= _endPoint!;
                        } else if (_startPoint != null) {
                          isSelected = t == _startPoint;
                        }

                        // Xử lý màu sắc
                        Color bgColor = Colors.white;
                        Color textColor = Colors.black87;

                        if (isDisabled) {
                          bgColor = Colors.grey[200]!;
                          textColor = Colors.grey[400]!;
                        } else if (isSelected) {
                          bgColor = Colors.green;
                          textColor = Colors.white;
                        }

                        return InkWell(
                          onTap: isDisabled ? null : () => _handleSlotTap(t, currentBookings),
                          child: Container(
                            decoration: BoxDecoration(
                              color: bgColor,
                              // Kẻ viền mỏng để phân biệt các mốc, không bo góc
                              border: Border.all(color: Colors.grey[300]!, width: 0.5),
                              borderRadius: BorderRadius.zero,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              _formatTime(t),
                              style: TextStyle(
                                fontSize: 13,
                                color: textColor,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  // Thanh xác nhận đặt sân phía dưới cùng
  Widget _buildBottomBar() {
    double durationInHours = 0;
    double totalPrice = 0;
    
    if (_startPoint != null && _endPoint != null) {
      durationInHours = _endPoint! - _startPoint!;
      totalPrice = (widget.court.pricePerHour / 60) * (durationInHours * 60).round();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white, 
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))]
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _endPoint == null 
                        ? 'Đang chọn: ${_startPoint != null ? _formatTime(_startPoint!) : "..."}' 
                        : 'Thời gian: $durationInHours giờ',
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                  Text(
                    '${totalPrice.toStringAsFixed(0)} VNĐ', 
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green)
                  ),
                ],
              ),
            ),
            _isBooking
                ? const SizedBox(width: 48, height: 48, child: CircularProgressIndicator())
                : ElevatedButton(
                    onPressed: (_startPoint != null && _endPoint != null)
                        ? _handleGoToPayment
                        : null,
                    style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
                    child: const Text('Đặt sân', style: TextStyle(fontSize: 16)),
                  )
          ],
        ),
      ),
    );
  }
}