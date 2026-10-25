import 'package:equatable/equatable.dart';
import '../../../profile/domain/models/family_member_model.dart';
import '../../../profile/domain/models/vehicle_model.dart';
import 'house_model.dart';

class HeadOfFamilyModel extends Equatable {
  final int id;
  final String name;
  final String phone;
  final String email;

  const HeadOfFamilyModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.email,
  });

  factory HeadOfFamilyModel.fromJson(Map<String, dynamic> json) {
    return HeadOfFamilyModel(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      email: json['email'] as String? ?? '',
    );
  }

  @override
  List<Object?> get props => [id, name, phone, email];
}

class HouseDetailFullModel extends Equatable {
  final HouseModel house;
  final HeadOfFamilyModel? headOfFamily;
  final int totalMembers;
  final List<FamilyMemberModel> familyMembers;
  final List<VehicleModel> vehicles;

  const HouseDetailFullModel({
    required this.house,
    this.headOfFamily,
    required this.totalMembers,
    required this.familyMembers,
    required this.vehicles,
  });

  factory HouseDetailFullModel.fromJson(Map<String, dynamic> json) {
    return HouseDetailFullModel(
      house: HouseModel.fromJson(json['house'] as Map<String, dynamic>),
      headOfFamily: json['head_of_family'] != null
          ? HeadOfFamilyModel.fromJson(
              json['head_of_family'] as Map<String, dynamic>)
          : null,
      totalMembers: json['total_members'] as int? ?? 0,
      familyMembers: (json['family_members'] as List<dynamic>? ?? [])
          .map((e) => FamilyMemberModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      vehicles: (json['vehicles'] as List<dynamic>? ?? [])
          .map((e) => VehicleModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  @override
  List<Object?> get props =>
      [house, headOfFamily, totalMembers, familyMembers, vehicles];
}
