import 'package:equatable/equatable.dart';

enum PanicCategory {
  kejahatan('KEJAHATAN', 'Maling / Kejahatan',
      'Ancaman keamanan, pencurian, atau tindak kriminal'),
  kebakaran('KEBAKARAN', 'Kebakaran',
      'Indikasi api, ledakan gas, atau potensi bahaya kebakaran'),
  medis('MEDIS', 'Darurat Medis', 'Kebutuhan pertolongan medis darurat segera');

  final String code;
  final String label;
  final String description;

  const PanicCategory(this.code, this.label, this.description);

  static PanicCategory fromCode(String code) {
    return PanicCategory.values.firstWhere(
      (c) => c.code == code.toUpperCase(),
      orElse: () => PanicCategory.kejahatan,
    );
  }
}

class IncidentReportModel extends Equatable {
  final int id;
  final String category;
  final String title;
  final String description;
  final String status;
  final int neighborhoodId;
  final DateTime reportedAt;
  final double? latitude;
  final double? longitude;
  final String? locationSource;
  final double? locationAccuracy;

  const IncidentReportModel({
    required this.id,
    required this.category,
    required this.title,
    required this.description,
    required this.status,
    required this.neighborhoodId,
    required this.reportedAt,
    this.latitude,
    this.longitude,
    this.locationSource,
    this.locationAccuracy,
  });

  factory IncidentReportModel.fromJson(Map<String, dynamic> json) {
    return IncidentReportModel(
      id: json['id'] as int? ?? 0,
      category: json['category'] as String? ?? 'KEJAHATAN',
      title: json['title'] as String? ?? 'Laporan Darurat',
      description: json['description'] as String? ?? '',
      status: json['status'] as String? ?? 'ACTIVE',
      neighborhoodId: json['neighborhood_id'] as int? ?? 1,
      reportedAt: json['reported_at'] != null
          ? DateTime.tryParse(json['reported_at'] as String) ?? DateTime.now()
          : DateTime.now(),
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      locationSource: json['location_source'] as String?,
      locationAccuracy: (json['location_accuracy'] as num?)?.toDouble(),
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
        reportedAt,
        latitude,
        longitude,
        locationSource,
      ];
}
