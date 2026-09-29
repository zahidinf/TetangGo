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
      throw Exception(response.data['message'] ?? 'Gagal memuat pengaturan pembayaran');
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ?? e.message ?? 'Gagal memuat pengaturan pembayaran';
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
      throw Exception(response.data['message'] ?? 'Gagal memperbarui pengaturan pembayaran');
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ?? e.message ?? 'Gagal memperbarui pengaturan pembayaran';
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
      final msg = e.response?.data?['message'] ?? e.message ?? 'Gagal menerbitkan tagihan';
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
        return list.map((e) => BillModel.fromJson(e as Map<String, dynamic>)).toList();
      }
      throw Exception(response.data['message'] ?? 'Gagal memuat daftar tagihan');
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ?? e.message ?? 'Gagal memuat daftar tagihan';
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
      throw Exception(response.data['message'] ?? 'Gagal menginisiasi tagihan periode $period');
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ?? e.message ?? 'Gagal menginisiasi tagihan periode $period';
      throw Exception(msg);
    }
  }

  Future<BillModel> getResidentBillDetail(int id) async {
    try {
      final response = await _dioClient.dio.get(ApiConstants.residentBillDetail(id));
      if (response.data['success'] == true) {
        return BillModel.fromJson(response.data['data']);
      }
      throw Exception(response.data['message'] ?? 'Gagal memuat detail tagihan');
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ?? e.message ?? 'Gagal memuat detail tagihan';
      throw Exception(msg);
    }
  }

  Future<void> submitPayment({
    required int billId,
    required String senderBank,
    required String senderName,
    required double amount,
    String? notes,
    required List<int> imageBytes,
    required String fileName,
  }) async {
    try {
      final formData = FormData.fromMap({
        'sender_bank': senderBank,
        'sender_name': senderName,
        'amount': amount.toString(),
        'notes': notes ?? '',
        'proof_image': MultipartFile.fromBytes(
          imageBytes,
          filename: fileName,
        ),
      });

      final response = await _dioClient.dio.post(
        ApiConstants.residentPayBill(billId),
        data: formData,
      );

      if (response.data['success'] != true) {
        throw Exception(response.data['message'] ?? 'Gagal mengirim bukti pembayaran');
      }
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ?? e.message ?? 'Gagal mengirim bukti pembayaran';
      throw Exception(msg);
    }
  }

  Future<List<PendingPaymentModel>> getPendingPayments() async {
    try {
      final response = await _dioClient.dio.get(ApiConstants.adminPendingBills);
      if (response.data['success'] == true) {
        final List list = response.data['data'] ?? [];
        return list.map((e) => PendingPaymentModel.fromJson(e as Map<String, dynamic>)).toList();
      }
      throw Exception(response.data['message'] ?? 'Gagal memuat antrean pembayaran');
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ?? e.message ?? 'Gagal memuat antrean pembayaran';
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
        throw Exception(response.data['message'] ?? 'Gagal memverifikasi pembayaran');
      }
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ?? e.message ?? 'Gagal memverifikasi pembayaran';
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
      final msg = e.response?.data?['message'] ?? e.message ?? 'Gagal memuat daftar blok';
      throw Exception(msg);
    }
  }

  Future<BillingSummaryModel> getBillingSummary({String? period, String? block}) async {
    try {
      final Map<String, dynamic> query = {};
      if (period != null && period.isNotEmpty) query['period'] = period;
      if (block != null && block.isNotEmpty && block != 'Semua') query['block'] = block;

      final response = await _dioClient.dio.get(
        ApiConstants.adminBillsSummary,
        queryParameters: query,
      );
      if (response.data['success'] == true) {
        return BillingSummaryModel.fromJson(response.data['data']);
      }
      throw Exception(response.data['message'] ?? 'Gagal memuat rekapitulasi iuran');
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ?? e.message ?? 'Gagal memuat rekapitulasi iuran';
      throw Exception(msg);
    }
  }
}
