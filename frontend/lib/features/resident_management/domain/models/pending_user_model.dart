import 'package:equatable/equatable.dart';

class PendingUserModel extends Equatable {
  final int id;
  final String name;
  final String phone;
  final String email;
  final String role;
  final int? houseId;
  final String houseBlock;
  final String houseNumber;
  final String ownershipStatus;
  final String status;
  final DateTime createdAt;

  const PendingUserModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.email,
    required this.role,
    this.houseId,
    required this.houseBlock,
    required this.houseNumber,
    required this.ownershipStatus,
    required this.status,
    required this.createdAt,
  });

  factory PendingUserModel.fromJson(Map<String, dynamic> json) {
    return PendingUserModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      email: json['email'] as String? ?? '',
      role: json['role'] as String? ?? 'warga',
      houseId: (json['house_id'] as num?)?.toInt(),
      houseBlock: json['house_block'] as String? ?? '',
      houseNumber: json['house_number'] as String? ?? '',
      ownershipStatus: json['ownership_status'] as String? ?? 'pemilik',
      status: json['status'] as String? ?? 'pending_verification',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  String get houseDisplay => 'Blok $houseBlock No. $houseNumber';

  String get ownershipDisplay =>
      ownershipStatus.toLowerCase() == 'pengontrak' ? 'Penyewa / Pengontrak' : 'Pemilik Rumah';

  @override
  List<Object?> get props => [
        id,
        name,
        phone,
        email,
        role,
        houseId,
        houseBlock,
        houseNumber,
        ownershipStatus,
        status,
        createdAt,
      ];
}
