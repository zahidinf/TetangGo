import 'package:dio/dio.dart';
import '../../../../core/constants/api_constants.dart';
import '../domain/models/dashboard_stats_model.dart';

class DashboardRepository {
  final Dio _dio;

  DashboardRepository({required Dio dio}) : _dio = dio;

  Future<DashboardStatsModel> getAdminDashboardStats({String? period}) async {
    try {
      final Map<String, dynamic> query = {};
      if (period != null && period.isNotEmpty) {
        query['period'] = period;
      }

      final response = await _dio.get(
        ApiConstants.adminDashboardStats,
        queryParameters: query,
      );

      if (response.data['success'] == true) {
        return DashboardStatsModel.fromJson(response.data['data']);
      }
      throw Exception(response.data['message'] ?? 'Gagal memuat statistik dashboard');
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ?? e.message ?? 'Gagal memuat statistik dashboard';
      throw Exception(msg);
    }
  }
}
