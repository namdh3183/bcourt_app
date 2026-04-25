import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:developer';
import '../models/court_model.dart';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/booking_model.dart';
import '../models/user_model.dart';
import '../models/report_model.dart';

class DatabaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Lấy danh sách CLB dành cho Khách hàng (Chỉ lấy CLB đang hoạt động 'active')
  Stream<List<CourtModel>> getActiveCourtsStream() {
    try {
      return _firestore
          .collection('courts')
          .where('status', isEqualTo: 'active')
          .snapshots()
          .map((snapshot) {
        return snapshot.docs.map((doc) {
          return CourtModel.fromMap(doc.data(), doc.id);
        }).toList();
      });
    } catch (e) {
      log("Lỗi khi lấy danh sách sân: $e");
      return Stream.value([]); 
    }
  }

  // Hàm thêm sân (CLB) mới cho Chủ sân
  Future<bool> addCourt(CourtModel court) async {
    try {
      DocumentReference docRef = _firestore.collection('courts').doc();

      CourtModel newCourt = CourtModel(
        id: docRef.id,
        name: court.name,
        ownerId: court.ownerId,
        address: court.address,
        pricePerHour: court.pricePerHour,
        images: court.images,
        status: court.status,
        subCourts: court.subCourts,
        bankName: court.bankName,
        bankAccountNumber: court.bankAccountNumber,
        bankAccountName: court.bankAccountName,
      );

      await docRef.set(newCourt.toMap());
      return true;
    } catch (e) {
      log("Lỗi khi thêm sân: $e");
      return false;
    }
  }

  // Hàm tải 1 file ảnh lên Firebase Storage
  Future<String?> uploadCourtImage(File imageFile, String courtId) async {
    try {
      String fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      Reference ref = _storage.ref().child('courts').child(courtId).child(fileName);

      UploadTask uploadTask = ref.putFile(imageFile);
      TaskSnapshot snapshot = await uploadTask;

      String downloadUrl = await snapshot.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      log("Lỗi khi upload ảnh: $e");
      return null;
    }
  }

  // Hàm upload ảnh bill đặt cọc lên Firebase Storage
  Future<String?> uploadDepositProof(File imageFile, String customerId) async {
    try {
      String fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      Reference ref = _storage
          .ref()
          .child('deposit_proofs')
          .child(customerId)
          .child(fileName);

      UploadTask uploadTask = ref.putFile(imageFile);
      TaskSnapshot snapshot = await uploadTask;

      String downloadUrl = await snapshot.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      log("Lỗi khi upload ảnh bill đặt cọc: $e");
      return null;
    }
  }

  // Hàm thêm CLB hỗ trợ upload nhiều ảnh
  Future<bool> addCourtWithImages(CourtModel court, List<File> imageFiles) async {
    try {
      DocumentReference docRef = _firestore.collection('courts').doc();
      String generatedCourtId = docRef.id;

      List<String> uploadedImageUrls = [];

      if (imageFiles.isNotEmpty) {
        for (File file in imageFiles) {
          String? url = await uploadCourtImage(file, generatedCourtId);
          if (url != null) {
            uploadedImageUrls.add(url);
          }
        }
      }

      CourtModel finalCourt = CourtModel(
        id: generatedCourtId,
        name: court.name,
        ownerId: court.ownerId,
        address: court.address,
        pricePerHour: court.pricePerHour,
        images: uploadedImageUrls,
        status: court.status,
        subCourts: court.subCourts,
        bankName: court.bankName,
        bankAccountNumber: court.bankAccountNumber,
        bankAccountName: court.bankAccountName,
      );

      await docRef.set(finalCourt.toMap());
      return true;
    } catch (e) {
      log("Lỗi khi thêm sân (kèm ảnh): $e");
      return false;
    }
  }

  // Lấy danh sách CLB do một Chủ sân cụ thể quản lý
  Stream<List<CourtModel>> getOwnerCourtsStream(String ownerId) {
    try {
      return _firestore
          .collection('courts')
          .where('ownerId', isEqualTo: ownerId)
          .snapshots()
          .map((snapshot) {
        return snapshot.docs.map((doc) {
          // ignore: unnecessary_cast
          return CourtModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
        }).toList();
      });
    } catch (e) {
      log("Lỗi khi lấy danh sách sân của chủ sân: $e");
      return Stream.value([]); 
    }
  }

  // Hàm cập nhật thông tin sân (Sửa)
  Future<bool> updateCourt(CourtModel court) async {
    try {
      await _firestore.collection('courts').doc(court.id).update(court.toMap());
      return true;
    } catch (e) {
      log("Lỗi khi cập nhật sân: $e");
      return false;
    }
  }

  // Hàm xóa sân
  Future<bool> deleteCourt(String courtId) async {
    try {
      await _firestore.collection('courts').doc(courtId).delete();
      return true;
    } catch (e) {
      log("Lỗi khi xóa sân: $e");
      return false;
    }
  }

  // 1. Hàm lấy danh sách các ca ĐÃ ĐƯỢC ĐẶT của một SÂN CON trong một NGÀY CỤ THỂ
  Stream<List<BookingModel>> getBookingsForSubCourtByDate(String courtId, String subCourtName, DateTime selectedDate) {
    try {
      DateTime startOfDay = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
      DateTime endOfDay = startOfDay.add(const Duration(days: 1));

      return _firestore
          .collection('bookings')
          .where('courtId', isEqualTo: courtId)
          .where('subCourtName', isEqualTo: subCourtName) 
          .where('startTime', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('startTime', isLessThan: Timestamp.fromDate(endOfDay))
          .snapshots()
          .map((snapshot) {
            return snapshot.docs
                .map((doc) => BookingModel.fromMap(doc.data(), doc.id))
                .where((booking) => booking.bookingStatus != 'cancelled')
                .toList();
      });
    } catch (e) {
      log("Lỗi khi lấy danh sách lịch đặt: $e");
      return Stream.value([]);
    }
  }

  // 2. Hàm tạo Đơn đặt sân mới (Transaction chống trùng lịch) — trả về bookingId khi thành công
  Future<String> createBooking(BookingModel booking) async {
    try {
      DocumentReference courtRef = _firestore.collection('courts').doc(booking.courtId);
      DocumentReference newBookingRef = _firestore.collection('bookings').doc();

      await _firestore.runTransaction((transaction) async {
        DocumentSnapshot courtSnap = await transaction.get(courtRef);
        if (!courtSnap.exists) {
          throw Exception("court_not_found");
        }

        DateTime bookingDate = booking.startTime.toDate();
        DateTime startOfDay = DateTime(bookingDate.year, bookingDate.month, bookingDate.day);
        DateTime endOfDay = startOfDay.add(const Duration(days: 1));

        QuerySnapshot dailyBookings = await _firestore
            .collection('bookings')
            .where('courtId', isEqualTo: booking.courtId)
            .where('subCourtName', isEqualTo: booking.subCourtName)
            .where('startTime', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
            .where('startTime', isLessThan: Timestamp.fromDate(endOfDay))
            .get();

        double newStart = booking.startTime.toDate().hour + (booking.startTime.toDate().minute / 60.0);
        double newEnd = booking.endTime.toDate().hour + (booking.endTime.toDate().minute / 60.0);

        for (var doc in dailyBookings.docs) {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          if (data['bookingStatus'] == 'cancelled') continue;
          Timestamp existingStartTs = data['startTime'];
          Timestamp existingEndTs = data['endTime'];
          double existingStart = existingStartTs.toDate().hour + (existingStartTs.toDate().minute / 60.0);
          double existingEnd = existingEndTs.toDate().hour + (existingEndTs.toDate().minute / 60.0);
          if (newStart < existingEnd && newEnd > existingStart) {
            throw Exception("overlap_booking");
          }
        }

        BookingModel newBooking = BookingModel(
          id: newBookingRef.id,
          customerId: booking.customerId,
          courtId: booking.courtId,
          subCourtName: booking.subCourtName,
          bookingDate: booking.bookingDate,
          startTime: booking.startTime,
          endTime: booking.endTime,
          totalPrice: booking.totalPrice,
          paymentStatus: booking.paymentStatus,
          bookingStatus: booking.bookingStatus,
          createdAt: booking.createdAt,
          depositProofImageUrl: booking.depositProofImageUrl,
        );

        transaction.set(newBookingRef, newBooking.toMap());
        transaction.update(courtRef, {'lastBookingUpdatedAt': FieldValue.serverTimestamp()});
      });

      return newBookingRef.id; // Trả về ID thực tế khi thành công
    } catch (e) {
      log("Lỗi khi tạo lịch đặt: $e");
      if (e.toString().contains("overlap_booking")) return "overlap";
      return "error";
    }
  }

  // Lấy danh sách sân con còn trống trong cùng CLB cho khung giờ cụ thể
  Future<List<String>> getAvailableSubCourts({
    required String courtId,
    required List<String> allSubCourts,
    required String excludeSubCourt,
    required DateTime startTime,
    required DateTime endTime,
  }) async {
    try {
      DateTime startOfDay = DateTime(startTime.year, startTime.month, startTime.day);
      DateTime endOfDay = startOfDay.add(const Duration(days: 1));
      double newStart = startTime.hour + (startTime.minute / 60.0);
      double newEnd = endTime.hour + (endTime.minute / 60.0);

      List<String> available = [];

      for (String subCourt in allSubCourts) {
        if (subCourt == excludeSubCourt) continue;

        QuerySnapshot snapshot = await _firestore
            .collection('bookings')
            .where('courtId', isEqualTo: courtId)
            .where('subCourtName', isEqualTo: subCourt)
            .where('startTime', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
            .where('startTime', isLessThan: Timestamp.fromDate(endOfDay))
            .get();

        bool hasOverlap = false;
        for (var doc in snapshot.docs) {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          if (data['bookingStatus'] == 'cancelled') continue;
          double bStart = (data['startTime'] as Timestamp).toDate().hour +
              ((data['startTime'] as Timestamp).toDate().minute / 60.0);
          double bEnd = (data['endTime'] as Timestamp).toDate().hour +
              ((data['endTime'] as Timestamp).toDate().minute / 60.0);
          if (newStart < bEnd && newEnd > bStart) {
            hasOverlap = true;
            break;
          }
        }

        if (!hasOverlap) available.add(subCourt);
      }

      return available;
    } catch (e) {
      log("Lỗi khi kiểm tra sân con còn trống: $e");
      return [];
    }
  }

  // Cập nhật trạng thái thanh toán và ảnh bill sau khi đặt sân
  Future<bool> updateBookingPayment(String bookingId, String paymentStatus, String depositProofImageUrl) async {
    try {
      await _firestore.collection('bookings').doc(bookingId).update({
        'paymentStatus': paymentStatus,
        'depositProofImageUrl': depositProofImageUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      log("Lỗi cập nhật thanh toán: $e");
      return false;
    }
  }

  // Tự động hủy booking chưa thanh toán quá 5 phút — trả về true nếu đã hủy
  Future<bool> autoCancelExpiredUnpaidBooking(String bookingId) async {
    try {
      DocumentSnapshot doc = await _firestore.collection('bookings').doc(bookingId).get();
      if (!doc.exists) return false;
      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      if (data['paymentStatus'] == 'unpaid' && data['bookingStatus'] == 'pending') {
        Timestamp createdAt = data['createdAt'];
        if (DateTime.now().difference(createdAt.toDate()).inMinutes >= 5) {
          await _firestore.collection('bookings').doc(bookingId).update({
            'bookingStatus': 'cancelled',
            'updatedAt': FieldValue.serverTimestamp(),
          });
          return true;
        }
      }
      return false;
    } catch (e) {
      log("Lỗi auto-cancel booking: $e");
      return false;
    }
  }

  // 3. Hàm lấy danh sách lịch sử đặt sân của 1 Khách hàng
  Stream<List<BookingModel>> getCustomerBookingsStream(String customerId) {
    try {
      return _firestore
          .collection('bookings')
          .where('customerId', isEqualTo: customerId)
          .snapshots()
          .map((snapshot) {
            List<BookingModel> bookings = snapshot.docs
                // ignore: unnecessary_cast
                .map((doc) => BookingModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
                .toList();
            
            bookings.sort((a, b) => b.createdAt.compareTo(a.createdAt));
            return bookings;
          });
    } catch (e) {
      log("Lỗi khi lấy lịch sử đặt sân: $e");
      return Stream.value([]);
    }
  }

  // 4. Hàm Hủy lịch đặt
  Future<bool> cancelBooking(String bookingId) async {
    try {
      await _firestore.collection('bookings').doc(bookingId).update({
        'bookingStatus': 'cancelled',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      log("Lỗi khi hủy lịch: $e");
      return false;
    }
  }

  // Hàm duyệt bill cọc — chỉ confirm booking, giữ nguyên paymentStatus=deposit_paid
  Future<bool> approveBooking(String bookingId) async {
    try {
      await _firestore.collection('bookings').doc(bookingId).update({
        'bookingStatus': 'confirmed',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      log("Lỗi khi duyệt lịch: $e");
      return false;
    }
  }

  // Hàm đánh dấu đã nhận đủ tiền — khách đến sân trả 70% còn lại
  Future<bool> markAsFullyPaid(String bookingId) async {
    try {
      await _firestore.collection('bookings').doc(bookingId).update({
        'paymentStatus': 'fully_paid',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      log("Lỗi khi đánh dấu đã thanh toán đủ: $e");
      return false;
    }
  }

  // Hàm lấy danh sách lịch đặt theo KHOẢNG NGÀY (Từ ngày A đến ngày B)
  Stream<List<BookingModel>> getBookingsForCourtByDateRange(String courtId, DateTime startDate, DateTime endDate) {
    try {
      // Đảm bảo lấy từ 00:00 của ngày bắt đầu đến 23:59 của ngày kết thúc
      DateTime startOfDay = DateTime(startDate.year, startDate.month, startDate.day);
      DateTime endOfDay = DateTime(endDate.year, endDate.month, endDate.day).add(const Duration(days: 1));

      return _firestore
          .collection('bookings')
          .where('courtId', isEqualTo: courtId)
          .where('startTime', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('startTime', isLessThan: Timestamp.fromDate(endOfDay))
          .snapshots()
          .map((snapshot) {
            return snapshot.docs
                .map((doc) => BookingModel.fromMap(doc.data(), doc.id))
                .toList();
      });
    } catch (e) {
      log("Lỗi khi lấy lịch tổng theo khoảng ngày: $e");
      return Stream.value([]);
    }
  }
  
  // 5. Hàm lấy TẤT CẢ lịch đặt của toàn bộ CLB trong 1 ngày (Dành cho Chủ sân)
  Stream<List<BookingModel>> getAllBookingsForCourtByDate(String courtId, DateTime selectedDate) {
    try {
      DateTime startOfDay = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
      DateTime endOfDay = startOfDay.add(const Duration(days: 1));

      return _firestore
          .collection('bookings')
          .where('courtId', isEqualTo: courtId)
          .where('startTime', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('startTime', isLessThan: Timestamp.fromDate(endOfDay))
          .snapshots()
          .map((snapshot) {
            return snapshot.docs
                .map((doc) => BookingModel.fromMap(doc.data(), doc.id))
                // Ở đây ta vẫn lấy cả ca 'cancelled' để chủ sân biết có khách vừa hủy
                .toList();
      });
    } catch (e) {
      log("Lỗi khi lấy lịch tổng của CLB: $e");
      return Stream.value([]);
    }
  }

  // 6. Thống kê Doanh thu và Số lượt đặt theo tháng của 1 CLB
  Future<Map<String, dynamic>> getMonthlyStatistics(String courtId, int year, int month) async {
    try {
      DateTime startOfMonth = DateTime(year, month, 1);
      // Xử lý lấy ngày đầu tiên của tháng tiếp theo để làm mốc chặn cuối (LessThan)
      DateTime endOfMonth = (month < 12) ? DateTime(year, month + 1, 1) : DateTime(year + 1, 1, 1);

      QuerySnapshot snapshot = await _firestore
          .collection('bookings')
          .where('courtId', isEqualTo: courtId)
          .where('startTime', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
          .where('startTime', isLessThan: Timestamp.fromDate(endOfMonth))
          .get();

      double totalRevenue = 0;
      int totalSuccessfulBookings = 0;
      int totalCancelledBookings = 0;

      for (var doc in snapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        
        if (data['bookingStatus'] == 'cancelled') {
          totalCancelledBookings++;
        } else {
          // Tính tổng tiền và số ca thành công (pending hoặc confirmed)
          totalSuccessfulBookings++;
          totalRevenue += (data['totalPrice'] ?? 0.0);
        }
      }

      return {
        'revenue': totalRevenue,
        'successful': totalSuccessfulBookings,
        'cancelled': totalCancelledBookings,
      };
    } catch (e) {
      log("Lỗi tính doanh thu: $e");
      return {'revenue': 0.0, 'successful': 0, 'cancelled': 0};
    }
  }

  // Cập nhật thông tin tài khoản ngân hàng của 1 sân cụ thể
  Future<bool> updateCourtBankInfo(
    String courtId,
    String bankName,
    String bankAccountNumber,
    String bankAccountName,
  ) async {
    try {
      await _firestore.collection('courts').doc(courtId).update({
        'bankName': bankName,
        'bankAccountNumber': bankAccountNumber,
        'bankAccountName': bankAccountName,
      });
      return true;
    } catch (e) {
      log("Lỗi khi cập nhật thông tin ngân hàng sân: $e");
      return false;
    }
  }

  // ================= PHÂN HỆ ADMIN =================

  // 1. Lấy TẤT CẢ người dùng (khách & chủ sân)
  Stream<List<UserModel>> getAllUsersStream() {
    try {
      return _firestore.collection('users').snapshots().map((snapshot) {
        return snapshot.docs.map((doc) => UserModel.fromMap(doc.data(), doc.id)).toList();
      });
    } catch (e) {
      log("Lỗi tải user: $e");
      return Stream.value([]);
    }
  }

  // 2. Khóa / Mở khóa người dùng
  Future<bool> updateUserStatus(String uid, String newStatus) async {
    try {
      await _firestore.collection('users').doc(uid).update({'status': newStatus});
      return true;
    } catch (e) {
      log("Lỗi cập nhật user: $e");
      return false;
    }
  }

  // 3. Lấy TẤT CẢ các sân (bao gồm cả sân đang chờ duyệt)
  Stream<List<CourtModel>> getAllCourtsForAdminStream() {
    try {
      return _firestore.collection('courts').snapshots().map((snapshot) {
        return snapshot.docs.map((doc) => CourtModel.fromMap(doc.data(), doc.id)).toList();
      });
    } catch (e) {
      log("Lỗi tải danh sách sân admin: $e");
      return Stream.value([]);
    }
  }

  // 4. Cập nhật trạng thái sân (Duyệt / Từ chối / Khóa)
  Future<bool> updateCourtStatus(String courtId, String newStatus) async {
    try {
      await _firestore.collection('courts').doc(courtId).update({'status': newStatus});
      return true;
    } catch (e) {
      log("Lỗi cập nhật sân: $e");
      return false;
    }
  }

  // ================= PHÂN HỆ BÁO CÁO VI PHẠM =================

  // Upload ảnh bằng chứng báo cáo lên Firebase Storage
  Future<String?> uploadReportEvidence(File imageFile, String reporterId) async {
    try {
      String fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      Reference ref = _storage
          .ref()
          .child('reports')
          .child(reporterId)
          .child(fileName);

      UploadTask uploadTask = ref.putFile(imageFile);
      TaskSnapshot snapshot = await uploadTask;

      String downloadUrl = await snapshot.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      log("Lỗi khi upload ảnh bằng chứng: $e");
      return null;
    }
  }

  // Kiểm tra người dùng đã báo cáo booking này chưa (query Firestore thật để tránh race condition)
  // LƯU Ý: Firestore cần composite index cho (reporterId, bookingId).
  // Lần đầu chạy, console sẽ hiển thị link tạo index tự động.
  Future<bool> hasReportedBooking(String reporterId, String bookingId) async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('reports')
          .where('reporterId', isEqualTo: reporterId)
          .where('bookingId', isEqualTo: bookingId)
          .limit(1)
          .get();
      return snapshot.docs.isNotEmpty;
    } catch (e) {
      log("Lỗi kiểm tra báo cáo trùng: $e");
      return false; // Fail-open để không chặn nhầm user
    }
  }

  // Tạo báo cáo vi phạm mới (có upload ảnh bằng chứng nếu có)
  Future<String> createReport(ReportModel report, {File? evidenceImage}) async {
    try {
      // Kiểm tra đã báo cáo booking này chưa
      bool isDuplicate = await hasReportedBooking(report.reporterId, report.bookingId);
      if (isDuplicate) return 'duplicate';

      String? evidenceUrl;
      if (evidenceImage != null) {
        evidenceUrl = await uploadReportEvidence(evidenceImage, report.reporterId);
        if (evidenceUrl == null) return 'error';
      }

      // Tạo report với URL ảnh bằng chứng (nếu có)
      DocumentReference docRef = _firestore.collection('reports').doc();
      ReportModel finalReport = ReportModel(
        id: docRef.id,
        reporterId: report.reporterId,
        reporterRole: report.reporterRole,
        reportedUserId: report.reportedUserId,
        reportedUserRole: report.reportedUserRole,
        bookingId: report.bookingId,
        reason: report.reason,
        description: report.description,
        evidenceImageUrl: evidenceUrl,
        status: 'pending',
        createdAt: report.createdAt,
      );

      await docRef.set(finalReport.toMap());
      return 'success';
    } catch (e) {
      log("Lỗi khi tạo báo cáo: $e");
      return 'error';
    }
  }

  // Tự động gỡ ban khi hết thời hạn (gọi sau khi login)
  Future<void> checkAndUnbanIfExpired(String uid) async {
    try {
      DocumentSnapshot doc = await _firestore.collection('users').doc(uid).get();
      if (!doc.exists) return;

      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      String status = data['status'] ?? 'active';
      Timestamp? bannedUntil = data['bannedUntil'] as Timestamp?;

      if (status == 'banned_temporary' &&
          bannedUntil != null &&
          bannedUntil.toDate().isBefore(DateTime.now())) {
        await _firestore.collection('users').doc(uid).update({
          'status': 'active',
          'bannedUntil': FieldValue.delete(),
        });
        log("Đã tự động gỡ ban cho user $uid (hết hạn)");
      }
    } catch (e) {
      log("Lỗi khi kiểm tra hết hạn ban: $e");
    }
  }

  // Lấy user theo uid
  Future<UserModel?> getUserById(String uid) async {
    try {
      DocumentSnapshot doc = await _firestore.collection('users').doc(uid).get();
      if (!doc.exists) return null;
      return UserModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
    } catch (e) {
      log("Lỗi khi lấy thông tin user: $e");
      return null;
    }
  }

  // Lấy booking theo id
  Future<BookingModel?> getBookingById(String bookingId) async {
    try {
      DocumentSnapshot doc = await _firestore.collection('bookings').doc(bookingId).get();
      if (!doc.exists) return null;
      return BookingModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
    } catch (e) {
      log("Lỗi khi lấy thông tin booking: $e");
      return null;
    }
  }

  // Lấy sân theo id
  Future<CourtModel?> getCourtById(String courtId) async {
    try {
      DocumentSnapshot doc = await _firestore.collection('courts').doc(courtId).get();
      if (!doc.exists) return null;
      return CourtModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
    } catch (e) {
      log("Lỗi khi lấy thông tin sân: $e");
      return null;
    }
  }

  // Thống kê tổng quan cho dashboard admin
  Future<Map<String, int>> getDashboardStats() async {
    try {
      DateTime now = DateTime.now();
      DateTime startOfMonth = DateTime(now.year, now.month, 1);
      DateTime endOfMonth = now.month < 12
          ? DateTime(now.year, now.month + 1, 1)
          : DateTime(now.year + 1, 1, 1);

      List<QuerySnapshot> results = await Future.wait([
        _firestore.collection('users').get(),
        _firestore.collection('courts').where('status', isEqualTo: 'active').get(),
        _firestore.collection('courts').where('status', isEqualTo: 'pending').get(),
        _firestore.collection('reports').where('status', isEqualTo: 'pending').get(),
        _firestore
            .collection('bookings')
            .where('startTime', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
            .where('startTime', isLessThan: Timestamp.fromDate(endOfMonth))
            .get(),
      ]);

      int totalUsers = 0;
      int bannedUsers = 0;
      for (var doc in results[0].docs) {
        final data = doc.data() as Map<String, dynamic>;
        if (data['role'] == 'admin') continue;
        totalUsers++;
        final status = data['status'] ?? 'active';
        if (status == 'banned' || status == 'banned_permanent' || status == 'banned_temporary') {
          bannedUsers++;
        }
      }

      return {
        'totalUsers': totalUsers,
        'activeCourts': results[1].docs.length,
        'pendingCourts': results[2].docs.length,
        'pendingReports': results[3].docs.length,
        'bannedUsers': bannedUsers,
        'monthlyBookings': results[4].docs.length,
      };
    } catch (e) {
      log("Lỗi khi tải thống kê dashboard: $e");
      return {
        'totalUsers': 0,
        'activeCourts': 0,
        'pendingCourts': 0,
        'pendingReports': 0,
        'bannedUsers': 0,
        'monthlyBookings': 0,
      };
    }
  }

  // Lấy tất cả báo cáo (dành cho admin)
  Stream<List<ReportModel>> getAllReportsStream() {
    try {
      return _firestore
          .collection('reports')
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((snapshot) {
        return snapshot.docs
            .map((doc) => ReportModel.fromMap(doc.data(), doc.id))
            .toList();
      });
    } catch (e) {
      log("Lỗi khi tải danh sách báo cáo: $e");
      return Stream.value([]);
    }
  }

  // Xử lý báo cáo vi phạm
  Future<bool> resolveReport({
    required String reportId,
    required String newReportStatus,
    required String reportedUserId,
    String? adminNote,
    String? banReason,
    int banDays = 0,
    String adminId = '',
  }) async {
    try {
      await _firestore.runTransaction((transaction) async {
        DocumentReference reportRef = _firestore.collection('reports').doc(reportId);
        DocumentReference userRef = _firestore.collection('users').doc(reportedUserId);

        // Đọc trước khi ghi (yêu cầu của Firestore transaction)
        DocumentSnapshot userSnap = await transaction.get(userRef);

        // Cập nhật trạng thái báo cáo
        Map<String, dynamic> reportUpdate = {
          'status': newReportStatus,
          'resolvedAt': FieldValue.serverTimestamp(),
          'resolvedBy': adminId,
        };
        if (adminNote != null && adminNote.isNotEmpty) {
          reportUpdate['adminNote'] = adminNote;
        }
        transaction.update(reportRef, reportUpdate);

        // Cập nhật user tùy theo loại xử lý
        if (newReportStatus == 'rejected' || !userSnap.exists) return;

        final userData = userSnap.data() as Map<String, dynamic>;

        if (newReportStatus == 'resolved_warning') {
          int current = (userData['warningCount'] as int?) ?? 0;
          transaction.update(userRef, {'warningCount': current + 1});
        } else if (newReportStatus == 'resolved_banned_temp') {
          int current = (userData['reportCount'] as int?) ?? 0;
          DateTime until = DateTime.now().add(Duration(days: banDays));
          Map<String, dynamic> userUpdate = {
            'status': 'banned_temporary',
            'bannedUntil': Timestamp.fromDate(until),
            'reportCount': current + 1,
          };
          if (banReason != null && banReason.isNotEmpty) userUpdate['banReason'] = banReason;
          transaction.update(userRef, userUpdate);
        } else if (newReportStatus == 'resolved_banned_permanent') {
          int current = (userData['reportCount'] as int?) ?? 0;
          Map<String, dynamic> userUpdate = {
            'status': 'banned_permanent',
            'reportCount': current + 1,
          };
          if (banReason != null && banReason.isNotEmpty) userUpdate['banReason'] = banReason;
          transaction.update(userRef, userUpdate);
        }
      });
      return true;
    } catch (e) {
      log("Lỗi khi xử lý báo cáo: $e");
      return false;
    }
  }

  // Lấy thông tin chủ sân từ courtId (dùng cho màn báo cáo phía khách)
  Future<UserModel?> getOwnerOfCourt(String courtId) async {
    try {
      DocumentSnapshot courtDoc = await _firestore.collection('courts').doc(courtId).get();
      if (!courtDoc.exists) return null;

      Map<String, dynamic> courtData = courtDoc.data() as Map<String, dynamic>;
      String ownerId = courtData['ownerId'] ?? '';
      if (ownerId.isEmpty) return null;

      DocumentSnapshot userDoc = await _firestore.collection('users').doc(ownerId).get();
      if (!userDoc.exists) return null;

      return UserModel.fromMap(userDoc.data() as Map<String, dynamic>, userDoc.id);
    } catch (e) {
      log("Lỗi khi lấy thông tin chủ sân: $e");
      return null;
    }
  }

}