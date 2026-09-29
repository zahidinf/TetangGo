import 'package:equatable/equatable.dart';

class HouseOccupantModel extends Equatable {
  final int id;
  final String name;
  final String phone;
  final String email;
  final String role;
  final String ownershipStatus;
  final DateTime createdAt;

  const HouseOccupantModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.email,
    required this.role,
    required this.ownershipStatus,
    required this.createdAt,
  });

  factory HouseOccupantModel.fromJson(Map<String, dynamic> json) {
    return HouseOccupantModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      email: json['email'] as String? ?? '',
      role: json['role'] as String? ?? 'warga',
      ownershipStatus: json['ownership_status'] as String? ?? 'pemilik',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  String get ownershipDisplay {
    switch (ownershipStatus.toLowerCase()) {
      case 'pengontrak':
        return 'Penyewa / Kontrak';
      case 'anggota_keluarga':
        return 'Anggota Keluarga';
      case 'pemilik':
      default:
        return 'Pemilik Rumah';
    }
  }

  @override
  List<Object?> get props => [id, name, phone, email, role, ownershipStatus, createdAt];
}

class UnassignedResidentModel extends Equatable {
  final int id;
  final String name;
  final String phone;
  final String email;
  final String role;
  final String status;
  final DateTime createdAt;

  const UnassignedResidentModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.email,
    required this.role,
    required this.status,
    required this.createdAt,
  });

  factory UnassignedResidentModel.fromJson(Map<String, dynamic> json) {
    return UnassignedResidentModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      email: json['email'] as String? ?? '',
      role: json['role'] as String? ?? 'warga',
      status: json['status'] as String? ?? 'active',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  @override
  List<Object?> get props => [id, name, phone, email, role, status, createdAt];
}
