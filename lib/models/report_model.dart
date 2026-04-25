import 'package:cloud_firestore/cloud_firestore.dart';

class ReportModel {
  final String id;
  final String reporterId;         // người báo cáo
  final String reporterRole;       // 'customer' | 'owner'
  final String reportedUserId;     // người bị báo cáo
  final String reportedUserRole;   // 'customer' | 'owner'
  final String bookingId;          // booking liên quan
  final String reason;             // key lý do từ ReportReasons
  final String description;        // mô tả chi tiết
  final String? evidenceImageUrl;  // ảnh bằng chứng (optional)
  final String status;             // 'pending' | 'resolved_warning' |
                                   // 'resolved_banned_temp' |
                                   // 'resolved_banned_permanent' | 'rejected'
  final String? adminNote;         // ghi chú của admin khi xử lý
  final Timestamp createdAt;
  final Timestamp? resolvedAt;
  final String? resolvedBy;        // adminId

  ReportModel({
    required this.id,
    required this.reporterId,
    required this.reporterRole,
    required this.reportedUserId,
    required this.reportedUserRole,
    required this.bookingId,
    required this.reason,
    required this.description,
    this.evidenceImageUrl,
    this.status = 'pending',
    this.adminNote,
    required this.createdAt,
    this.resolvedAt,
    this.resolvedBy,
  });

  factory ReportModel.fromMap(Map<String, dynamic> map, String documentId) {
    return ReportModel(
      id: documentId,
      reporterId: map['reporterId'] ?? '',
      reporterRole: map['reporterRole'] ?? '',
      reportedUserId: map['reportedUserId'] ?? '',
      reportedUserRole: map['reportedUserRole'] ?? '',
      bookingId: map['bookingId'] ?? '',
      reason: map['reason'] ?? '',
      description: map['description'] ?? '',
      evidenceImageUrl: map['evidenceImageUrl'],
      status: map['status'] ?? 'pending',
      adminNote: map['adminNote'],
      createdAt: map['createdAt'] ?? Timestamp.now(),
      resolvedAt: map['resolvedAt'],
      resolvedBy: map['resolvedBy'],
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'reporterId': reporterId,
      'reporterRole': reporterRole,
      'reportedUserId': reportedUserId,
      'reportedUserRole': reportedUserRole,
      'bookingId': bookingId,
      'reason': reason,
      'description': description,
      'status': status,
      'createdAt': createdAt,
    };
    if (evidenceImageUrl != null) map['evidenceImageUrl'] = evidenceImageUrl!;
    if (adminNote != null) map['adminNote'] = adminNote!;
    if (resolvedAt != null) map['resolvedAt'] = resolvedAt!;
    if (resolvedBy != null) map['resolvedBy'] = resolvedBy!;
    return map;
  }
}
