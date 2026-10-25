import 'package:equatable/equatable.dart';

class VehicleModel extends Equatable {
  final int id;
  final int houseId;
  final String plateNumber;
  final String vehicleType; // 'mobil' or 'motor'
  final String? brandModel;
  final DateTime createdAt;

  const VehicleModel({
    required this.id,
    required this.houseId,
    required this.plateNumber,
    required this.vehicleType,
    this.brandModel,
    required this.createdAt,
  });

  factory VehicleModel.fromJson(Map<String, dynamic> json) {
    return VehicleModel(
      id: json['id'] as int,
      houseId: json['house_id'] as int? ?? 0,
      plateNumber: json['plate_number'] as String? ?? '',
      vehicleType: json['vehicle_type'] as String? ?? 'motor',
      brandModel: json['brand_model'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  bool get isCar => vehicleType.toLowerCase() == 'mobil';

  String get typeDisplay => isCar ? 'Mobil' : 'Motor';

  @override
  List<Object?> get props =>
      [id, houseId, plateNumber, vehicleType, brandModel, createdAt];
}
