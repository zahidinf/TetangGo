import 'package:dio/dio.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/dio_client.dart';
import '../domain/models/panic_models.dart';

class PanicRepository {
  final DioClient _dioClient;

  PanicRepository(this._dioClient);

  Future<IncidentReportModel> sendEmergencyAlarm({
    required String category,
    String? title,
    String? description,
    double? latitude,
    double? longitude,
    String? locationSource,
    double? locationAccuracy,
    String? idempotencyKey,
  }) async {
    try {
      final body = <String, dynamic>{
        'category': category.toUpperCase(),
        'title': title ?? 'Laporan Darurat $category',
        'description': description?.trim().isNotEmpty == true
            ? description!.trim()
            : 'Aktivasi tombol darurat (Panic Button) oleh warga',
      };

      if (latitude != null && longitude != null) {
        body['latitude'] = latitude;
        body['longitude'] = longitude;
        body['location_source'] = locationSource ?? 'GPS';
        if (locationAccuracy != null) {
          body['location_accuracy'] = locationAccuracy;
        }
      } else {
        body['location_source'] = 'HOUSE_FALLBACK';
      }

      final options = Options();
      if (idempotencyKey != null && idempotencyKey.isNotEmpty) {
        options.headers = {
          'X-Idempotency-Key': idempotencyKey,
        };
      }

      final response = await _dioClient.dio.post(
        ApiConstants.incidents,
        data: body,
        options: options,
      );

      if (response.data is Map && response.data['success'] == true) {
        final data = response.data['data'] as Map<String, dynamic>;
        return IncidentReportModel.fromJson(data);
      }

      final msg =
          response.data?['message'] ?? 'Gagal mengirimkan laporan darurat';
      throw Exception(msg);
    } on DioException catch (e) {
      if (e.response != null && e.response?.data is Map) {
        final message = (e.response?.data as Map)['message'] as String?;
        throw Exception(message ?? 'Gagal mengirimkan laporan darurat');
      }
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        throw Exception('Koneksi timeout. Silakan periksa jaringan dan coba kembali.');
      }
      throw Exception('Tidak dapat terhubung ke server TetangGo. Silakan periksa status server.');
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }
}
