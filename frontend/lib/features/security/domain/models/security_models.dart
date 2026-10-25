import 'package:equatable/equatable.dart';

class SecurityAssignmentModel extends Equatable {
  final int id;
  final int userId;
  final int neighborhoodId;
  final String neighborhoodName;
  final String neighborhoodCode;
  final bool isActive;
  final DateTime? assignedAt;
  final String notes;
  final String assignedByName;
  final DateTime? revokedAt;
  final String revokedByName;

  const SecurityAssignmentModel({
    required this.id,
    required this.userId,
    required this.neighborhoodId,
    required this.neighborhoodName,
    required this.neighborhoodCode,
    required this.isActive,
    this.assignedAt,
    this.notes = '',
    this.assignedByName = '',
    this.revokedAt,
    this.revokedByName = '',
  });

  factory SecurityAssignmentModel.fromJson(Map<String, dynamic> json) {
    String nName = '';
    String nCode = '';
    if (json['neighborhood'] is Map) {
      final n = json['neighborhood'] as Map<String, dynamic>;
      nName = n['name'] as String? ?? '';
      nCode = n['code'] as String? ?? '';
    } else {
      nName = json['neighborhood_name'] as String? ??
          'Lingkungan #${json['neighborhood_id']}';
      nCode = json['neighborhood_code'] as String? ?? '';
    }

    DateTime? assigned;
    if (json['assigned_at'] != null) {
      assigned = DateTime.tryParse(json['assigned_at'].toString())?.toLocal();
    }

    DateTime? revoked;
    if (json['revoked_at'] != null) {
      revoked = DateTime.tryParse(json['revoked_at'].toString())?.toLocal();
    }

    return SecurityAssignmentModel(
      id: json['id'] as int? ?? 0,
      userId: json['user_id'] as int? ?? 0,
      neighborhoodId: json['neighborhood_id'] as int? ?? 0,
      neighborhoodName:
          nName.isNotEmpty ? nName : 'Lingkungan #${json['neighborhood_id']}',
      neighborhoodCode: nCode,
      isActive: json['is_active'] as bool? ?? true,
      assignedAt: assigned,
      notes: json['notes'] as String? ?? '',
      assignedByName: json['assigned_by_name'] as String? ?? '',
      revokedAt: revoked,
      revokedByName: json['revoked_by_name'] as String? ?? '',
    );
  }

  @override
  List<Object?> get props => [
        id,
        userId,
        neighborhoodId,
        neighborhoodName,
        neighborhoodCode,
        isActive,
        assignedAt,
        notes,
        assignedByName,
        revokedAt,
        revokedByName,
      ];
}

class NeighborhoodModel extends Equatable {
  final int id;
  final String name;
  final String code;
  final String address;

  const NeighborhoodModel({
    required this.id,
    required this.name,
    this.code = '',
    this.address = '',
  });

  factory NeighborhoodModel.fromJson(Map<String, dynamic> json) {
    return NeighborhoodModel(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      code: json['code'] as String? ?? '',
      address: json['address'] as String? ?? '',
    );
  }

  @override
  List<Object?> get props => [id, name, code, address];
}

class SecurityUserModel extends Equatable {
  final int id;
  final String salutation;
  final String name;
  final String phone;
  final String email;
  final String role;
  final String status;
  final int? houseId; // Strictly null for independent security accounts
  final DateTime? createdAt;
  final List<SecurityAssignmentModel> assignments;

  const SecurityUserModel({
    required this.id,
    required this.salutation,
    required this.name,
    required this.phone,
    required this.email,
    required this.role,
    required this.status,
    this.houseId,
    this.createdAt,
    this.assignments = const [],
  });

  bool get isActive => status.toLowerCase() == 'active';

  String get displayName =>
      '${salutation.isNotEmpty ? '$salutation ' : ''}$name'.trim();

  SecurityUserModel copyWith({
    int? id,
    String? salutation,
    String? name,
    String? phone,
    String? email,
    String? role,
    String? status,
    int? houseId,
    DateTime? createdAt,
    List<SecurityAssignmentModel>? assignments,
  }) {
    return SecurityUserModel(
      id: id ?? this.id,
      salutation: salutation ?? this.salutation,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      role: role ?? this.role,
      status: status ?? this.status,
      houseId: houseId ?? this.houseId,
      createdAt: createdAt ?? this.createdAt,
      assignments: assignments ?? this.assignments,
    );
  }

