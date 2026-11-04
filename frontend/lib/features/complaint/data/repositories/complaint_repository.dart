import 'dart:typed_data';
import 'package:dio/dio.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/dio_client.dart';
import '../../domain/models/complaint_model.dart';

class ComplaintRepository {
  final DioClient _dioClient;

  ComplaintRepository(this._dioClient);

  Future<ComplaintModel> createComplaint({
    required String title,
    required String description,
    required ComplaintCategory category,
    Uint8List? photoBytes,
    String? photoFileName,
  }) async {
    final Map<String, dynamic> formMap = {
      'title': title,
      'description': description,
      'category': category.label,
    };

    if (photoBytes != null && photoFileName != null) {
      formMap['photo'] = MultipartFile.fromBytes(
        photoBytes,
        filename: photoFileName,
      );
    }

    final formData = FormData.fromMap(formMap);

    final response = await _dioClient.dio.post(
      ApiConstants.complaints,
      data: formData,
      options: Options(
        contentType: 'multipart/form-data',
      ),
    );

    final data = response.data['data'] as Map<String, dynamic>;
    return ComplaintModel.fromJson(data);
  }

  Future<({List<ComplaintModel> complaints, int total, int totalPages})> getMyComplaints({
    int page = 1,
    int limit = 10,
  }) async {
    final response = await _dioClient.dio.get(
      ApiConstants.complaints,
      queryParameters: {
        'page': page,
        'limit': limit,
      },
    );

    final rawList = response.data['data'] as List<dynamic>? ?? [];
    final complaints = rawList
        .map((item) => ComplaintModel.fromJson(item as Map<String, dynamic>))
        .toList();

    final meta = response.data['meta'] as Map<String, dynamic>? ?? {};
    final total = meta['total'] as int? ?? complaints.length;
    final totalPages = meta['total_pages'] as int? ?? 1;

    return (complaints: complaints, total: total, totalPages: totalPages);
  }

  Future<ComplaintModel> getComplaintDetail(int id) async {
    final response = await _dioClient.dio.get(
      ApiConstants.complaintDetail(id),
    );

    final data = response.data['data'] as Map<String, dynamic>;
    return ComplaintModel.fromJson(data);
  }

  // ----------------------------------------------------
  // US-5.4: Pengelolaan Tiket, Penugasan & Kanban (Admin)
  // ----------------------------------------------------

  Future<({List<ComplaintModel> complaints, int total, int totalPages, int page})> getAdminComplaints({
    String? status,
    String? category,
    String? officer,
    String? search,
    String? startDate,
    String? endDate,
    int page = 1,
    int limit = 10,
  }) async {
    final query = <String, dynamic>{
      'page': page,
      'limit': limit,
    };
    if (status != null && status.isNotEmpty) query['status'] = status;
    if (category != null && category.isNotEmpty) query['category'] = category;
    if (officer != null && officer.isNotEmpty) query['officer'] = officer;
    if (search != null && search.isNotEmpty) query['search'] = search;
    if (startDate != null && startDate.isNotEmpty) query['start_date'] = startDate;
    if (endDate != null && endDate.isNotEmpty) query['end_date'] = endDate;

    final response = await _dioClient.dio.get(
      ApiConstants.adminComplaints,
      queryParameters: query,
    );

    final rawList = response.data['data'] as List<dynamic>? ?? [];
    final complaints = rawList
        .map((item) => ComplaintModel.fromJson(item as Map<String, dynamic>))
        .toList();

    final meta = response.data['meta'] as Map<String, dynamic>? ?? {};
    final total = meta['total'] as int? ?? complaints.length;
    final totalPages = meta['total_pages'] as int? ?? 1;

    return (complaints: complaints, total: total, totalPages: totalPages, page: page);
  }

  Future<KanbanComplaintsData> getKanbanComplaints({
    String? category,
    String? officer,
    String? search,
    String? startDate,
    String? endDate,
  }) async {
    final query = <String, dynamic>{};
    if (category != null && category.isNotEmpty) query['category'] = category;
    if (officer != null && officer.isNotEmpty) query['officer'] = officer;
    if (search != null && search.isNotEmpty) query['search'] = search;
    if (startDate != null && startDate.isNotEmpty) query['start_date'] = startDate;
    if (endDate != null && endDate.isNotEmpty) query['end_date'] = endDate;

    final response = await _dioClient.dio.get(
      ApiConstants.adminComplaintsKanban,
      queryParameters: query,
    );

    final data = response.data['data'] as Map<String, dynamic>;
    return KanbanComplaintsData.fromJson(data);
  }

