import 'package:equatable/equatable.dart';
import '../../../../core/utils/honorific_helper.dart';

class HouseOccupantModel extends Equatable {
  final int id;
  final String? salutation;
  final String name;
  final String phone;
  final String email;
  final String role;
  final String ownershipStatus;
  final DateTime createdAt;

  const HouseOccupantModel({
    required this.id,
    this.salutation = HonorificHelper.bapak,
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
      salutation: HonorificHelper.normalize(json['salutation'] as String?),
      name: json['name'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      email: json['email'] as String? ?? '',
      role: (json['role'] as String? ?? 'RESIDENT').toUpperCase(),
      ownershipStatus: json['ownership_status'] as String? ?? 'pemilik',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  String get displayName {
    return HonorificHelper.formatDisplayName(salutation, name);
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
  List<Object?> get props =>
      [id, salutation, name, phone, email, role, ownershipStatus, createdAt];
}

class UnassignedResidentModel extends Equatable {
  final int id;
  final String? salutation;
  final String name;
  final String phone;
  final String email;
  final String role;
  final String status;
  final DateTime createdAt;

  const UnassignedResidentModel({
    required this.id,
    this.salutation = HonorificHelper.bapak,
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
      salutation: HonorificHelper.normalize(json['salutation'] as String?),
      name: json['name'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      email: json['email'] as String? ?? '',
      role: (json['role'] as String? ?? 'RESIDENT').toUpperCase(),
      status: json['status'] as String? ?? 'active',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  String get displayName {
    return HonorificHelper.formatDisplayName(salutation, name);
  }

  @override
  List<Object?> get props =>
      [id, salutation, name, phone, email, role, status, createdAt];
}
