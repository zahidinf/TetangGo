class DashboardRecentActivityModel {
  final int id;
  final String residentName;
  final String block;
  final String houseNumber;
  final double amountPaid;
  final String status;
  final DateTime createdAt;

  const DashboardRecentActivityModel({
    required this.id,
    required this.residentName,
    required this.block,
    required this.houseNumber,
    required this.amountPaid,
    required this.status,
    required this.createdAt,
  });

  factory DashboardRecentActivityModel.fromJson(Map<String, dynamic> json) {
    return DashboardRecentActivityModel(
      id: json['id'] as int? ?? 0,
      residentName: json['resident_name'] as String? ?? 'Warga',
      block: json['block'] as String? ?? '',
      houseNumber: json['house_number'] as String? ?? '',
      amountPaid: (json['amount_paid'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] as String? ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

class DashboardStatsModel {
  final int totalHouses;
  final int occupiedHouses;
  final int emptyHouses;
  final int totalResidents;
  final int pendingResidents;
  final String currentPeriod;
  final double collectedAmount;
  final double targetAmount;
  final int pendingPaymentsCount;
  final List<DashboardRecentActivityModel> recentActivities;

  const DashboardStatsModel({
    required this.totalHouses,
    required this.occupiedHouses,
    required this.emptyHouses,
    required this.totalResidents,
    required this.pendingResidents,
    required this.currentPeriod,
    required this.collectedAmount,
    required this.targetAmount,
    required this.pendingPaymentsCount,
    required this.recentActivities,
  });

  factory DashboardStatsModel.fromJson(Map<String, dynamic> json) {
    return DashboardStatsModel(
      totalHouses: json['total_houses'] as int? ?? 0,
      occupiedHouses: json['occupied_houses'] as int? ?? 0,
      emptyHouses: json['empty_houses'] as int? ?? 0,
      totalResidents: json['total_residents'] as int? ?? 0,
      pendingResidents: json['pending_residents'] as int? ?? 0,
      currentPeriod: json['current_period'] as String? ?? '',
      collectedAmount: (json['collected_amount'] as num?)?.toDouble() ?? 0.0,
      targetAmount: (json['target_amount'] as num?)?.toDouble() ?? 0.0,
      pendingPaymentsCount: json['pending_payments_count'] as int? ?? 0,
      recentActivities: (json['recent_activities'] as List<dynamic>?)
              ?.map((e) => DashboardRecentActivityModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}