  Future<({ComplaintModel complaint, List<ComplaintAssignmentModel> assignments})> getAdminComplaintDetail(int id) async {
    final response = await _dioClient.dio.get(
      ApiConstants.adminComplaintDetail(id),
    );

    final data = response.data['data'] as Map<String, dynamic>;
    final complaint = ComplaintModel.fromJson(data['complaint'] as Map<String, dynamic>);
    final rawAssignments = data['assignments'] as List<dynamic>? ?? [];
    final assignments = rawAssignments
        .map((e) => ComplaintAssignmentModel.fromJson(e as Map<String, dynamic>))
        .toList();

    return (complaint: complaint, assignments: assignments);
  }

  Future<({ComplaintModel complaint, List<ComplaintAssignmentModel> assignments})> assignOfficer({
    required int complaintId,
    required String officerName,
    int? officerUserId,
    String? notes,
    String? status,
  }) async {
    final body = <String, dynamic>{
      'officer_name': officerName,
    };
    if (officerUserId != null && officerUserId > 0) {
      body['officer_user_id'] = officerUserId;
    }
    if (notes != null && notes.isNotEmpty) {
      body['notes'] = notes;
    }
    if (status != null && status.isNotEmpty) {
      body['status'] = status;
    }

    final response = await _dioClient.dio.post(
      ApiConstants.adminComplaintAssign(complaintId),
      data: body,
    );

    final data = response.data['data'] as Map<String, dynamic>;
    final complaint = ComplaintModel.fromJson(data['complaint'] as Map<String, dynamic>);
    final rawAssignments = data['assignments'] as List<dynamic>? ?? [];
    final assignments = rawAssignments
        .map((e) => ComplaintAssignmentModel.fromJson(e as Map<String, dynamic>))
        .toList();

    return (complaint: complaint, assignments: assignments);
  }

  Future<ComplaintModel> updateStatus({
    required int complaintId,
    required ComplaintStatus status,
  }) async {
    final response = await _dioClient.dio.patch(
      ApiConstants.adminComplaintStatus(complaintId),
      data: {'status': status.label},
    );

    final data = response.data['data'] as Map<String, dynamic>;
    return ComplaintModel.fromJson(data);
  }

  Future<List<EligibleOfficerModel>> getEligibleOfficers() async {
    final response = await _dioClient.dio.get(
      ApiConstants.adminComplaintsEligibleOfficers,
    );

    final rawList = response.data['data'] as List<dynamic>? ?? [];
    return rawList
        .map((e) => EligibleOfficerModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<ComplaintAssignmentModel>> getAssignmentHistory(int complaintId) async {
    final response = await _dioClient.dio.get(
      ApiConstants.adminComplaintAssignments(complaintId),
    );

    final rawList = response.data['data'] as List<dynamic>? ?? [];
    return rawList
        .map((e) => ComplaintAssignmentModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Uint8List> getComplaintPhotoBytes(String photoUrl) async {
    final cleanPath = photoUrl.trim();
    if (cleanPath.isEmpty) {
      throw const ComplaintPhotoException('Path foto pengaduan kosong');
    }

    try {
      final response = await _dioClient.dio.get<List<int>>(
        cleanPath,
        options: Options(
          responseType: ResponseType.bytes,
        ),
      );

      final data = response.data;
      if (data == null || data.isEmpty) {
        throw const ComplaintPhotoException('Data foto pengaduan kosong');
      }

      return Uint8List.fromList(data);
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      if (statusCode == 401) {
        throw const ComplaintPhotoException('Autentikasi diperlukan untuk melihat foto pengaduan');
      } else if (statusCode == 403) {
        throw const ComplaintPhotoException('Akses dilindungi: Anda tidak memiliki izin melihat foto ini');
      } else if (statusCode == 404) {
        throw const ComplaintPhotoException('Foto pengaduan tidak ditemukan di server');
      } else if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.connectionError) {
        throw const ComplaintPhotoException('Gagal memuat foto: periksa koneksi jaringan Anda');
      }

      final msg = e.response?.data is Map ? e.response?.data['message']?.toString() : null;
      throw ComplaintPhotoException(msg ?? 'Gagal memuat foto pengaduan');
    } catch (e) {
      if (e is ComplaintPhotoException) rethrow;
      throw ComplaintPhotoException('Terjadi kesalahan saat memproses foto pengaduan: $e');
    }
  }
}

class ComplaintPhotoException implements Exception {
  final String message;
  const ComplaintPhotoException(this.message);

  @override
  String toString() => message;
}
