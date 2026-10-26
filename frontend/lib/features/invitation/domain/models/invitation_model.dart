import 'package:equatable/equatable.dart';

enum VisitType { tamu, kurir }

extension VisitTypeExtension on VisitType {
  String toApi() {
    switch (this) {
      case VisitType.tamu:
        return 'TAMU';
      case VisitType.kurir:
        return 'KURIR';
    }
  }

  String get label {
    switch (this) {
      case VisitType.tamu:
        return 'Tamu Warga';
      case VisitType.kurir:
        return 'Kurir / Paket / Delivery';
    }
  }

  static VisitType fromApi(String? val) {
    if (val?.toUpperCase() == 'KURIR') {
      return VisitType.kurir;
    }
    return VisitType.tamu;
  }
}

enum InvitationStatus { active, used, completed, cancelled, expired }

extension InvitationStatusExtension on InvitationStatus {
  String toApi() {
    switch (this) {
      case InvitationStatus.active:
        return 'ACTIVE';
      case InvitationStatus.used:
        return 'USED';
      case InvitationStatus.completed:
        return 'COMPLETED';
      case InvitationStatus.cancelled:
        return 'CANCELLED';
      case InvitationStatus.expired:
        return 'EXPIRED';
    }
  }

  String get label {
    switch (this) {
      case InvitationStatus.active:
        return 'Aktif';
      case InvitationStatus.used:
        return 'Sudah Digunakan';
      case InvitationStatus.completed:
        return 'Selesai';
      case InvitationStatus.cancelled:
        return 'Dibatalkan';
      case InvitationStatus.expired:
        return 'Kedaluwarsa';
    }
  }

  static InvitationStatus fromApi(String? val) {
    switch (val?.toUpperCase()) {
      case 'USED':
        return InvitationStatus.used;
      case 'COMPLETED':
        return InvitationStatus.completed;
      case 'CANCELLED':
        return InvitationStatus.cancelled;
      case 'EXPIRED':
        return InvitationStatus.expired;
      case 'ACTIVE':
      default:
        return InvitationStatus.active;
    }
  }
}

class GuestInvitationModel extends Equatable {
  final int id;
  final String invitationCode;
  final int hostUserId;
  final int houseId;
  final String guestName;
  final VisitType visitType;
  final String? phone;
  final String? notes;
  final DateTime validFrom;
  final DateTime validUntil;
  final InvitationStatus status;
  final String qrPayload;
  final DateTime? cancelledAt;
  final String? cancellationReason;
  final DateTime createdAt;
  final String? hostName;
  final String? houseBlock;
  final String? houseNumber;
  final bool hasActiveSession;
  final int completedVisitsCount;

  const GuestInvitationModel({
    required this.id,
    required this.invitationCode,
    required this.hostUserId,
    required this.houseId,
    required this.guestName,
    required this.visitType,
    this.phone,
    this.notes,
    required this.validFrom,
    required this.validUntil,
    required this.status,
    required this.qrPayload,
    this.cancelledAt,
    this.cancellationReason,
    required this.createdAt,
    this.hostName,
    this.houseBlock,
    this.houseNumber,
    this.hasActiveSession = false,
    this.completedVisitsCount = 0,
  });

  bool get isActive {
    if (status != InvitationStatus.active) return false;
    return validUntil.isAfter(DateTime.now());
  }

  // Tombol Akhiri Undangan hanya tersedia ketika:
  // 1. Setidaknya sudah ada sesi kunjungan yang selesai checkout (completedVisitsCount > 0)
  // 2. Tidak ada sesi kunjungan yang sedang aktif (!hasActiveSession)
  // 3. Undangan masih dalam masa berlaku (validUntil > now)
  // 4. Belum dibatalkan (bukan CANCELLED) atau diakhiri (bukan COMPLETED)
  bool get canBeCompleted {
    if (status == InvitationStatus.cancelled ||
        status == InvitationStatus.completed ||
        status == InvitationStatus.expired) {
      return false;
    }
    if (hasActiveSession) return false;
    if (completedVisitsCount <= 0) return false;
    return validUntil.isAfter(DateTime.now());
  }

  // Batalkan Undangan tersedia untuk undangan aktif yang belum pernah diselesaikan
  bool get canBeCancelled => isActive && completedVisitsCount == 0 && !hasActiveSession;

  String get houseDisplay {
    if (houseBlock != null && houseNumber != null) {
      return 'Blok $houseBlock No. $houseNumber';
    }
    return '';
  }

