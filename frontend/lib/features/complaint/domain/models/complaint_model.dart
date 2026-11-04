import 'package:equatable/equatable.dart';

enum ComplaintCategory {
  lampuJalan('Lampu Jalan'),
  sampah('Sampah'),
  ketertiban('Ketertiban'),
  jalanan('Jalanan');

  final String label;
  const ComplaintCategory(this.label);

  static ComplaintCategory fromString(String val) {
    switch (val.trim()) {
      case 'Lampu Jalan':
        return ComplaintCategory.lampuJalan;
      case 'Sampah':
        return ComplaintCategory.sampah;
      case 'Ketertiban':
        return ComplaintCategory.ketertiban;
      case 'Jalanan':
        return ComplaintCategory.jalanan;
      default:
        return ComplaintCategory.lampuJalan;
    }
  }
}

enum ComplaintStatus {
  menunggu('Menunggu'),
  diproses('Diproses'),
  selesai('Selesai'),
  ditolak('Ditolak');

  final String label;
  const ComplaintStatus(this.label);

  static ComplaintStatus fromString(String val) {
    switch (val.trim()) {
      case 'Menunggu':
        return ComplaintStatus.menunggu;
      case 'Diproses':
        return ComplaintStatus.diproses;
      case 'Selesai':
        return ComplaintStatus.selesai;
      case 'Ditolak':
        return ComplaintStatus.ditolak;
      default:
        return ComplaintStatus.menunggu;
    }
  }
}

class ComplaintModel extends Equatable {
  final int id;
  final String ticketNumber;
  final int userId;
  final int houseId;
  final String title;
  final String description;
  final ComplaintCategory category;
  final String? photoUrl;
  final ComplaintStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? reporterName;
  final String? houseBlock;
  final String? houseNumber;
  final String? assignedOfficer;
  final int? assignedOfficerId;
  final DateTime? assignedAt;

  const ComplaintModel({
    required this.id,
    required this.ticketNumber,
    required this.userId,
    required this.houseId,
    required this.title,
    required this.description,
    required this.category,
    this.photoUrl,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.reporterName,
    this.houseBlock,
    this.houseNumber,
    this.assignedOfficer,
    this.assignedOfficerId,
    this.assignedAt,
  });

  String get houseDisplay {
    if (houseBlock != null && houseNumber != null) {
      return 'Blok $houseBlock No. $houseNumber';
    }
    return '';
  }

