import 'package:dio/dio.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/dio_client.dart';
import '../domain/models/billing_models.dart';

class BillingRepository {
  final DioClient _dioClient;

  BillingRepository(this._dioClient);

  Future<PaymentSettingModel> getPaymentSettings() async {
    try {
      final response = await _dioClient.dio.get(ApiConstants.paymentSettings);
      if (response.data['success'] == true) {
        return PaymentSettingModel.fromJson(response.data['data']);
      }
      throw Exception(
          response.data['message'] ?? 'Gagal memuat pengaturan pembayaran');
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ??
          e.message ??
          'Gagal memuat pengaturan pembayaran';
      throw Exception(msg);
    }
  }

  Future<PaymentSettingModel> updatePaymentSettings({
    required String bankName,
    required String accountNumber,
    required String accountHolder,
    required double monthlyFee,
  }) async {
    try {
      final response = await _dioClient.dio.put(
        ApiConstants.adminPaymentSettings,
        data: {
          'bank_name': bankName,
          'account_number': accountNumber,
          'account_holder': accountHolder,
          'monthly_fee': monthlyFee,
        },
      );
      if (response.data['success'] == true) {
        return PaymentSettingModel.fromJson(response.data['data']);
      }
      throw Exception(response.data['message'] ??
          'Gagal memperbarui pengaturan pembayaran');
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ??
          e.message ??
          'Gagal memperbarui pengaturan pembayaran';
      throw Exception(msg);
    }
  }

  Future<int> generateMonthlyBills(String period) async {
    try {
      final response = await _dioClient.dio.post(
        ApiConstants.adminGenerateBills,
        data: {'period': period},
      );
      if (response.data['success'] == true) {
        return response.data['data']?['generated_count'] ?? 0;
      }
      throw Exception(response.data['message'] ?? 'Gagal menerbitkan tagihan');
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ??
          e.message ??
          'Gagal menerbitkan tagihan';
      throw Exception(msg);
    }
  }

  Future<void> generateIndividualBill(int houseId, String period) async {
    try {
      final response = await _dioClient.dio.post(
        ApiConstants.adminGenerateBills,
        data: {
          'house_id': houseId,
          'period': period,
        },
      );
      if (response.data['success'] == true) {
        return;
      }
      throw Exception(
          response.data['message'] ?? 'Gagal menerbitkan tagihan individual');
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ??
          e.message ??
          'Gagal menerbitkan tagihan individual';
      throw Exception(msg);
    }
  }

