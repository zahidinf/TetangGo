import 'package:equatable/equatable.dart';
import '../../../auth/domain/models/user_model.dart';
import '../../../resident_management/domain/models/house_model.dart';
import 'family_member_model.dart';
import 'vehicle_model.dart';

class ProfileDetailModel extends Equatable {
  final UserModel user;
  final HouseModel? house;
  final List<FamilyMemberModel> familyMembers;
  final List<VehicleModel> vehicles;

  const ProfileDetailModel({
    required this.user,
    this.house,
    this.familyMembers = const [],
    this.vehicles = const [],
  });

  factory ProfileDetailModel.fromJson(Map<String, dynamic> json) {
    final userJson = json['user'] as Map<String, dynamic>? ?? {};
    final houseJson = json['house'] as Map<String, dynamic>?;

    final familyList = (json['family_members'] as List<dynamic>? ?? [])
        .map((e) => FamilyMemberModel.fromJson(e as Map<String, dynamic>))
        .toList();

    final vehicleList = (json['vehicles'] as List<dynamic>? ?? [])
        .map((e) => VehicleModel.fromJson(e as Map<String, dynamic>))
        .toList();

    return ProfileDetailModel(
      user: UserModel.fromJson(userJson),
      house: houseJson != null ? HouseModel.fromJson(houseJson) : null,
      familyMembers: familyList,
      vehicles: vehicleList,
    );
  }

  @override
  List<Object?> get props => [user, house, familyMembers, vehicles];
}
