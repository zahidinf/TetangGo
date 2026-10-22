class MonthlyCashFlowModel {
  final String month;
  final double income;
  final double expense;

  MonthlyCashFlowModel({
    required this.month,
    required this.income,
    required this.expense,
  });

  factory MonthlyCashFlowModel.fromJson(Map<String, dynamic> json) {
    return MonthlyCashFlowModel(
      month: json['month'] ?? '',
      income: (json['income'] as num?)?.toDouble() ?? 0.0,
      expense: (json['expense'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class CashbookSummaryModel {
  final double currentBalance;
  final double totalIncome;
  final double totalExpense;
  final List<MonthlyCashFlowModel> monthlySummary;

  CashbookSummaryModel({
    required this.currentBalance,
    required this.totalIncome,
    required this.totalExpense,
    required this.monthlySummary,
  });

  factory CashbookSummaryModel.fromJson(Map<String, dynamic> json) {
    final list = (json['monthly_summary'] as List<dynamic>?)
            ?.map((e) => MonthlyCashFlowModel.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];

    return CashbookSummaryModel(
      currentBalance: (json['current_balance'] as num?)?.toDouble() ?? 0.0,
      totalIncome: (json['total_income'] as num?)?.toDouble() ?? 0.0,
      totalExpense: (json['total_expense'] as num?)?.toDouble() ?? 0.0,
      monthlySummary: list,
    );
  }
}

class CashTransactionModel {
  final int id;
  final String type; // 'income' or 'expense'
  final String category;
  final double amount;
  final String transactionDate;
  final String description;
  final String? proofImageUrl;
  final int? billId;
  final int? createdBy;
  final String creatorName;
  final DateTime createdAt;

  CashTransactionModel({
    required this.id,
    required this.type,
    required this.category,
    required this.amount,
    required this.transactionDate,
    required this.description,
    this.proofImageUrl,
    this.billId,
    this.createdBy,
    required this.creatorName,
    required this.createdAt,
  });

  bool get isIncome => type == 'income';
  bool get isExpense => type == 'expense';
  bool get isFromBill => billId != null;

  String get categoryDisplay {
    switch (category) {
      case 'iuran':
        return 'Iuran Bulanan';
      case 'donasi':
        return 'Donasi Warga';
      case 'kebersihan':
        return 'Kebersihan & Sampah';
      case 'keamanan':
        return 'Keamanan & Ronda';
      case 'perbaikan_fasilitas':
        return 'Perbaikan Fasilitas';
      case 'kegiatan_sosial':
        return 'Kegiatan Sosial / Warga';
      case 'operasional':
        return 'Operasional RT';
      default:
        return category.replaceAll('_', ' ').toUpperCase();
    }
  }

  factory CashTransactionModel.fromJson(Map<String, dynamic> json) {
    return CashTransactionModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      type: json['type'] ?? 'income',
      category: json['category'] ?? 'lainnya',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      transactionDate: json['transaction_date'] ?? '',
      description: json['description'] ?? '',
      proofImageUrl: json['proof_image_url'],
      billId: json['bill_id'] is int ? json['bill_id'] : int.tryParse(json['bill_id']?.toString() ?? ''),
      createdBy: json['created_by'] is int ? json['created_by'] : int.tryParse(json['created_by']?.toString() ?? ''),
      creatorName: json['creator_name'] ?? 'Admin RT',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
