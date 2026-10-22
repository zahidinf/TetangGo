import 'package:dio/dio.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/dio_client.dart';
import '../domain/models/cashbook_models.dart';

class CashbookRepository {
  final DioClient _dioClient;

  CashbookRepository(this._dioClient);

  Future<CashbookSummaryModel> getCashbookSummary() async {
    try {
      final response = await _dioClient.dio.get(ApiConstants.cashbookSummary);
      if (response.data['success'] == true) {
        return CashbookSummaryModel.fromJson(response.data['data']);
      }
      throw Exception(response.data['message'] ?? 'Gagal memuat ringkasan kas');
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ?? e.message ?? 'Gagal memuat ringkasan kas';
      throw Exception(msg);
    }
  }

  Future<List<CashTransactionModel>> getCashbookTransactions({
    String? type,
    String? category,
    String? startDate,
    String? endDate,
    int page = 1,
    int limit = 100,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'page': page,
        'limit': limit,
      };
      if (type != null && type.isNotEmpty && type != 'all') {
        queryParams['type'] = type;
      }
      if (category != null && category.isNotEmpty && category != 'all') {
        queryParams['category'] = category;
      }
      if (startDate != null && startDate.isNotEmpty) {
        queryParams['start_date'] = startDate;
      }
      if (endDate != null && endDate.isNotEmpty) {
        queryParams['end_date'] = endDate;
      }

      final response = await _dioClient.dio.get(
        ApiConstants.cashbookTransactions,
        queryParameters: queryParams,
      );

      if (response.data['success'] == true) {
        final list = (response.data['data'] as List<dynamic>?)
                ?.map((e) => CashTransactionModel.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [];
        return list;
      }
      throw Exception(response.data['message'] ?? 'Gagal memuat mutasi kas');
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ?? e.message ?? 'Gagal memuat mutasi kas';
      throw Exception(msg);
    }
  }

  Future<CashTransactionModel> createManualTransaction({
    required String type,
    required String category,
    required double amount,
    required String transactionDate,
    required String description,
    List<int>? imageBytes,
    String? fileName,
  }) async {
    try {
      final mapData = <String, dynamic>{
        'type': type,
        'category': category,
        'amount': amount.toString(),
        'transaction_date': transactionDate,
        'description': description,
      };

      if (imageBytes != null && imageBytes.isNotEmpty && fileName != null) {
        mapData['proof_image'] = MultipartFile.fromBytes(
          imageBytes,
          filename: fileName,
        );
      }

      final formData = FormData.fromMap(mapData);

      final response = await _dioClient.dio.post(
        ApiConstants.adminCashbookTransactions,
        data: formData,
      );

      if (response.data['success'] == true) {
        return CashTransactionModel.fromJson(response.data['data']);
      }
      throw Exception(response.data['message'] ?? 'Gagal mencatat transaksi kas');
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ?? e.message ?? 'Gagal mencatat transaksi kas';
      throw Exception(msg);
    }
  }

  Future<void> deleteManualTransaction(int id) async {
    try {
      final response = await _dioClient.dio.delete(
        ApiConstants.adminDeleteCashbookTransaction(id),
      );
      if (response.data['success'] != true) {
        throw Exception(response.data['message'] ?? 'Gagal menghapus transaksi');
      }
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ?? e.message ?? 'Gagal menghapus transaksi';
      throw Exception(msg);
    }
  }
}
