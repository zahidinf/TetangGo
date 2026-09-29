import 'package:equatable/equatable.dart';

class HouseModel extends Equatable {
  final int id;
  final String block;
  final String houseNumber;
  final String status;
  final String? residentName;
  final String? residentPhone;
  final int familyCount;
  final int totalOccupants;
  final int vehicleCount;

  const HouseModel({
    required this.id,
    required this.block,
    required this.houseNumber,
    required this.status,
    this.residentName,
    this.residentPhone,
    this.familyCount = 0,
    this.totalOccupants = 0,
    this.vehicleCount = 0,
  });

  factory HouseModel.fromJson(Map<String, dynamic> json) {
    final famCount = json['family_count'] as int? ?? 0;
    final totalOcc = json['total_occupants'] as int? ?? (famCount + (json['resident_name'] != null ? 1 : 0));
    return HouseModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      block: json['block'] as String? ?? '',
      houseNumber: json['house_number'] as String? ?? '',
      status: json['status'] as String? ?? 'kosong',
      residentName: json['resident_name'] as String?,
      residentPhone: json['resident_phone'] as String?,
      familyCount: famCount,
      totalOccupants: totalOcc,
      vehicleCount: json['vehicle_count'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'block': block,
      'house_number': houseNumber,
      'status': status,
      'resident_name': residentName,
      'resident_phone': residentPhone,
      'family_count': familyCount,
      'total_occupants': totalOccupants,
      'vehicle_count': vehicleCount,
    };
  }

  String get label => 'Blok $block No. $houseNumber';

  String get statusDisplay {
    switch (status.toLowerCase()) {
      case 'milik':
        return 'Dihuni Pemilik';
      case 'kontrak':
        return 'Disewa / Kontrak';
      case 'kosong':
      default:
        return 'Kosong';
    }
  }

  @override
  List<Object?> get props => [
        id,
        block,
        houseNumber,
        status,
        residentName,
        residentPhone,
        familyCount,
        totalOccupants,
        vehicleCount,
      ];
}
