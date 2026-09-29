import 'package:equatable/equatable.dart';
import 'house_model.dart';

class ResidentUserModel extends Equatable {
  final int id;
  final String name;
  final String phone;
  final String email;
  final String role;
  final String status;
  final String ownershipStatus;
  final int? houseId;
  final HouseModel? house;
  final DateTime createdAt;

  const ResidentUserModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.email,
    required this.role,
    required this.status,
    required this.ownershipStatus,
    this.houseId,
    this.house,
    required this.createdAt,
  });

  factory ResidentUserModel.fromJson(Map<String, dynamic> json) {
    return ResidentUserModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      email: json['email'] as String? ?? '',
      role: json['role'] as String? ?? 'warga',
      status: json['status'] as String? ?? 'active',
      ownershipStatus: json['ownership_status'] as String? ?? 'pemilik',
      houseId: (json['house_id'] as num?)?.toInt(),
      house: json['house'] != null ? HouseModel.fromJson(json['house'] as Map<String, dynamic>) : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  String get houseDisplay {
    if (house != null) {
      return house!.label;
    }
    return 'Belum Ada Rumah';
  }

  String get statusDisplay {
    switch (status.toLowerCase()) {
      case 'active':
        return 'Aktif';
      case 'pending_verification':
        return 'Menunggu';
      case 'rejected':
        return 'Ditolak';
      case 'inactive':
        return 'Non-Aktif';
      default:
        return status;
    }
  }

  @override
  List<Object?> get props => [
        id,
        name,
        phone,
        email,
        role,
        status,
        ownershipStatus,
        houseId,
        house,
        createdAt,
      ];
}
