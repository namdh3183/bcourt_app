import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationModel {
  final String id;
  final String recipientId;
  final String title;
  final String body;
  // Loại thông báo: 'booking_confirmed', 'booking_cancelled_by_owner',
  // 'booking_cancelled_by_customer', 'deposit_uploaded', 'new_booking',
  // 'fully_paid', 'admin_warning', 'admin_ban', 'court_approved'
  final String type;
  final String? relatedId;
  final Timestamp createdAt;

  const NotificationModel({
    required this.id,
    required this.recipientId,
    required this.title,
    required this.body,
    required this.type,
    this.relatedId,
    required this.createdAt,
  });

  factory NotificationModel.fromMap(Map<String, dynamic> map, String docId) {
    return NotificationModel(
      id: docId,
      recipientId: map['recipientId'] ?? '',
      title: map['title'] ?? '',
      body: map['body'] ?? '',
      type: map['type'] ?? '',
      relatedId: map['relatedId'] as String?,
      createdAt: map['createdAt'] as Timestamp? ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'recipientId': recipientId,
      'title': title,
      'body': body,
      'type': type,
      'createdAt': createdAt,
    };
    if (relatedId != null) map['relatedId'] = relatedId;
    return map;
  }
}
