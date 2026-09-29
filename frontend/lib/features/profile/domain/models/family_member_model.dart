import 'package:equatable/equatable.dart';

class FamilyMemberModel extends Equatable {
  final int id;
  final int houseId;
  final String name;
  final String relation;
  final String? phone;
  final DateTime createdAt;

  const FamilyMemberModel({
    required this.id,
    required this.houseId,
    required this.name,
    required this.relation,
    this.phone,
    required this.createdAt,
  });

  factory FamilyMemberModel.fromJson(Map<String, dynamic> json) {
    return FamilyMemberModel(
      id: json['id'] as int,
      houseId: json['house_id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      relation: json['relation'] as String? ?? 'lainnya',
      phone: json['phone'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  String get relationDisplay {
    switch (relation.toLowerCase()) {
      case 'istri':
        return 'Istri';
      case 'suami':
        return 'Suami';
      case 'anak':
        return 'Anak';
      case 'orang_tua':
        return 'Orang Tua';
      case 'famili':
        return 'Famili';
      default:
        return 'Lainnya';
    }
  }

  @override
  List<Object?> get props => [id, houseId, name, relation, phone, createdAt];
}