  factory GuestInvitationModel.fromJson(Map<String, dynamic> json) {
    return GuestInvitationModel(
      id: json['id'] as int? ?? 0,
      invitationCode: json['invitation_code'] as String? ?? '',
      hostUserId: json['host_user_id'] as int? ?? 0,
      houseId: json['house_id'] as int? ?? 0,
      guestName: json['guest_name'] as String? ?? '',
      visitType: VisitTypeExtension.fromApi(json['visit_type'] as String?),
      phone: json['phone'] as String?,
      notes: json['notes'] as String?,
      validFrom: DateTime.tryParse(json['valid_from'] as String? ?? '')?.toLocal() ?? DateTime.now(),
      validUntil: DateTime.tryParse(json['valid_until'] as String? ?? '')?.toLocal() ?? DateTime.now(),
      status: InvitationStatusExtension.fromApi(json['status'] as String?),
      qrPayload: json['qr_payload'] as String? ?? '',
      cancelledAt: json['cancelled_at'] != null
          ? DateTime.tryParse(json['cancelled_at'].toString())?.toLocal()
          : null,
      cancellationReason: json['cancellation_reason'] as String?,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '')?.toLocal() ?? DateTime.now(),
      hostName: json['host_name'] as String?,
      houseBlock: json['house_block'] as String?,
      houseNumber: json['house_number'] as String?,
      hasActiveSession: json['has_active_session'] as bool? ?? false,
      completedVisitsCount: json['completed_visits_count'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'invitation_code': invitationCode,
        'host_user_id': hostUserId,
        'house_id': houseId,
        'guest_name': guestName,
        'visit_type': visitType.toApi(),
        'phone': phone,
        'notes': notes,
        'valid_from': validFrom.toIso8601String(),
        'valid_until': validUntil.toIso8601String(),
        'status': status.toApi(),
        'qr_payload': qrPayload,
        'has_active_session': hasActiveSession,
        'completed_visits_count': completedVisitsCount,
      };

  @override
  List<Object?> get props => [
        id,
        invitationCode,
        hostUserId,
        houseId,
        guestName,
        visitType,
        phone,
        notes,
        validFrom,
        validUntil,
        status,
        qrPayload,
        cancelledAt,
        cancellationReason,
        createdAt,
        hostName,
        houseBlock,
        houseNumber,
        hasActiveSession,
        completedVisitsCount,
      ];
}

// US-5.2: Guest Visit Models

enum VisitStatus {
  checkedIn,
  checkedOut,
}

extension VisitStatusExtension on VisitStatus {
  String toApi() {
    switch (this) {
      case VisitStatus.checkedIn:
        return 'CHECKED_IN';
      case VisitStatus.checkedOut:
        return 'CHECKED_OUT';
    }
  }

  String get label {
    switch (this) {
      case VisitStatus.checkedIn:
        return 'Sedang Berkunjung';
      case VisitStatus.checkedOut:
        return 'Selesai / Keluar';
    }
  }

  static VisitStatus fromApi(String? val) {
    if (val?.toUpperCase() == 'CHECKED_OUT') {
      return VisitStatus.checkedOut;
    }
    return VisitStatus.checkedIn;
  }
}

class GuestVisitModel extends Equatable {
  final int id;
  final int invitationID;
  final DateTime checkInAt;
  final int checkInBy;
  final DateTime? checkOutAt;
  final int? checkOutBy;
  final VisitStatus status;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Enriched fields
  final String? invitationCode;
  final String? guestName;
  final VisitType visitType;
  final String? hostName;
  final String? houseBlock;
  final String? houseNumber;
  final String? checkInByName;
  final String? checkOutByName;

  const GuestVisitModel({
    required this.id,
    required this.invitationID,
    required this.checkInAt,
    required this.checkInBy,
    this.checkOutAt,
    this.checkOutBy,
    required this.status,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.invitationCode,
    this.guestName,
    this.visitType = VisitType.tamu,
    this.hostName,
    this.houseBlock,
    this.houseNumber,
    this.checkInByName,
    this.checkOutByName,
  });

  String get houseDisplay {
    if (houseBlock != null && houseNumber != null) {
      return 'Blok $houseBlock No. $houseNumber';
    }
    return '';
  }

  factory GuestVisitModel.fromJson(Map<String, dynamic> json) {
    return GuestVisitModel(
      id: json['id'] as int? ?? 0,
      invitationID: json['invitation_id'] as int? ?? 0,
      checkInAt: DateTime.tryParse(json['check_in_at'] as String? ?? '')?.toLocal() ?? DateTime.now(),
      checkInBy: json['check_in_by'] as int? ?? 0,
      checkOutAt: json['check_out_at'] != null
          ? DateTime.tryParse(json['check_out_at'].toString())?.toLocal()
          : null,
      checkOutBy: json['check_out_by'] as int?,
      status: VisitStatusExtension.fromApi(json['status'] as String?),
      notes: json['notes'] as String?,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '')?.toLocal() ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? '')?.toLocal() ?? DateTime.now(),
      invitationCode: json['invitation_code'] as String?,
      guestName: json['guest_name'] as String?,
      visitType: VisitTypeExtension.fromApi(json['visit_type'] as String?),
      hostName: json['host_name'] as String?,
      houseBlock: json['house_block'] as String?,
      houseNumber: json['house_number'] as String?,
      checkInByName: json['check_in_by_name'] as String?,
      checkOutByName: json['check_out_by_name'] as String?,
    );
  }

  @override
  List<Object?> get props => [
        id,
        invitationID,
        checkInAt,
        checkInBy,
        checkOutAt,
        checkOutBy,
        status,
        notes,
        createdAt,
        updatedAt,
        invitationCode,
        guestName,
        visitType,
        hostName,
        houseBlock,
        houseNumber,
        checkInByName,
        checkOutByName,
      ];
}

