import 'package:dio/dio.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/dio_client.dart';
import '../domain/models/security_models.dart';

class SecurityRepository {
  final DioClient _dioClient;

  SecurityRepository(this._dioClient);

  Future<List<SecurityAssignmentModel>> getMyAssignments() async {
    try {
      final response =
          await _dioClient.dio.get(ApiConstants.securityMyAssignments);
      if (response.statusCode == 200 && response.data['success'] == true) {
        final List list = response.data['data'] as List? ?? [];
        return list
            .map((e) =>
                SecurityAssignmentModel.fromJson(e as Map<String, dynamic>))
            .where((a) => a.isActive)
            .toList();
      }
      return [];
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ??
          'Gagal mengambil data penugasan satpam';
      throw Exception(msg);
    }
  }

  Future<List<SecurityIncidentModel>> getActiveIncidents() async {
    try {
      final response = await _dioClient.dio.get(ApiConstants.activeIncidents);
      if (response.statusCode == 200 && response.data['success'] == true) {
        final List list = response.data['data'] as List? ?? [];
        return list
            .map((e) =>
                SecurityIncidentModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return [];
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ?? 'Gagal memuat insiden aktif';
      throw Exception(msg);
    }
  }

  Future<SecurityIncidentModel> getIncidentDetail(int id) async {
    try {
      final response =
          await _dioClient.dio.get(ApiConstants.incidentDetail(id));
      if (response.statusCode == 200 && response.data['success'] == true) {
        return SecurityIncidentModel.fromJson(
            response.data['data'] as Map<String, dynamic>);
      }
      throw Exception('Insiden tidak ditemukan');
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ?? 'Gagal memuat detail insiden';
      throw Exception(msg);
    }
  }

  Future<SecurityIncidentModel> acknowledgeIncident(int id,
      {String? notes}) async {
    try {
      final response = await _dioClient.dio.post(
        ApiConstants.incidentAcknowledge(id),
        data: notes != null && notes.isNotEmpty ? {'notes': notes} : {},
      );
      if (response.statusCode == 200 && response.data['success'] == true) {
        return SecurityIncidentModel.fromJson(
            response.data['data'] as Map<String, dynamic>);
      }
      throw Exception('Gagal menanggapi insiden');
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ?? 'Gagal menanggapi insiden';
      throw Exception(msg);
    }
  }

  Future<SecurityIncidentModel> resolveIncident(
      int id, String resolutionNotes) async {
    try {
      final response = await _dioClient.dio.post(
        ApiConstants.incidentResolve(id),
        data: {'resolution_notes': resolutionNotes},
      );
      if (response.statusCode == 200 && response.data['success'] == true) {
        return SecurityIncidentModel.fromJson(
            response.data['data'] as Map<String, dynamic>);
      }
      throw Exception('Gagal menyelesaikan insiden');
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ?? 'Gagal menyelesaikan insiden';
      throw Exception(msg);
    }
  }

  Future<void> registerDeviceToken({
    required String deviceId,
    required String deviceToken,
    String platform = 'android',
  }) async {
    try {
      await _dioClient.dio.post(
        ApiConstants.securityDeviceToken,
        data: {
          'device_id': deviceId,
          'device_token': deviceToken,
          'platform': platform,
        },
      );
    } on DioException catch (e) {
      final msg =
          e.response?.data?['message'] ?? 'Gagal mendaftarkan token perangkat';
      throw Exception(msg);
    }
  }

  Future<void> revokeDeviceToken(String deviceId) async {
    try {
      await _dioClient.dio.post(
        ApiConstants.securityDeviceTokenRevoke,
        data: {'device_id': deviceId},
      );
    } on DioException catch (e) {
      final msg =
          e.response?.data?['message'] ?? 'Gagal mencabut token perangkat';
      throw Exception(msg);
    }
  }

  // ----------------------------------------------------
  // SPRINT 4: ADMIN SECURITY MANAGEMENT METHODS
  // (Authorized for Admin, Chairperson, Vice Chairperson)
  // ----------------------------------------------------

  Future<List<SecurityUserModel>> getAdminSecurityUsers() async {
    try {
      final response =
          await _dioClient.dio.get(ApiConstants.adminSecurityUsers);
      if (response.statusCode == 200 && response.data['success'] == true) {
        final List list = response.data['data'] as List? ?? [];
        return list
            .map((e) => SecurityUserModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return [];
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ?? 'Gagal memuat daftar satpam';
      throw Exception(msg);
    }
  }

  Future<SecurityUserModel> createSecurityUser({
    required String name,
    required String phone,
    required String email,
    required String password,
    String salutation = 'Bapak',
  }) async {
    try {
      final response = await _dioClient.dio.post(
        ApiConstants.adminSecurityUsers,
        data: {
          'salutation': salutation,
          'name': name,
          'phone': phone,
          'email': email,
          'password': password,
        },
      );
      if ((response.statusCode == 200 || response.statusCode == 201) &&
          response.data['success'] == true) {
        return SecurityUserModel.fromJson(
            response.data['data'] as Map<String, dynamic>);
      }
      throw Exception('Gagal membuat akun satpam');
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ?? 'Gagal membuat akun satpam';
      throw Exception(msg);
    }
  }

  Future<void> setSecurityUserStatus(int userId, String status) async {
    try {
      final response = await _dioClient.dio.put(
        ApiConstants.adminSecurityUserStatus(userId),
        data: {'status': status},
      );
      if (response.statusCode != 200 || response.data['success'] != true) {
        throw Exception(
            response.data?['message'] ?? 'Gagal memperbarui status satpam');
      }
    } on DioException catch (e) {
      final msg =
          e.response?.data?['message'] ?? 'Gagal memperbarui status satpam';
      throw Exception(msg);
    }
  }

  Future<List<NeighborhoodModel>> getAdminNeighborhoods() async {
    try {
      final response =
          await _dioClient.dio.get(ApiConstants.adminNeighborhoods);
      if (response.statusCode == 200 && response.data['success'] == true) {
        final List list = response.data['data'] as List? ?? [];
        return list
            .map((e) => NeighborhoodModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return [];
    } on DioException catch (e) {
      final msg =
          e.response?.data?['message'] ?? 'Gagal memuat daftar lingkungan';
      throw Exception(msg);
    }
  }

  Future<List<SecurityAssignmentModel>> getAdminAssignments({
    int? userId,
    int? neighborhoodId,
    bool? activeOnly,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (userId != null) {
        queryParams['user_id'] = userId;
      }
      if (neighborhoodId != null) {
        queryParams['neighborhood_id'] = neighborhoodId;
      }
      if (activeOnly != null) {
        queryParams['active_only'] = activeOnly;
      }

      final response = await _dioClient.dio.get(
        ApiConstants.adminSecurityAssignments,
        queryParameters: queryParams,
      );
      if (response.statusCode == 200 && response.data['success'] == true) {
        final List list = response.data['data'] as List? ?? [];
        return list
            .map((e) =>
                SecurityAssignmentModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return [];
    } on DioException catch (e) {
      final msg =
          e.response?.data?['message'] ?? 'Gagal memuat penugasan satpam';
      throw Exception(msg);
    }
  }

  Future<SecurityAssignmentModel> createSecurityAssignment({
    required int userId,
    required int neighborhoodId,
    String? notes,
  }) async {
    try {
      final response = await _dioClient.dio.post(
        ApiConstants.adminSecurityAssignments,
        data: {
          'user_id': userId,
          'neighborhood_id': neighborhoodId,
          'notes': notes ?? '',
        },
      );
      if ((response.statusCode == 200 || response.statusCode == 201) &&
          response.data['success'] == true) {
        return SecurityAssignmentModel.fromJson(
            response.data['data'] as Map<String, dynamic>);
      }
      throw Exception('Gagal membuat penugasan satpam');
    } on DioException catch (e) {
      final msg =
          e.response?.data?['message'] ?? 'Gagal membuat penugasan satpam';
      throw Exception(msg);
    }
  }

  Future<void> updateSecurityAssignmentStatus(
    int assignmentId, {
    required bool isActive,
    String? notes,
  }) async {
    try {
      final response = await _dioClient.dio.put(
        ApiConstants.adminSecurityAssignmentStatus(assignmentId),
        data: {
          'is_active': isActive,
          'notes': notes ?? '',
        },
      );
      if (response.statusCode != 200 || response.data['success'] != true) {
        throw Exception(
            response.data?['message'] ?? 'Gagal memperbarui status penugasan');
      }
    } on DioException catch (e) {
      final msg =
          e.response?.data?['message'] ?? 'Gagal memperbarui status penugasan';
      throw Exception(msg);
    }
  }

  Future<void> revokeSecurityAssignment(int assignmentId,
      {String? notes}) async {
    try {
      final response = await _dioClient.dio.delete(
        ApiConstants.adminSecurityAssignmentDetail(assignmentId),
        data: notes != null && notes.isNotEmpty ? {'notes': notes} : null,
      );
      if (response.statusCode != 200 || response.data['success'] != true) {
        throw Exception(
            response.data?['message'] ?? 'Gagal mencabut penugasan satpam');
      }
    } on DioException catch (e) {
      final msg =
          e.response?.data?['message'] ?? 'Gagal mencabut penugasan satpam';
      throw Exception(msg);
    }
  }

  // ----------------------------------------------------
  // ENHANCEMENT: EMERGENCY MONITORING & CORRECTION
  // ----------------------------------------------------

  Future<int> getActiveIncidentCount() async {
    try {
      final response =
          await _dioClient.dio.get(ApiConstants.incidentActiveCount);
      if (response.statusCode == 200 && response.data['success'] == true) {
        final data = response.data['data'] as Map<String, dynamic>? ?? {};
        return data['active_count'] as int? ?? 0;
      }
      return 0;
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ??
          'Gagal memuat hitungan insiden aktif';
      throw Exception(msg);
    }
  }

  Future<IncidentListResponse> getIncidents({
    int page = 1,
    int limit = 20,
    String? status,
    String? category,
    int? neighborhoodId,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'page': page,
        'limit': limit,
      };
      if (status != null && status.isNotEmpty) {
        queryParams['status'] = status;
      }
      if (category != null && category.isNotEmpty) {
        queryParams['category'] = category;
      }
      if (neighborhoodId != null) {
        queryParams['neighborhood_id'] = neighborhoodId;
      }

      final response = await _dioClient.dio.get(
        ApiConstants.incidents,
        queryParameters: queryParams,
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        return IncidentListResponse.fromJson(
            response.data as Map<String, dynamic>);
      }
      return const IncidentListResponse(
          incidents: [], total: 0, page: 1, limit: 20, totalPages: 1);
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ??
          'Gagal memuat daftar laporan kejadian';
      throw Exception(msg);
    }
  }

  Future<List<IncidentLogModel>> getIncidentLogs(int incidentId) async {
    try {
      final response =
          await _dioClient.dio.get(ApiConstants.incidentLogs(incidentId));
      if (response.statusCode == 200 && response.data['success'] == true) {
        final List list = response.data['data'] as List? ?? [];
        return list
            .map((e) => IncidentLogModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return [];
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ??
          'Gagal memuat riwayat audit insiden';
      throw Exception(msg);
    }
  }

  Future<SecurityIncidentModel> correctIncident(
    int incidentId, {
    String? status,
    String? category,
    String? title,
    String? description,
    required String notes,
  }) async {
    try {
      final body = <String, dynamic>{
        'notes': notes,
      };
      if (status != null && status.isNotEmpty) body['status'] = status;
      if (category != null && category.isNotEmpty) body['category'] = category;
      if (title != null && title.isNotEmpty) body['title'] = title;
      if (description != null) body['description'] = description;

      final response = await _dioClient.dio.patch(
        ApiConstants.incidentCorrect(incidentId),
        data: body,
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        return SecurityIncidentModel.fromJson(
            response.data['data'] as Map<String, dynamic>);
      }
      throw Exception(
          response.data?['message'] ?? 'Gagal mengoreksi laporan insiden');
    } on DioException catch (e) {
      final msg =
          e.response?.data?['message'] ?? 'Gagal mengoreksi laporan insiden';
      throw Exception(msg);
    }
  }
}
