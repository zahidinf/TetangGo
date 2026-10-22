import 'package:dio/dio.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/dio_client.dart';
import '../domain/models/announcement_model.dart';

class AnnouncementsRepository {
  final DioClient _dioClient;

  AnnouncementsRepository(this._dioClient);

  Future<List<AnnouncementModel>> getAnnouncements({
    String? category,
    String? search,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (category != null && category.isNotEmpty && category != 'all') {
        queryParams['category'] = category;
      }
      if (search != null && search.isNotEmpty) {
        queryParams['search'] = search;
      }

      final response = await _dioClient.dio.get(
        ApiConstants.announcements,
        queryParameters: queryParams,
      );

      if (response.data['success'] == true) {
        final list = (response.data['data'] as List<dynamic>?)
                ?.map((e) => AnnouncementModel.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [];
        return list;
      }
      throw Exception(response.data['message'] ?? 'Gagal memuat daftar pengumuman');
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ?? e.message ?? 'Gagal memuat daftar pengumuman';
      throw Exception(msg);
    }
  }

  Future<AnnouncementModel> getAnnouncementDetail(int id) async {
    try {
      final response = await _dioClient.dio.get(ApiConstants.announcementDetail(id));
      if (response.data['success'] == true) {
        return AnnouncementModel.fromJson(response.data['data']);
      }
      throw Exception(response.data['message'] ?? 'Gagal memuat detail pengumuman');
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ?? e.message ?? 'Gagal memuat detail pengumuman';
      throw Exception(msg);
    }
  }

  Future<AnnouncementModel> createAnnouncement({
    required String title,
    required String content,
    required String category,
    required bool isPinned,
    List<int>? imageBytes,
    String? fileName,
  }) async {
    try {
      final mapData = <String, dynamic>{
        'title': title,
        'content': content,
        'category': category,
        'is_pinned': isPinned ? 'true' : 'false',
      };

      if (imageBytes != null && imageBytes.isNotEmpty && fileName != null) {
        mapData['image'] = MultipartFile.fromBytes(
          imageBytes,
          filename: fileName,
        );
      }

      final formData = FormData.fromMap(mapData);

      final response = await _dioClient.dio.post(
        ApiConstants.adminAnnouncements,
        data: formData,
      );

      if (response.data['success'] == true) {
        return AnnouncementModel.fromJson(response.data['data']);
      }
      throw Exception(response.data['message'] ?? 'Gagal membuat pengumuman');
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ?? e.message ?? 'Gagal membuat pengumuman';
      throw Exception(msg);
    }
  }

  Future<AnnouncementModel> updateAnnouncement({
    required int id,
    required String title,
    required String content,
    required String category,
    required bool isPinned,
    List<int>? imageBytes,
    String? fileName,
  }) async {
    try {
      final mapData = <String, dynamic>{
        'title': title,
        'content': content,
        'category': category,
        'is_pinned': isPinned ? 'true' : 'false',
      };

      if (imageBytes != null && imageBytes.isNotEmpty && fileName != null) {
        mapData['image'] = MultipartFile.fromBytes(
          imageBytes,
          filename: fileName,
        );
      }

      final formData = FormData.fromMap(mapData);

      final response = await _dioClient.dio.put(
        ApiConstants.adminAnnouncementDetail(id),
        data: formData,
      );

      if (response.data['success'] == true) {
        return AnnouncementModel.fromJson(response.data['data']);
      }
      throw Exception(response.data['message'] ?? 'Gagal memperbarui pengumuman');
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ?? e.message ?? 'Gagal memperbarui pengumuman';
      throw Exception(msg);
    }
  }

  Future<void> deleteAnnouncement(int id) async {
    try {
      final response = await _dioClient.dio.delete(
        ApiConstants.adminAnnouncementDetail(id),
      );
      if (response.data['success'] != true) {
        throw Exception(response.data['message'] ?? 'Gagal menghapus pengumuman');
      }
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ?? e.message ?? 'Gagal menghapus pengumuman';
      throw Exception(msg);
    }
  }
}
