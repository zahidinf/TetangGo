class PaymentSettingModel {
  final int id;
  final String bankName;
  final String accountNumber;
  final String accountHolder;
  final double monthlyFee;

  PaymentSettingModel({
    required this.id,
    required this.bankName,
    required this.accountNumber,
    required this.accountHolder,
    required this.monthlyFee,
  });

  factory PaymentSettingModel.fromJson(Map<String, dynamic> json) {
    return PaymentSettingModel(
      id: json['id'] as int? ?? 0,
      bankName: json['bank_name'] as String? ?? '',
      accountNumber: json['account_number'] as String? ?? '',
      accountHolder: json['account_holder'] as String? ?? '',
      monthlyFee: (json['monthly_fee'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'bank_name': bankName,
      'account_number': accountNumber,
      'account_holder': accountHolder,
      'monthly_fee': monthlyFee,
    };
  }
}

class PaymentModel {
  final int id;
  final int billId;
  final String paymentMethod;
  final double amountPaid;
  final String proofImageUrl;
  final String? senderBank; // WAJIB NULLABLE
  final String? senderName; // WAJIB NULLABLE
  final String? notes; // WAJIB NULLABLE
  final String? rejectionReason; // WAJIB NULLABLE
  final String? verifiedAt; // WAJIB NULLABLE
  final int? verifiedBy; // WAJIB NULLABLE
  final String? verifiedByName;
  final int? userId;
  final DateTime? createdAt;

  PaymentModel({
    required this.id,
    required this.billId,
    this.paymentMethod = 'TRANSFER',
    required this.amountPaid,
    required this.proofImageUrl,
    this.senderBank,
    this.senderName,
    this.notes,
    this.rejectionReason,
    this.verifiedAt,
    this.verifiedBy,
    this.verifiedByName,
    this.userId,
    this.createdAt,
  });

  bool get isCash => paymentMethod.toUpperCase() == 'CASH';
  bool get isTransfer => paymentMethod.toUpperCase() == 'TRANSFER';

  DateTime? get verifiedAtDateTime =>
      verifiedAt != null ? DateTime.tryParse(verifiedAt!) : null;

  factory PaymentModel.fromJson(Map<String, dynamic> json) {
    return PaymentModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      billId: (json['bill_id'] as num?)?.toInt() ?? 0,
      paymentMethod: (json['payment_method'] as String?) ?? 'TRANSFER',
      amountPaid: (json['amount_paid'] as num?)?.toDouble() ?? 0.0,
      proofImageUrl: (json['proof_image_url'] as String?) ?? '',
      senderBank: json['sender_bank'] as String?,
      senderName: json['sender_name'] as String?,
      notes: json['notes'] as String?,
      rejectionReason: json['rejection_reason'] as String?,
      verifiedAt: json['verified_at']?.toString(),
      verifiedBy: (json['verified_by'] as num?)?.toInt(),
      verifiedByName: json['verified_by_name'] as String?,
      userId: (json['user_id'] as num?)?.toInt(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }
}

class BillModel {
  final int id;
  final int houseId;
  final String billingPeriod;
  final double amount;
  final String status; // 'unpaid', 'pending_verification', 'paid', 'rejected'
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? block;
  final String? houseNumber;
  final PaymentModel? payment;

  BillModel({
    required this.id,
    required this.houseId,
    required this.billingPeriod,
    required this.amount,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.block,
    this.houseNumber,
    this.payment,
  });

  bool get isPaid => status == 'paid';
  bool get isPending => status == 'pending_verification';
  bool get isRejected => status == 'rejected';
  bool get isUnpaid => status == 'unpaid';

  factory BillModel.fromJson(Map<String, dynamic> json) {
    String? b;
    String? hn;
    if (json['house'] is Map<String, dynamic>) {
      b = json['house']['block'] as String?;
      hn = json['house']['house_number'] as String?;
    }

    return BillModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      houseId: (json['house_id'] as num?)?.toInt() ?? 0,
      billingPeriod: json['billing_period'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] as String? ?? 'unpaid',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      block: b,
      houseNumber: hn,
      payment: json['payment'] is Map<String, dynamic>
          ? PaymentModel.fromJson(json['payment'] as Map<String, dynamic>)
          : null,
    );
  }
}

class PendingPaymentModel {
  final int billId;
  final int paymentId;
  final int houseId;
  final String paymentMethod;
  final String houseBlock;
  final String houseNumber;
  final String residentName;
  final String residentPhone;
  final String billingPeriod;
  final double billAmount;
  final double amountPaid;
  final String? senderBank;
  final String? senderName;
  final String proofImageUrl;
  final String? notes;
  final DateTime createdAt;

  PendingPaymentModel({
    required this.billId,
    required this.paymentId,
    required this.houseId,
    this.paymentMethod = 'TRANSFER',
    required this.houseBlock,
    required this.houseNumber,
    required this.residentName,
    required this.residentPhone,
    required this.billingPeriod,
    required this.billAmount,
    required this.amountPaid,
    this.senderBank,
    this.senderName,
    required this.proofImageUrl,
    this.notes,
    required this.createdAt,
  });

  bool get isCash => paymentMethod.toUpperCase() == 'CASH';

  factory PendingPaymentModel.fromJson(Map<String, dynamic> json) {
    return PendingPaymentModel(
      billId: (json['bill_id'] as num?)?.toInt() ?? 0,
      paymentId: (json['payment_id'] as num?)?.toInt() ?? 0,
      houseId: (json['house_id'] as num?)?.toInt() ?? 0,
      paymentMethod: (json['payment_method'] as String?) ?? 'TRANSFER',
      houseBlock: json['house_block'] as String? ?? '',
      houseNumber: json['house_number'] as String? ?? '',
      residentName: json['resident_name'] as String? ?? '',
      residentPhone: json['resident_phone'] as String? ?? '',
      billingPeriod: json['billing_period'] as String? ?? '',
      billAmount: (json['bill_amount'] as num?)?.toDouble() ?? 0.0,
      amountPaid: (json['amount_paid'] as num?)?.toDouble() ?? 0.0,
      senderBank: json['sender_bank'] as String?,
      senderName: json['sender_name'] as String?,
      proofImageUrl: json['proof_image_url'] as String? ?? '',
      notes: json['notes'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

class HouseBillStatusModel {
  final int houseId;
  final String block;
  final String houseNumber;
  final String residentName;
  final String residentPhone;
  final String status;
  final int? billId;
  final double amount;
  final DateTime? paidAt;
  final String? proofImageUrl;

  HouseBillStatusModel({
    required this.houseId,
    required this.block,
    required this.houseNumber,
    required this.residentName,
    required this.residentPhone,
    required this.status,
    this.billId,
    required this.amount,
    this.paidAt,
    this.proofImageUrl,
  });

  factory HouseBillStatusModel.fromJson(Map<String, dynamic> json) {
    return HouseBillStatusModel(
      houseId: json['house_id'] as int? ?? 0,
      block: json['block'] as String? ?? '',
      houseNumber: json['house_number'] as String? ?? '',
      residentName: json['resident_name'] as String? ?? '',
      residentPhone: json['resident_phone'] as String? ?? '',
      status: json['status'] as String? ?? 'unpaid',
      billId: json['bill_id'] as int?,
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      paidAt:
          json['paid_at'] != null ? DateTime.tryParse(json['paid_at']) : null,
      proofImageUrl: json['proof_image_url'] as String?,
    );
  }
}

class BillingSummaryModel {
  final String period;
  final String? block;
  final bool isPeriodGenerated;
  final int totalHouses;
  final int paidHouses;
  final int unpaidHouses;
  final double totalPaidAmount;
  final double totalUnpaidAmount;
  final List<HouseBillStatusModel> houseBills;

  BillingSummaryModel({
    required this.period,
    this.block,
    this.isPeriodGenerated = true,
    required this.totalHouses,
    required this.paidHouses,
    required this.unpaidHouses,
    required this.totalPaidAmount,
    required this.totalUnpaidAmount,
    required this.houseBills,
  });

  int get totalPaidHouses => paidHouses;
  int get totalUnpaidHouses => unpaidHouses;
  List<HouseBillStatusModel> get items => houseBills;

  factory BillingSummaryModel.fromJson(Map<String, dynamic> json) {
    final list = (json['house_bills'] ?? json['items']) as List<dynamic>?;
    return BillingSummaryModel(
      period: json['period'] as String? ?? '',
      block: json['block'] as String?,
      isPeriodGenerated: json['is_period_generated'] as bool? ?? true,
      totalHouses: (json['total_houses'] as num?)?.toInt() ?? 0,
      paidHouses: ((json['paid_houses'] ?? json['total_paid_houses']) as num?)
              ?.toInt() ??
          0,
      unpaidHouses:
          ((json['unpaid_houses'] ?? json['total_unpaid_houses']) as num?)
                  ?.toInt() ??
              0,
      totalPaidAmount: (json['total_paid_amount'] as num?)?.toDouble() ?? 0.0,
      totalUnpaidAmount:
          (json['total_unpaid_amount'] as num?)?.toDouble() ?? 0.0,
      houseBills: list
              ?.map((e) =>
                  HouseBillStatusModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class BulkProcessItemResultModel {
  final int billId;
  final int houseId;
  final String houseBlock;
  final String houseNumber;
  final String residentName;
  final bool success;
  final String status;
  final String message;
  final double amount;

  BulkProcessItemResultModel({
    required this.billId,
    required this.houseId,
    required this.houseBlock,
    required this.houseNumber,
    required this.residentName,
    required this.success,
    required this.status,
    required this.message,
    required this.amount,
  });

  factory BulkProcessItemResultModel.fromJson(Map<String, dynamic> json) {
    return BulkProcessItemResultModel(
      billId: (json['bill_id'] as num?)?.toInt() ?? 0,
      houseId: (json['house_id'] as num?)?.toInt() ?? 0,
      houseBlock: json['house_block'] as String? ?? '',
      houseNumber: json['house_number'] as String? ?? '',
      residentName: json['resident_name'] as String? ?? '',
      success: json['success'] as bool? ?? false,
      status: json['status'] as String? ?? '',
      message: json['message'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class BulkProcessResultModel {
  final String period;
  final String paymentMethod;
  final int totalProcessed;
  final int successCount;
  final int failedCount;
  final List<BulkProcessItemResultModel> results;

  BulkProcessResultModel({
    required this.period,
    required this.paymentMethod,
    required this.totalProcessed,
    required this.successCount,
    required this.failedCount,
    required this.results,
  });

  factory BulkProcessResultModel.fromJson(Map<String, dynamic> json) {
    final list = json['results'] as List<dynamic>?;
    return BulkProcessResultModel(
      period: json['period'] as String? ?? '',
      paymentMethod: json['payment_method'] as String? ?? '',
      totalProcessed: (json['total_processed'] as num?)?.toInt() ?? 0,
      successCount: (json['success_count'] as num?)?.toInt() ?? 0,
      failedCount: (json['failed_count'] as num?)?.toInt() ?? 0,
      results: list
              ?.map((e) => BulkProcessItemResultModel.fromJson(
                  e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

typedef BillSummaryModel = BillingSummaryModel;

class EligibleDuesPeriodModel {
  final int billId;
  final String billingPeriod;
  final double amount;
  final String status;
  final bool isEligible;

  EligibleDuesPeriodModel({
    required this.billId,
    required this.billingPeriod,
    required this.amount,
    required this.status,
    bool? isEligible,
  }) : isEligible = isEligible ?? (status == 'unpaid' || status == 'rejected');

  bool get isPaid => status == 'paid';
  bool get isPending => status == 'pending_verification';

  factory EligibleDuesPeriodModel.fromJson(Map<String, dynamic> json) {
    final s = json['status'] as String? ?? 'unpaid';
    return EligibleDuesPeriodModel(
      billId: (json['bill_id'] as num?)?.toInt() ?? 0,
      billingPeriod: json['billing_period'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      status: s,
      isEligible:
          json['is_eligible'] as bool? ?? (s == 'unpaid' || s == 'rejected'),
    );
  }
}

class ResidentBillingOptionModel {
  final int residentId;
  final String residentName;
  final String residentPhone;
  final int houseId;
  final String houseBlock;
  final String houseNumber;

  ResidentBillingOptionModel({
    required this.residentId,
    required this.residentName,
    required this.residentPhone,
    required this.houseId,
    required this.houseBlock,
    required this.houseNumber,
  });

  String get occupancyIdentifier {
    final cleanBlock = houseBlock.trim();
    if (cleanBlock.isEmpty && houseNumber.isEmpty) return '';
    final blockDisplay = cleanBlock.toLowerCase().startsWith('blok')
        ? cleanBlock
        : 'Blok $cleanBlock';
    return houseNumber.isNotEmpty ? '$blockDisplay/$houseNumber' : blockDisplay;
  }

  String get displayName {
    final occ = occupancyIdentifier;
    return occ.isNotEmpty ? '$residentName ($occ)' : residentName;
  }

  factory ResidentBillingOptionModel.fromJson(Map<String, dynamic> json) {
    return ResidentBillingOptionModel(
      residentId:
          (json['resident_id'] ?? json['user_id'] as num?)?.toInt() ?? 0,
      residentName: (json['resident_name'] ?? json['name'] as String?) ?? '',
      residentPhone: (json['resident_phone'] ?? json['phone'] as String?) ?? '',
      houseId: (json['house_id'] as num?)?.toInt() ?? 0,
      houseBlock: (json['house_block'] as String?) ?? '',
      houseNumber: (json['house_number'] as String?) ?? '',
    );
  }
}