  factory ComplaintModel.fromJson(Map<String, dynamic> json) {
    return ComplaintModel(
      id: json['id'] as int? ?? 0,
      ticketNumber: json['ticket_number'] as String? ?? '',
      userId: json['user_id'] as int? ?? 0,
      houseId: json['house_id'] as int? ?? 0,
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      category: ComplaintCategory.fromString(json['category'] as String? ?? ''),
      photoUrl: json['photo_url'] as String?,
      status: ComplaintStatus.fromString(json['status'] as String? ?? ''),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String) ?? DateTime.now()
          : DateTime.now(),
      reporterName: json['reporter_name'] as String?,
      houseBlock: json['house_block'] as String?,
      houseNumber: json['house_number'] as String?,
      assignedOfficer: json['assigned_officer'] as String?,
      assignedOfficerId: json['assigned_officer_id'] as int?,
      assignedAt: json['assigned_at'] != null
          ? DateTime.tryParse(json['assigned_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'ticket_number': ticketNumber,
      'user_id': userId,
      'house_id': houseId,
      'title': title,
      'description': description,
      'category': category.label,
      'photo_url': photoUrl,
      'status': status.label,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'reporter_name': reporterName,
      'house_block': houseBlock,
      'house_number': houseNumber,
      'assigned_officer': assignedOfficer,
      'assigned_officer_id': assignedOfficerId,
      'assigned_at': assignedAt?.toIso8601String(),
    };
  }

  ComplaintModel copyWith({
    int? id,
    String? ticketNumber,
    int? userId,
    int? houseId,
    String? title,
    String? description,
    ComplaintCategory? category,
    String? photoUrl,
    ComplaintStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? reporterName,
    String? houseBlock,
    String? houseNumber,
    String? assignedOfficer,
    int? assignedOfficerId,
    DateTime? assignedAt,
  }) {
    return ComplaintModel(
      id: id ?? this.id,
      ticketNumber: ticketNumber ?? this.ticketNumber,
      userId: userId ?? this.userId,
      houseId: houseId ?? this.houseId,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      photoUrl: photoUrl ?? this.photoUrl,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      reporterName: reporterName ?? this.reporterName,
      houseBlock: houseBlock ?? this.houseBlock,
      houseNumber: houseNumber ?? this.houseNumber,
      assignedOfficer: assignedOfficer ?? this.assignedOfficer,
      assignedOfficerId: assignedOfficerId ?? this.assignedOfficerId,
      assignedAt: assignedAt ?? this.assignedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        ticketNumber,
        userId,
        houseId,
        title,
        description,
        category,
        photoUrl,
        status,
        createdAt,
        updatedAt,
        reporterName,
        houseBlock,
        houseNumber,
        assignedOfficer,
        assignedOfficerId,
        assignedAt,
      ];
}

// US-5.4 Assignment Audit Model
class ComplaintAssignmentModel extends Equatable {
  final int id;
  final int complaintId;
  final String officerName;
  final int? officerUserId;
  final int assignedBy;
  final String? assignedByName;
  final String? notes;
  final DateTime assignedAt;
  final DateTime createdAt;

  const ComplaintAssignmentModel({
    required this.id,
    required this.complaintId,
    required this.officerName,
    this.officerUserId,
    required this.assignedBy,
    this.assignedByName,
    this.notes,
    required this.assignedAt,
    required this.createdAt,
  });

  factory ComplaintAssignmentModel.fromJson(Map<String, dynamic> json) {
    return ComplaintAssignmentModel(
      id: json['id'] as int? ?? 0,
      complaintId: json['complaint_id'] as int? ?? 0,
      officerName: json['officer_name'] as String? ?? '',
      officerUserId: json['officer_user_id'] as int?,
      assignedBy: json['assigned_by'] as int? ?? 0,
      assignedByName: json['assigned_by_name'] as String?,
      notes: json['notes'] as String?,
      assignedAt: json['assigned_at'] != null
          ? DateTime.tryParse(json['assigned_at'] as String) ?? DateTime.now()
          : DateTime.now(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  @override
  List<Object?> get props => [
        id,
        complaintId,
        officerName,
        officerUserId,
        assignedBy,
        assignedByName,
        notes,
        assignedAt,
        createdAt,
      ];
}

// US-5.4 Kanban Data Model
class KanbanComplaintsData extends Equatable {
  final List<ComplaintModel> menunggu;
  final List<ComplaintModel> diproses;
  final List<ComplaintModel> selesai;
  final Map<String, int> counts;

  const KanbanComplaintsData({
    required this.menunggu,
    required this.diproses,
    required this.selesai,
    required this.counts,
  });

  factory KanbanComplaintsData.fromJson(Map<String, dynamic> json) {
    final rawMenunggu = json['menunggu'] as List<dynamic>? ?? [];
    final rawDiproses = json['diproses'] as List<dynamic>? ?? [];
    final rawSelesai = json['selesai'] as List<dynamic>? ?? [];
    final rawCounts = json['counts'] as Map<String, dynamic>? ?? {};

    return KanbanComplaintsData(
      menunggu: rawMenunggu
          .map((e) => ComplaintModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      diproses: rawDiproses
          .map((e) => ComplaintModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      selesai: rawSelesai
          .map((e) => ComplaintModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      counts: rawCounts.map((k, v) => MapEntry(k, v as int? ?? 0)),
    );
  }

  @override
  List<Object?> get props => [menunggu, diproses, selesai, counts];
}

// US-5.4 Eligible Officer Model
class EligibleOfficerModel extends Equatable {
  final int id;
  final String name;
  final String role;
  final String phone;
  final String status;

  const EligibleOfficerModel({
    required this.id,
    required this.name,
    required this.role,
    required this.phone,
    required this.status,
  });

  factory EligibleOfficerModel.fromJson(Map<String, dynamic> json) {
    return EligibleOfficerModel(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      role: json['role'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      status: json['status'] as String? ?? '',
    );
  }

  @override
  List<Object?> get props => [id, name, role, phone, status];
}