  factory SecurityUserModel.fromJson(Map<String, dynamic> json) {
    DateTime? created;
    if (json['created_at'] != null) {
      created = DateTime.tryParse(json['created_at'].toString())?.toLocal();
    }
    return SecurityUserModel(
      id: json['id'] as int? ?? 0,
      salutation: json['salutation'] as String? ?? 'Bapak',
      name: json['name'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      email: json['email'] as String? ?? '',
      role: (json['role'] as String? ??
              json['role_name'] as String? ??
              'SECURITY')
          .toUpperCase(),
      status: (json['status'] as String? ?? 'active').toLowerCase(),
      houseId: json['house_id'] as int?,
      createdAt: created,
    );
  }

  @override
  List<Object?> get props => [
        id,
        salutation,
        name,
        phone,
        email,
        role,
        status,
        houseId,
        createdAt,
        assignments,
      ];
}

class SecurityIncidentModel extends Equatable {
  final int id;
  final String category;
  final String title;
  final String description;
  final String status;
  final int neighborhoodId;
  final String neighborhoodName;
  final int? houseId;
  final String? houseBlock;
  final String? houseNumber;
  final int reporterId;
  final String reporterName;
  final String? reporterPhone;
  final double? latitude;
  final double? longitude;
  final String? locationSource;
  final DateTime reportedAt;
  final int? assignedSecurityId;
  final String? assignedSecurityName;
  final DateTime? handlingStartedAt;
  final DateTime? resolvedAt;
  final String? resolutionNotes;

  const SecurityIncidentModel({
    required this.id,
    required this.category,
    required this.title,
    required this.description,
    required this.status,
    required this.neighborhoodId,
    this.neighborhoodName = '',
    this.houseId,
    this.houseBlock,
    this.houseNumber,
    required this.reporterId,
    required this.reporterName,
    this.reporterPhone,
    this.latitude,
    this.longitude,
    this.locationSource,
    required this.reportedAt,
    this.assignedSecurityId,
    this.assignedSecurityName,
    this.handlingStartedAt,
    this.resolvedAt,
    this.resolutionNotes,
  });

  bool get isActive => status == 'ACTIVE' || status == 'REPORTED';
  bool get isAcknowledged => status == 'ACKNOWLEDGED' || status == 'RESPONDING';
  bool get isResolved => status == 'RESOLVED';

  String get houseDisplay {
    if (houseBlock != null &&
        houseBlock!.trim().isNotEmpty &&
        houseNumber != null &&
        houseNumber!.trim().isNotEmpty) {
      return 'Blok ${houseBlock!.trim()} No. ${houseNumber!.trim()}';
    }
    return 'Hunian belum terdata';
  }

  String get categoryDisplay {
    switch (category.toUpperCase()) {
      case 'KEJAHATAN':
        return 'Tindak Kejahatan / Kriminal';
      case 'KEBAKARAN':
        return 'Kebakaran & Api';
      case 'MEDIS':
        return 'Darurat Medis / Kesehatan';
      default:
        return category.toUpperCase();
    }
  }

  factory SecurityIncidentModel.fromJson(Map<String, dynamic> json) {
    String repName = 'Warga';
    String? repPhone;
    if (json['reporter'] is Map) {
      final r = json['reporter'] as Map<String, dynamic>;
      repName = r['name'] as String? ?? 'Warga';
      repPhone = r['phone'] as String?;
    } else {
      repName = json['reporter_name'] as String? ?? 'Warga';
      repPhone = json['reporter_phone'] as String?;
    }

    String? block;
    String? numStr;
    if (json['house'] is Map) {
      final h = json['house'] as Map<String, dynamic>;
      block = h['block'] as String?;
      numStr = h['house_number'] as String?;
    } else {
      block = json['house_block'] as String?;
      numStr = json['house_number'] as String?;
    }

    String nName = '';
    if (json['neighborhood'] is Map) {
      final n = json['neighborhood'] as Map<String, dynamic>;
      nName = n['name'] as String? ?? '';
    } else {
      nName = json['neighborhood_name'] as String? ?? '';
    }

    String? secName;
    if (json['assigned_security'] is Map) {
      final s = json['assigned_security'] as Map<String, dynamic>;
      secName = s['name'] as String?;
    } else {
      secName = json['assigned_security_name'] as String?;
    }

    DateTime reported = DateTime.now();
    if (json['reported_at'] != null) {
      reported = DateTime.tryParse(json['reported_at'].toString())?.toLocal() ??
          DateTime.now();
    }

    DateTime? started;
    if (json['handling_started_at'] != null) {
      started =
          DateTime.tryParse(json['handling_started_at'].toString())?.toLocal();
    }

    DateTime? resolved;
    if (json['resolved_at'] != null) {
      resolved = DateTime.tryParse(json['resolved_at'].toString())?.toLocal();
    }

    double? lat;
    if (json['latitude'] != null) {
      lat = double.tryParse(json['latitude'].toString());
    }

    double? lon;
    if (json['longitude'] != null) {
      lon = double.tryParse(json['longitude'].toString());
    }

    return SecurityIncidentModel(
      id: json['id'] as int? ?? json['incident_id'] as int? ?? 0,
      category: (json['category'] as String? ?? 'UMUM').toUpperCase(),
      title: json['title'] as String? ?? 'Insiden Darurat',
      description: json['description'] as String? ?? '',
      status: (json['status'] as String? ?? 'ACTIVE').toUpperCase(),
      neighborhoodId: json['neighborhood_id'] as int? ?? 0,
      neighborhoodName: nName,
      houseId: json['house_id'] as int?,
      houseBlock: block,
      houseNumber: numStr,
      reporterId: json['reporter_id'] as int? ?? 0,
      reporterName: repName,
      reporterPhone: repPhone,
      latitude: lat,
      longitude: lon,
      locationSource: json['location_source'] as String?,
      reportedAt: reported,
      assignedSecurityId: json['assigned_security_id'] as int?,
      assignedSecurityName: secName,
      handlingStartedAt: started,
      resolvedAt: resolved,
      resolutionNotes: json['resolution_notes'] as String?,
    );
  }

