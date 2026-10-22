import 'package:equatable/equatable.dart';
import '../../../../core/utils/honorific_helper.dart';

class UserModel extends Equatable {
  final int id;
  final String? salutation;
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
    this.salutation = HonorificHelper.bapak,
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
      salutation: HonorificHelper.normalize(json['salutation'] as String?),
      name: json['name'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      email: json['email'] as String? ?? '',
      roleId: json['role_id'] as int? ?? 0,
      role: (json['role'] as String? ?? 'RESIDENT').toUpperCase(),
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
      'salutation': HonorificHelper.normalize(salutation),
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

  String get displayName {
    return HonorificHelper.formatDisplayName(salutation, name);
  }

  String get roleDisplay {
    switch (role.toUpperCase()) {
      case 'ADMIN':
      case 'ADMIN_RT':
        return 'Administrator';
      case 'CHAIRPERSON':
        return 'Ketua';
      case 'VICE_CHAIRPERSON':
        return 'Wakil Ketua';
      case 'TREASURER':
        return 'Bendahara';
      case 'SECRETARY':
        return 'Sekretaris';
      case 'RESIDENT':
      case 'WARGA':
      default:
        return 'Warga';
    }
  }

  bool get isPending => status == 'pending_verification';
  bool get isActive => status == 'active';

  // Role Checks
  bool get isAdmin => role.toUpperCase() == 'ADMIN' || role.toLowerCase() == 'admin_rt';
  bool get isChairperson => role.toUpperCase() == 'CHAIRPERSON';
  bool get isViceChairperson => role.toUpperCase() == 'VICE_CHAIRPERSON';
  bool get isTreasurer => role.toUpperCase() == 'TREASURER';
  bool get isSecretary => role.toUpperCase() == 'SECRETARY';
  bool get isResident => role.toUpperCase() == 'RESIDENT' || role.toLowerCase() == 'warga';

  // Permission Checks based on Authorization Matrix
  bool get canManageRoles => isAdmin || isChairperson || isViceChairperson;
  bool get canAccessLeadership => isAdmin || isChairperson || isViceChairperson;
  bool get canAccessBillingAdmin => isAdmin || isChairperson || isViceChairperson || isTreasurer;
  bool get canAccessCashbookAdmin => isAdmin || isChairperson || isViceChairperson || isTreasurer;
  bool get canAccessVerificationAdmin => isAdmin || isChairperson || isViceChairperson || isSecretary;
  bool get canAccessHousesAdmin => isAdmin || isChairperson || isViceChairperson || isSecretary;
  bool get canAccessSecurityGuestbookAdmin => isAdmin || isChairperson || isViceChairperson || isSecretary;

  // Has any administrative portal capability
  bool get hasAdminAccess =>
      isAdmin || isChairperson || isViceChairperson || isTreasurer || isSecretary;

  // Housing-based resident Iuran eligibility: Any account mapped to a housing record
  bool get hasHousingAssociation =>
      (houseId != null && houseId! > 0) ||
      (houseBlock != null && houseBlock!.trim().isNotEmpty && houseNumber != null && houseNumber!.trim().isNotEmpty);

  bool get canAccessResidentIuran => hasHousingAssociation;

  String get houseDisplay {
    if (houseBlock != null && houseNumber != null) {
      return 'Blok $houseBlock No. $houseNumber';
    }
    return 'Hunian Belum Terdaftar';
  }

  @override
  List<Object?> get props => [
        id,
        salutation,
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