  Future<List<BillModel>> getResidentBills({String? period}) async {
    try {
      final Map<String, dynamic> query = {};
      if (period != null && period.isNotEmpty && period != 'all') {
        query['period'] = period;
      }
      final response = await _dioClient.dio.get(
        ApiConstants.residentBills,
        queryParameters: query.isNotEmpty ? query : null,
      );
      if (response.data['success'] == true) {
        final List list = response.data['data'] ?? [];
        return list
            .map((e) => BillModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      throw Exception(
          response.data['message'] ?? 'Gagal memuat daftar tagihan');
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ??
          e.message ??
          'Gagal memuat daftar tagihan';
      throw Exception(msg);
    }
  }

  Future<BillModel> initiateResidentBill(String period) async {
    try {
      final response = await _dioClient.dio.post(
        ApiConstants.residentInitiateBill,
        data: {'period': period},
      );
      if (response.data['success'] == true) {
        return BillModel.fromJson(response.data['data']);
      }
      throw Exception(response.data['message'] ??
          'Gagal menginisiasi tagihan periode $period');
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ??
          e.message ??
          'Gagal menginisiasi tagihan periode $period';
      throw Exception(msg);
    }
  }

  Future<BillModel> getResidentBillDetail(int id) async {
    try {
      final response =
          await _dioClient.dio.get(ApiConstants.residentBillDetail(id));
      if (response.data['success'] == true) {
        return BillModel.fromJson(response.data['data']);
      }
      throw Exception(
          response.data['message'] ?? 'Gagal memuat detail tagihan');
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ??
          e.message ??
          'Gagal memuat detail tagihan';
      throw Exception(msg);
    }
  }

  Future<void> submitPayment({
    required int billId,
    String paymentMethod = 'TRANSFER',
    String? senderBank,
    String? senderName,
    required double amount,
    String? notes,
    List<int>? imageBytes,
    String? fileName,
  }) async {
    try {
      final Map<String, dynamic> formMap = {
        'payment_method': paymentMethod,
        'amount': amount.toString(),
        'notes': notes ?? '',
      };
      if (senderBank != null && senderBank.isNotEmpty) {
        formMap['sender_bank'] = senderBank;
      }
      if (senderName != null && senderName.isNotEmpty) {
        formMap['sender_name'] = senderName;
      }
      if (imageBytes != null && imageBytes.isNotEmpty && fileName != null) {
        formMap['proof_image'] = MultipartFile.fromBytes(
          imageBytes,
          filename: fileName,
        );
      }

      final formData = FormData.fromMap(formMap);

      final response = await _dioClient.dio.post(
        ApiConstants.residentPayBill(billId),
        data: formData,
      );

      if (response.data['success'] != true) {
        throw Exception(
            response.data['message'] ?? 'Gagal mengirim pembayaran');
      }
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ??
          e.message ??
          'Gagal mengirim pembayaran';
      throw Exception(msg);
    }
  }

  Future<List<ResidentBillingOptionModel>> getEligibleResidents() async {
    try {
      final response =
          await _dioClient.dio.get(ApiConstants.adminEligibleResidents);
      if (response.data['success'] == true) {
        final List list = response.data['data'] ?? [];
        return list
            .map((e) =>
                ResidentBillingOptionModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      throw Exception(response.data['message'] ?? 'Gagal memuat daftar warga');
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ??
          e.message ??
          'Gagal memuat daftar warga';
      throw Exception(msg);
    }
  }

  Future<List<EligibleDuesPeriodModel>> getResidentEligiblePeriods(
      int residentId) async {
    try {
      final response = await _dioClient.dio.get(
        ApiConstants.adminResidentPeriods,
        queryParameters: {'resident_id': residentId},
      );
      if (response.data['success'] == true) {
        final List list = response.data['data'] ?? [];
        return list
            .map((e) =>
                EligibleDuesPeriodModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      throw Exception(
          response.data['message'] ?? 'Gagal memuat periode iuran warga');
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ??
          e.message ??
          'Gagal memuat periode iuran warga';
      throw Exception(msg);
    }
  }

  Future<PaymentModel> recordDirectCashPayment({
    required int residentId,
    required int billId,
    required double amount,
    DateTime? paymentDate,
    String? notes,
  }) async {
    try {
      final response = await _dioClient.dio.post(
        ApiConstants.adminRecordCash,
        data: {
          'resident_id': residentId,
          'bill_id': billId,
          'amount': amount,
          if (paymentDate != null)
            'payment_date': paymentDate.toUtc().toIso8601String(),
          if (notes != null && notes.isNotEmpty) 'notes': notes,
        },
      );

      if (response.data['success'] == true) {
        return PaymentModel.fromJson(
            response.data['data'] as Map<String, dynamic>);
      }
      throw Exception(
          response.data['message'] ?? 'Gagal mencatat pembayaran tunai');
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ??
          e.message ??
          'Gagal mencatat pembayaran tunai';
      throw Exception(msg);
    }
  }

  Future<List<PendingPaymentModel>> getPendingPayments() async {
    try {
      final response = await _dioClient.dio.get(ApiConstants.adminPendingBills);
      if (response.data['success'] == true) {
        final List list = response.data['data'] ?? [];
        return list
            .map((e) => PendingPaymentModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      throw Exception(
          response.data['message'] ?? 'Gagal memuat antrean pembayaran');
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ??
          e.message ??
          'Gagal memuat antrean pembayaran';
      throw Exception(msg);
    }
  }

  Future<void> verifyPayment({
    required int billId,
    required String action, // 'approve' | 'reject'
    String? rejectionReason,
  }) async {
    try {
      final response = await _dioClient.dio.post(
        ApiConstants.adminVerifyBill(billId),
        data: {
          'action': action,
          if (rejectionReason != null && rejectionReason.isNotEmpty)
            'rejection_reason': rejectionReason,
        },
      );
      if (response.data['success'] != true) {
        throw Exception(
            response.data['message'] ?? 'Gagal memverifikasi pembayaran');
      }
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ??
          e.message ??
          'Gagal memverifikasi pembayaran';
      throw Exception(msg);
    }
  }

  Future<List<String>> getHouseBlocks() async {
    try {
      final response = await _dioClient.dio.get(ApiConstants.houseBlocks);
      if (response.data['success'] == true) {
        final List list = response.data['data'] ?? [];
        return list.map((e) => e.toString()).toList();
      }
      throw Exception(response.data['message'] ?? 'Gagal memuat daftar blok');
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ??
          e.message ??
          'Gagal memuat daftar blok';
      throw Exception(msg);
    }
  }

  Future<BillingSummaryModel> getBillingSummary(
      {String? period, String? block}) async {
    try {
      final Map<String, dynamic> query = {};
      if (period != null && period.isNotEmpty) query['period'] = period;
      if (block != null && block.isNotEmpty && block != 'Semua')
        query['block'] = block;

      final response = await _dioClient.dio.get(
        ApiConstants.adminBillsSummary,
        queryParameters: query,
      );
      if (response.data['success'] == true) {
        return BillingSummaryModel.fromJson(response.data['data']);
      }
      throw Exception(
          response.data['message'] ?? 'Gagal memuat rekapitulasi iuran');
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ??
          e.message ??
          'Gagal memuat rekapitulasi iuran';
      throw Exception(msg);
    }
  }

  Future<BulkProcessResultModel> bulkProcessPayments({
    required String period,
    required String paymentMethod,
    required List<int> billIds,
    String? notes,
  }) async {
    try {
      final response = await _dioClient.dio.post(
        ApiConstants.adminBulkPay,
        data: {
          'period': period,
          'payment_method': paymentMethod,
          'bill_ids': billIds,
          if (notes != null && notes.isNotEmpty) 'notes': notes,
        },
      );
      if (response.data['success'] == true) {
        return BulkProcessResultModel.fromJson(
            response.data['data'] as Map<String, dynamic>);
      }
      throw Exception(
          response.data['message'] ?? 'Gagal memproses pembayaran massal');
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ??
          e.message ??
          'Gagal memproses pembayaran massal';
      throw Exception(msg);
    }
  }
}