  SecurityIncidentModel copyWith({
    int? id,
    String? category,
    String? title,
    String? description,
    String? status,
    int? neighborhoodId,
    String? neighborhoodName,
    int? houseId,
    String? houseBlock,
    String? houseNumber,
    int? reporterId,
    String? reporterName,
    String? reporterPhone,
    double? latitude,
    double? longitude,
    String? locationSource,
    DateTime? reportedAt,
    int? assignedSecurityId,
    String? assignedSecurityName,
    DateTime? handlingStartedAt,
    DateTime? resolvedAt,
    String? resolutionNotes,
  }) {
    return SecurityIncidentModel(
      id: id ?? this.id,
      category: category ?? this.category,
      title: title ?? this.title,
      description: description ?? this.description,
      status: status ?? this.status,
      neighborhoodId: neighborhoodId ?? this.neighborhoodId,
      neighborhoodName: neighborhoodName ?? this.neighborhoodName,
      houseId: houseId ?? this.houseId,
      houseBlock: houseBlock ?? this.houseBlock,
      houseNumber: houseNumber ?? this.houseNumber,
      reporterId: reporterId ?? this.reporterId,
      reporterName: reporterName ?? this.reporterName,
      reporterPhone: reporterPhone ?? this.reporterPhone,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      locationSource: locationSource ?? this.locationSource,
      reportedAt: reportedAt ?? this.reportedAt,
      assignedSecurityId: assignedSecurityId ?? this.assignedSecurityId,
      assignedSecurityName:
          assignedSecurityName ?? this.assignedSecurityName,
      handlingStartedAt: handlingStartedAt ?? this.handlingStartedAt,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      resolutionNotes: resolutionNotes ?? this.resolutionNotes,
    );
  }

  @override
  List<Object?> get props => [
        id,
        category,
        title,
        description,
        status,
        neighborhoodId,
        neighborhoodName,
        houseId,
        houseBlock,
        houseNumber,
        reporterId,
        reporterName,
        reporterPhone,
        latitude,
        longitude,
        locationSource,
        reportedAt,
        assignedSecurityId,
        assignedSecurityName,
        handlingStartedAt,
        resolvedAt,
        resolutionNotes,
      ];
}

class IncidentLogModel extends Equatable {
  final int id;
  final int incidentId;
  final int userId;
  final String userName;
  final String userRole;
  final String action;
  final String? previousStatus;
  final String? newStatus;
  final String notes;
  final DateTime createdAt;

  const IncidentLogModel({
    required this.id,
    required this.incidentId,
    required this.userId,
    this.userName = '',
    this.userRole = '',
    required this.action,
    this.previousStatus,
    this.newStatus,
    this.notes = '',
    required this.createdAt,
  });

  factory IncidentLogModel.fromJson(Map<String, dynamic> json) {
    DateTime created = DateTime.now();
    if (json['created_at'] != null) {
      created = DateTime.tryParse(json['created_at'].toString())?.toLocal() ??
          DateTime.now();
    }
    return IncidentLogModel(
      id: json['id'] as int? ?? 0,
      incidentId: json['incident_id'] as int? ?? 0,
      userId: json['user_id'] as int? ?? 0,
      userName: json['user_name'] as String? ?? '',
      userRole: json['user_role'] as String? ?? '',
      action: json['action'] as String? ?? '',
      previousStatus: json['previous_status'] as String?,
      newStatus: json['new_status'] as String?,
      notes: json['notes'] as String? ?? '',
      createdAt: created,
    );
  }

  @override
  List<Object?> get props => [
        id,
        incidentId,
        userId,
        userName,
        userRole,
        action,
        previousStatus,
        newStatus,
        notes,
        createdAt,
      ];
}

class IncidentListResponse extends Equatable {
  final List<SecurityIncidentModel> incidents;
  final int total;
  final int page;
  final int limit;
  final int totalPages;

  const IncidentListResponse({
    required this.incidents,
    required this.total,
    required this.page,
    required this.limit,
    required this.totalPages,
  });

  factory IncidentListResponse.fromJson(Map<String, dynamic> json) {
    final List list = json['data'] as List? ?? [];
    final meta = json['meta'] as Map<String, dynamic>? ?? {};
    final incidents = list
        .map((e) => SecurityIncidentModel.fromJson(e as Map<String, dynamic>))
        .toList();
    return IncidentListResponse(
      incidents: incidents,
      total: meta['total'] as int? ?? incidents.length,
      page: meta['page'] as int? ?? 1,
      limit: meta['limit'] as int? ?? 20,
      totalPages: meta['total_pages'] as int? ?? 1,
    );
  }

  @override
  List<Object?> get props => [incidents, total, page, limit, totalPages];
}
