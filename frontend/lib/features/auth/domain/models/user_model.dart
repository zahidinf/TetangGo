import 'package:equatable/equatable.dart';

class UserModel extends Equatable {
  final int id;
  final String name;
  final String phone;
  final String email;
  final int roleId;
  final String role;
  final int? houseId;
  final String status;
  final String ownershipStatus;
  final String? rejectionReason;
  final String? profilePhotoUrl;
  final String? houseBlock;
  final String? houseNumber;

  const UserModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.email,
    required this.roleId,
    required this.role,
    this.houseId,
    required this.status,
    this.ownershipStatus = 'pemilik',
    this.rejectionReason,
    this.profilePhotoUrl,
    this.houseBlock,
    this.houseNumber,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    String? block;
    String? number;
    if (json['house'] is Map) {
      final h = json['house'] as Map<String, dynamic>;
      block = h['block'] as String?;
      number = h['house_number'] as String?;
    }

    return UserModel(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      email: json['email'] as String? ?? '',
      roleId: json['role_id'] as int? ?? 0,
      role: json['role'] as String? ?? 'warga',
      houseId: json['house_id'] as int?,
      status: json['status'] as String? ?? 'active',
      ownershipStatus: json['ownership_status'] as String? ?? 'pemilik',
      rejectionReason: json['rejection_reason'] as String?,
      profilePhotoUrl: json['profile_photo_url'] as String?,
      houseBlock: block ?? json['house_block'] as String?,
      houseNumber: number ?? json['house_number'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'email': email,
      'role_id': roleId,
      'role': role,
      'house_id': houseId,
      'status': status,
      'ownership_status': ownershipStatus,
      'rejection_reason': rejectionReason,
      'profile_photo_url': profilePhotoUrl,
      'house_block': houseBlock,
      'house_number': houseNumber,
    };
  }

  String get roleDisplay {
    switch (role) {
      case 'admin_rt':
        return 'Pengurus RT';
      case 'satpam':
        return 'Petugas Satpam';
      case 'warga':
      default:
        return 'Warga Cluster';
    }
  }

  bool get isPending => status == 'pending_verification';
  bool get isActive => status == 'active';
  bool get isAdmin => role == 'admin_rt';

  String get houseDisplay {
    if (houseBlock != null && houseNumber != null) {
      return 'Blok $houseBlock No. $houseNumber';
    }
    return 'Hunian Belum Terdaftar';
  }

  @override
  List<Object?> get props => [
        id,
        name,
        phone,
        email,
        roleId,
        role,
        houseId,
        status,
        ownershipStatus,
        rejectionReason,
        profilePhotoUrl,
        houseBlock,
        houseNumber,
      ];
}
