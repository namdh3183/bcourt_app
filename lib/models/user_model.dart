import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String fullName;
  final String email;
  final String phone;
  final String role;          // 'customer' | 'owner' | 'admin'
  final Timestamp createdAt;
  final String status;        // 'active' | 'banned_temporary' |
                              // 'banned_permanent' | 'banned' (legacy)
  final Timestamp? bannedUntil;  // ngày hết hạn ban tạm thời
  final int reportCount;         // tổng số báo cáo được admin duyệt
  final int warningCount;        // tổng số lần bị cảnh báo
  final String? banReason;       // lý do ban (hiển thị cho người dùng)

  // Field transient — không lưu Firestore, chỉ tính toán runtime
  final bool isBanned;

  UserModel({
    required this.uid,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.role,
    required this.createdAt,
    this.status = 'active',
    this.bannedUntil,
    this.reportCount = 0,
    this.warningCount = 0,
    this.banReason,
    this.isBanned = false,
  });

  factory UserModel.fromMap(Map<String, dynamic> map, String documentId) {
    return UserModel(
      uid: documentId,
      fullName: map['fullName'] ?? '',
      email: map['email'] ?? '',
      phone: map['phone'] ?? '',
      role: map['role'] ?? 'customer',
      createdAt: map['createdAt'] ?? Timestamp.now(),
      status: map['status'] ?? 'active',
      bannedUntil: map['bannedUntil'] as Timestamp?,
      reportCount: (map['reportCount'] as int?) ?? 0,
      warningCount: (map['warningCount'] as int?) ?? 0,
      banReason: map['banReason'] as String?,
      // isBanned KHÔNG đọc từ map — được set bởi AuthService
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'fullName': fullName,
      'email': email,
      'phone': phone,
      'role': role,
      'createdAt': createdAt,
      'status': status,
      'reportCount': reportCount,
      'warningCount': warningCount,
    };
    // Chỉ lưu bannedUntil khi có giá trị (ban tạm thời)
    if (bannedUntil != null) map['bannedUntil'] = bannedUntil!;
    // Chỉ lưu banReason khi có giá trị
    if (banReason != null) map['banReason'] = banReason!;
    // isBanned là transient, KHÔNG lưu lên Firestore
    return map;
  }
}
