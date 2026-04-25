import 'package:cloud_firestore/cloud_firestore.dart';

class BookingModel {
  final String id;
  final String customerId;
  final String courtId;
  final Timestamp bookingDate;
  final Timestamp startTime;
  final Timestamp endTime;
  final double totalPrice;
  final String paymentStatus; // 'unpaid', 'deposit_paid', 'fully_paid'
  final String bookingStatus; // 'pending', 'confirmed', 'cancelled'
  final Timestamp createdAt;
  final String subCourtName;
  final String? depositProofImageUrl; // ẢNH BILL ĐẶT CỌC - MỚI

  BookingModel({
    required this.id,
    required this.customerId,
    required this.courtId,
    required this.bookingDate,
    required this.startTime,
    required this.endTime,
    required this.totalPrice,
    required this.paymentStatus,
    required this.bookingStatus,
    required this.createdAt,
    required this.subCourtName,
    this.depositProofImageUrl, // Optional
  });

  factory BookingModel.fromMap(Map<String, dynamic> map, String documentId) {
    return BookingModel(
      id: documentId,
      customerId: map['customerId'] ?? '',
      courtId: map['courtId'] ?? '',
      bookingDate: map['bookingDate'] ?? Timestamp.now(),
      startTime: map['startTime'] ?? Timestamp.now(),
      endTime: map['endTime'] ?? Timestamp.now(),
      totalPrice: (map['totalPrice'] ?? 0.0).toDouble(),
      paymentStatus: map['paymentStatus'] ?? 'unpaid',
      bookingStatus: map['bookingStatus'] ?? 'pending',
      createdAt: map['createdAt'] ?? Timestamp.now(),
      subCourtName: map['subCourtName'] ?? '',
      depositProofImageUrl: map['depositProofImageUrl'], // Nullable
    );
  }

  Map<String, dynamic> toMap() {
    final map = {
      'customerId': customerId,
      'courtId': courtId,
      'bookingDate': bookingDate,
      'startTime': startTime,
      'endTime': endTime,
      'totalPrice': totalPrice,
      'paymentStatus': paymentStatus,
      'bookingStatus': bookingStatus,
      'createdAt': createdAt,
      'subCourtName': subCourtName,
    };
    // Chỉ thêm vào nếu có giá trị (tránh lưu null lên Firestore)
    if (depositProofImageUrl != null) {
      map['depositProofImageUrl'] = depositProofImageUrl!;
    }
    return map;
  }
}