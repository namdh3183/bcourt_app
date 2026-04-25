class CourtModel {
  final String id;
  final String name;
  final String ownerId;
  final String? address;
  final double pricePerHour;
  final List<String> images;
  final String status;
  final List<String> subCourts;
  final String? bankName;
  final String? bankAccountNumber;
  final String? bankAccountName;

  CourtModel({
    required this.id,
    required this.name,
    required this.ownerId,
    required this.pricePerHour,
    required this.images,
    required this.status,
    required this.subCourts,
    this.address,
    this.bankName,
    this.bankAccountNumber,
    this.bankAccountName,
  });

  factory CourtModel.fromMap(Map<String, dynamic> map, String documentId) {
    return CourtModel(
      id: documentId,
      name: map['name'] ?? '',
      ownerId: map['ownerId'] ?? '',
      pricePerHour: (map['pricePerHour'] ?? 0.0).toDouble(),
      images: List<String>.from(map['images'] ?? []),
      status: map['status'] ?? 'active',
      subCourts: List<String>.from(map['subCourts'] ?? ['Sân 1']),
      address: map['address'] as String?,
      bankName: map['bankName'] as String?,
      bankAccountNumber: map['bankAccountNumber'] as String?,
      bankAccountName: map['bankAccountName'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'name': name,
      'ownerId': ownerId,
      'pricePerHour': pricePerHour,
      'images': images,
      'status': status,
      'subCourts': subCourts,
    };
    // Chỉ thêm vào nếu có giá trị (tránh lưu null lên Firestore)
    if (address != null) map['address'] = address!;
    if (bankName != null) map['bankName'] = bankName!;
    if (bankAccountNumber != null) map['bankAccountNumber'] = bankAccountNumber!;
    if (bankAccountName != null) map['bankAccountName'] = bankAccountName!;
    return map;
  }
}