class VerifyInvitationResult extends Equatable {
  final bool valid;
  final InvitationStatus status;
  final String message;
  final GuestInvitationModel? invitation;
  final GuestVisitModel? activeVisit;

  const VerifyInvitationResult({
    required this.valid,
    required this.status,
    required this.message,
    this.invitation,
    this.activeVisit,
  });

  factory VerifyInvitationResult.fromJson(Map<String, dynamic> json) {
    return VerifyInvitationResult(
      valid: json['valid'] as bool? ?? false,
      status: InvitationStatusExtension.fromApi(json['status'] as String?),
      message: json['message'] as String? ?? '',
      invitation: json['data'] != null
          ? GuestInvitationModel.fromJson(json['data'] as Map<String, dynamic>)
          : null,
      activeVisit: json['active_visit'] != null
          ? GuestVisitModel.fromJson(json['active_visit'] as Map<String, dynamic>)
          : null,
    );
  }

  @override
  List<Object?> get props => [valid, status, message, invitation, activeVisit];
}

class GuestVisitGroupModel extends Equatable {
  final int invitationID;
  final String invitationCode;
  final String guestName;
  final VisitType visitType;
  final String hostName;
  final String houseBlock;
  final String houseNumber;
  final InvitationStatus invitationStatus;
  final DateTime validFrom;
  final DateTime validUntil;
  final String? phone;
  final String? notes;
  final bool hasActiveSession;
  final int? activeVisitID;
  final DateTime firstCheckInAt;
  final DateTime latestActivityAt;
  final int totalVisits;
  final List<GuestVisitModel> visits;

  const GuestVisitGroupModel({
    required this.invitationID,
    required this.invitationCode,
    required this.guestName,
    required this.visitType,
    required this.hostName,
    required this.houseBlock,
    required this.houseNumber,
    required this.invitationStatus,
    required this.validFrom,
    required this.validUntil,
    this.phone,
    this.notes,
    required this.hasActiveSession,
    this.activeVisitID,
    required this.firstCheckInAt,
    required this.latestActivityAt,
    required this.totalVisits,
    required this.visits,
  });

  String get houseDisplay {
    if (houseBlock.isNotEmpty && houseNumber.isNotEmpty) {
      return 'Blok $houseBlock No. $houseNumber';
    }
    return '';
  }

  bool get isInvitationActive {
    if (invitationStatus != InvitationStatus.active) return false;
    return validUntil.isAfter(DateTime.now());
  }

  factory GuestVisitGroupModel.fromJson(Map<String, dynamic> json) {
    final visitsJson = json['visits'] as List? ?? [];
    return GuestVisitGroupModel(
      invitationID: json['invitation_id'] as int? ?? 0,
      invitationCode: json['invitation_code'] as String? ?? '',
      guestName: json['guest_name'] as String? ?? '',
      visitType: VisitTypeExtension.fromApi(json['visit_type'] as String?),
      hostName: json['host_name'] as String? ?? '',
      houseBlock: json['house_block'] as String? ?? '',
      houseNumber: json['house_number'] as String? ?? '',
      invitationStatus:
          InvitationStatusExtension.fromApi(json['invitation_status'] as String?),
      validFrom: DateTime.tryParse(json['valid_from'] as String? ?? '')?.toLocal() ??
          DateTime.now(),
      validUntil:
          DateTime.tryParse(json['valid_until'] as String? ?? '')?.toLocal() ??
              DateTime.now(),
      phone: json['phone'] as String?,
      notes: json['notes'] as String?,
      hasActiveSession: json['has_active_session'] as bool? ?? false,
      activeVisitID: json['active_visit_id'] as int?,
      firstCheckInAt:
          DateTime.tryParse(json['first_check_in_at'] as String? ?? '')?.toLocal() ??
              DateTime.now(),
      latestActivityAt:
          DateTime.tryParse(json['latest_activity_at'] as String? ?? '')?.toLocal() ??
              DateTime.now(),
      totalVisits: json['total_visits'] as int? ?? 0,
      visits: visitsJson
          .map((v) => GuestVisitModel.fromJson(v as Map<String, dynamic>))
          .toList(),
    );
  }

  @override
  List<Object?> get props => [
        invitationID,
        invitationCode,
        guestName,
        visitType,
        hostName,
        houseBlock,
        houseNumber,
        invitationStatus,
        validFrom,
        validUntil,
        phone,
        notes,
        hasActiveSession,
        activeVisitID,
        firstCheckInAt,
        latestActivityAt,
        totalVisits,
        visits,
      ];
}

