import 'package:dio/dio.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/dio_client.dart';
import '../../domain/models/invitation_model.dart';

class InvitationRepository {
  final DioClient _dioClient;

  InvitationRepository(this._dioClient);

  Future<GuestInvitationModel> createInvitation({
    required String guestName,
    required VisitType visitType,
    String? phone,
    String? notes,
    int validHours = 24,
  }) async {
    try {
      final response = await _dioClient.dio.post(
        ApiConstants.invitations,
        data: {
          'guest_name': guestName.trim(),
          'visit_type': visitType.toApi(),
          if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
          if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
          'valid_hours': validHours,
        },
      );

      if (response.data != null && response.data['data'] != null) {
        return GuestInvitationModel.fromJson(
            response.data['data'] as Map<String, dynamic>);
      }
      throw Exception('Format data respons undangan tidak valid');
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ??
          e.message ??
          'Gagal membuat undangan tamu';
      throw Exception(msg);
    }
  }

  Future<List<GuestInvitationModel>> getMyInvitations({
    int page = 1,
    int limit = 50,
  }) async {
    try {
      final response = await _dioClient.dio.get(
        ApiConstants.invitations,
        queryParameters: {'page': page, 'limit': limit},
      );

      if (response.data != null && response.data['data'] != null) {
        final list = response.data['data'] as List;
        return list
            .map((item) =>
                GuestInvitationModel.fromJson(item as Map<String, dynamic>))
            .toList();
      }
      return [];
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ??
          e.message ??
          'Gagal memuat daftar undangan';
      throw Exception(msg);
    }
  }

  Future<GuestInvitationModel> getInvitationDetail(int id) async {
    try {
      final response =
          await _dioClient.dio.get(ApiConstants.invitationDetail(id));

      if (response.data != null && response.data['data'] != null) {
        return GuestInvitationModel.fromJson(
            response.data['data'] as Map<String, dynamic>);
      }
      throw Exception('Undangan tidak ditemukan');
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ??
          e.message ??
          'Gagal memuat detail undangan';
      throw Exception(msg);
    }
  }

  Future<void> cancelInvitation(int id, {String? reason}) async {
    try {
      await _dioClient.dio.post(
        ApiConstants.cancelInvitation(id),
        data: {
          if (reason != null && reason.trim().isNotEmpty)
            'reason': reason.trim(),
        },
      );
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ??
          e.message ??
          'Gagal membatalkan undangan';
      throw Exception(msg);
    }
  }

  Future<void> completeInvitation(int id) async {
    try {
      await _dioClient.dio.post(
        ApiConstants.completeInvitation(id),
      );
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ??
          e.message ??
          'Gagal menyelesaikan kunjungan';
      throw Exception(msg);
    }
  }

  // US-5.2: Security Gate Operations (Verify, Check-In, Check-Out, History)

  Future<VerifyInvitationResult> verifyInvitation(String rawCodeOrPayload) async {
    try {
      final response = await _dioClient.dio.post(
        ApiConstants.verifyInvitation,
        data: {'code': rawCodeOrPayload.trim()},
      );

      if (response.data != null) {
        return VerifyInvitationResult.fromJson(
            response.data as Map<String, dynamic>);
      }
      throw Exception('Format data verifikasi tidak valid');
    } on DioException catch (e) {
      if (e.response?.data != null && e.response?.data is Map) {
        return VerifyInvitationResult.fromJson(
            e.response!.data as Map<String, dynamic>);
      }
      final msg = e.response?.data?['message'] ??
          e.message ??
          'Gagal memverifikasi QR Code';
      throw Exception(msg);
    }
  }

  Future<GuestVisitModel> checkInGuest({
    required String code,
    String? notes,
  }) async {
    try {
      final response = await _dioClient.dio.post(
        ApiConstants.checkInInvitation,
        data: {
          'code': code.trim(),
          if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
        },
      );

      if (response.data != null && response.data['data'] != null) {
        return GuestVisitModel.fromJson(
            response.data['data'] as Map<String, dynamic>);
      }
      throw Exception('Gagal mencatat check-in');
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ??
          e.message ??
          'Gagal check-in tamu';
      throw Exception(msg);
    }
  }

  Future<GuestVisitModel> checkOutGuest({
    int? visitID,
    String? code,
    String? notes,
    bool endInvitation = false,
  }) async {
    try {
      final response = await _dioClient.dio.post(
        ApiConstants.checkOutInvitation,
        data: {
          if (visitID != null && visitID > 0) 'visit_id': visitID,
          if (code != null && code.trim().isNotEmpty) 'code': code.trim(),
          if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
          if (endInvitation) 'end_invitation': true,
        },
      );

      if (response.data != null && response.data['data'] != null) {
        return GuestVisitModel.fromJson(
            response.data['data'] as Map<String, dynamic>);
      }
      throw Exception('Gagal mencatat check-out');
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ??
          e.message ??
          'Gagal check-out tamu';
      throw Exception(msg);
    }
  }

  Future<List<GuestVisitGroupModel>> getGroupedGuestVisits({
    int page = 1,
    int limit = 50,
    String? status,
    String? search,
    String? visitType,
  }) async {
    try {
      final response = await _dioClient.dio.get(
        ApiConstants.guestVisits,
        queryParameters: {
          'page': page,
          'limit': limit,
          'grouped': 'true',
          if (status != null && status.isNotEmpty) 'status': status,
          if (search != null && search.isNotEmpty) 'search': search,
          if (visitType != null && visitType.isNotEmpty) 'visit_type': visitType,
        },
      );

      if (response.data != null && response.data['data'] != null) {
        final list = response.data['data'] as List;
        return list
            .map((item) =>
                GuestVisitGroupModel.fromJson(item as Map<String, dynamic>))
            .toList();
      }
      return [];
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ??
          e.message ??
          'Gagal memuat riwayat kunjungan terpadu';
      throw Exception(msg);
    }
  }

  Future<List<GuestVisitModel>> getGuestVisits({
    int page = 1,
    int limit = 50,
    String? status,
    String? search,
    String? visitType,
  }) async {
    try {
      final response = await _dioClient.dio.get(
        ApiConstants.guestVisits,
        queryParameters: {
          'page': page,
          'limit': limit,
          if (status != null && status.isNotEmpty) 'status': status,
          if (search != null && search.isNotEmpty) 'search': search,
          if (visitType != null && visitType.isNotEmpty) 'visit_type': visitType,
        },
      );

      if (response.data != null && response.data['data'] != null) {
        final list = response.data['data'] as List;
        return list
            .map((item) =>
                GuestVisitModel.fromJson(item as Map<String, dynamic>))
            .toList();
      }
      return [];
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ??
          e.message ??
          'Gagal memuat riwayat kunjungan';
      throw Exception(msg);
    }
  }

  Future<GuestVisitModel> getGuestVisitDetail(int id) async {
    try {
      final response = await _dioClient.dio.get(ApiConstants.guestVisitDetail(id));
      if (response.data != null && response.data['data'] != null) {
        return GuestVisitModel.fromJson(
            response.data['data'] as Map<String, dynamic>);
      }
      throw Exception('Data kunjungan tidak ditemukan');
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ??
          e.message ??
          'Gagal memuat detail kunjungan';
      throw Exception(msg);
    }
  }
}
