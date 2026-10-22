import 'package:dio/dio.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/utils/honorific_helper.dart';
import '../../profile/domain/models/family_member_model.dart';
import '../../profile/domain/models/vehicle_model.dart';
import '../domain/models/house_detail_full_model.dart';
import '../domain/models/house_model.dart';
import '../domain/models/occupant_model.dart';
import '../domain/models/pending_user_model.dart';
import '../domain/models/resident_user_model.dart';

class ResidentRepository {
  final Dio _dio;

  ResidentRepository({required Dio dio}) : _dio = dio;

  Future<List<PendingUserModel>> getPendingUsers() async {
    try {
      final res = await _dio.get(ApiConstants.pendingUsers);
      final data = res.data as Map<String, dynamic>;
      final list = (data['data'] as List<dynamic>? ?? [])
          .map((e) => PendingUserModel.fromJson(e as Map<String, dynamic>))
          .toList();
      return list;
    } on DioException catch (e) {
      final msg = e.response?.data is Map ? (e.response?.data as Map)['message'] : null;
      throw Exception(msg ?? 'Gagal memuat antrean verifikasi warga');
    }
  }

  Future<void> approveUser(int id) async {
    try {
      await _dio.post(ApiConstants.approveUser(id));
    } on DioException catch (e) {
      final msg = e.response?.data is Map ? (e.response?.data as Map)['message'] : null;
      throw Exception(msg ?? 'Gagal menyetujui warga');
    }
  }

  Future<void> rejectUser(int id, String reason) async {
    try {
      await _dio.post(
        ApiConstants.rejectUser(id),
        data: {'reason': reason},
      );
    } on DioException catch (e) {
      final msg = e.response?.data is Map ? (e.response?.data as Map)['message'] : null;
      throw Exception(msg ?? 'Gagal menolak pendaftaran warga');
    }
  }

  Future<List<HouseModel>> getHouses({String? block, String? status, String? search}) async {
    try {
      final queryParams = <String, dynamic>{};
      if (block != null && block.isNotEmpty && block != 'Semua Blok') {
        queryParams['block'] = block;
      }
      if (status != null && status.isNotEmpty && status != 'Semua Status') {
        queryParams['status'] = status;
      }
      if (search != null && search.isNotEmpty) {
        queryParams['search'] = search;
      }

      final res = await _dio.get(ApiConstants.houses, queryParameters: queryParams);
      final data = res.data as Map<String, dynamic>;
      final list = (data['data'] as List<dynamic>? ?? [])
          .map((e) => HouseModel.fromJson(e as Map<String, dynamic>))
          .toList();
      return list;
    } on DioException catch (e) {
      final msg = e.response?.data is Map ? (e.response?.data as Map)['message'] : null;
      throw Exception(msg ?? 'Gagal memuat master data rumah');
    }
  }

  Future<List<String>> getHouseBlocks() async {
    try {
      final res = await _dio.get(ApiConstants.houseBlocks);
      final data = res.data as Map<String, dynamic>;
      final list = (data['data'] as List<dynamic>? ?? []).map((e) => e.toString()).toList();
      return list;
    } on DioException catch (e) {
      final msg = e.response?.data is Map ? (e.response?.data as Map)['message'] : null;
      throw Exception(msg ?? 'Gagal memuat daftar blok');
    }
  }

  Future<List<HouseModel>> getAvailableHouses() async {
    try {
      final res = await _dio.get(ApiConstants.housesAvailable);
      final data = res.data as Map<String, dynamic>;
      final list = (data['data'] as List<dynamic>? ?? [])
          .map((e) => HouseModel.fromJson(e as Map<String, dynamic>))
          .toList();
      return list;
    } on DioException catch (e) {
      final msg = e.response?.data is Map ? (e.response?.data as Map)['message'] : null;
      throw Exception(msg ?? 'Gagal memuat daftar rumah tersedia');
    }
  }

  Future<HouseModel> createHouse(String block, String houseNumber, String status) async {
    try {
      final res = await _dio.post(
        ApiConstants.houses,
        data: {
          'block': block.trim().toUpperCase(),
          'house_number': houseNumber.trim(),
          'status': status.trim().toLowerCase(),
        },
      );
      final data = res.data as Map<String, dynamic>;
      return HouseModel.fromJson(data['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      final msg = e.response?.data is Map ? (e.response?.data as Map)['message'] : null;
      throw Exception(msg ?? 'Gagal menambah rumah baru');
    }
  }

  Future<HouseModel> updateHouse(int id, String block, String houseNumber, String status) async {
    try {
      final res = await _dio.put(
        ApiConstants.houseDetail(id),
        data: {
          'block': block.trim().toUpperCase(),
          'house_number': houseNumber.trim(),
          'status': status.trim().toLowerCase(),
        },
      );
      final data = res.data as Map<String, dynamic>;
      return HouseModel.fromJson(data['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      final msg = e.response?.data is Map ? (e.response?.data as Map)['message'] : null;
      throw Exception(msg ?? 'Gagal memperbarui data rumah');
    }
  }

  Future<void> deleteHouse(int id) async {
    try {
      await _dio.delete(ApiConstants.houseDetail(id));
    } on DioException catch (e) {
      final msg = e.response?.data is Map ? (e.response?.data as Map)['message'] : null;
      throw Exception(msg ?? 'Gagal menghapus rumah (masih terikat penghuni)');
    }
  }

  Future<int> bulkDeleteHouses(List<int> houseIds) async {
    try {
      final res = await _dio.post(
        ApiConstants.bulkDeleteHouses,
        data: {'house_ids': houseIds},
      );
      final data = res.data as Map<String, dynamic>;
      final payload = data['data'] as Map<String, dynamic>?;
      return (payload?['deleted_count'] as int?) ?? houseIds.length;
    } on DioException catch (e) {
      final msg = e.response?.data is Map ? (e.response?.data as Map)['message'] : null;
      throw Exception(msg ?? 'Gagal menghapus data hunian massal');
    }
  }

  Future<List<HouseOccupantModel>> getHouseOccupants(int houseId) async {
    try {
      final res = await _dio.get(ApiConstants.houseOccupants(houseId));
      final data = res.data as Map<String, dynamic>;
      final payload = data['data'] as Map<String, dynamic>;
      final occupantsList = (payload['occupants'] as List<dynamic>? ?? [])
          .map((e) => HouseOccupantModel.fromJson(e as Map<String, dynamic>))
          .toList();
      return occupantsList;
    } on DioException catch (e) {
      final msg = e.response?.data is Map ? (e.response?.data as Map)['message'] : null;
      throw Exception(msg ?? 'Gagal memuat penghuni rumah');
    }
  }

  Future<List<UnassignedResidentModel>> getUnassignedResidents({String? search}) async {
    try {
      final queryParams = <String, dynamic>{};
      if (search != null && search.isNotEmpty) {
        queryParams['search'] = search;
      }
      final res = await _dio.get(ApiConstants.unassignedResidents, queryParameters: queryParams);
      final data = res.data as Map<String, dynamic>;
      final list = (data['data'] as List<dynamic>? ?? [])
          .map((e) => UnassignedResidentModel.fromJson(e as Map<String, dynamic>))
          .toList();
      return list;
    } on DioException catch (e) {
      final msg = e.response?.data is Map ? (e.response?.data as Map)['message'] : null;
      throw Exception(msg ?? 'Gagal memuat warga belum terpetakan');
    }
  }

  Future<void> assignResident({
    required int houseId,
    required int userId,
    required String occupantType,
  }) async {
    try {
      await _dio.post(
        ApiConstants.assignResident(houseId),
        data: {
          'user_id': userId,
          'occupant_type': occupantType,
        },
      );
    } on DioException catch (e) {
      final msg = e.response?.data is Map ? (e.response?.data as Map)['message'] : null;
      throw Exception(msg ?? 'Gagal memetakan warga ke rumah');
    }
  }

  Future<void> removeResident({
    required int houseId,
    required int userId,
  }) async {
    try {
      await _dio.delete(ApiConstants.removeResident(houseId, userId));
    } on DioException catch (e) {
      final msg = e.response?.data is Map ? (e.response?.data as Map)['message'] : null;
      throw Exception(msg ?? 'Gagal melepas warga dari rumah');
    }
  }

  Future<void> transferHouse({
    required int userId,
    required int newHouseId,
  }) async {
    try {
      await _dio.post(
        ApiConstants.transferHouse(userId),
        data: {
          'new_house_id': newHouseId,
        },
      );
    } on DioException catch (e) {
      final msg = e.response?.data is Map ? (e.response?.data as Map)['message'] : null;
      throw Exception(msg ?? 'Gagal memindahkan warga ke rumah baru');
    }
  }

  Future<HouseDetailFullModel> getHouseDetails(int houseId) async {
    try {
      final res = await _dio.get(ApiConstants.houseDetails(houseId));
      final data = res.data as Map<String, dynamic>;
      return HouseDetailFullModel.fromJson(data['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      final msg = e.response?.data is Map ? (e.response?.data as Map)['message'] : null;
      throw Exception(msg ?? 'Gagal memuat rincian hunian');
    }
  }

  Future<FamilyMemberModel> adminAddFamilyMember({
    required int houseId,
    required String name,
    required String relation,
    String? phone,
  }) async {
    try {
      final res = await _dio.post(
        ApiConstants.adminHouseFamily(houseId),
        data: {
          'name': name.trim(),
          'relation': relation.trim().toLowerCase(),
          if (phone != null && phone.isNotEmpty) 'phone': phone.trim(),
        },
      );
      final data = res.data as Map<String, dynamic>;
      return FamilyMemberModel.fromJson(data['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      final msg = e.response?.data is Map ? (e.response?.data as Map)['message'] : null;
      throw Exception(msg ?? 'Gagal menambahkan anggota keluarga');
    }
  }

  Future<void> adminDeleteFamilyMember({
    required int houseId,
    required int familyId,
  }) async {
    try {
      await _dio.delete(ApiConstants.adminDeleteHouseFamily(houseId, familyId));
    } on DioException catch (e) {
      final msg = e.response?.data is Map ? (e.response?.data as Map)['message'] : null;
      throw Exception(msg ?? 'Gagal menghapus anggota keluarga');
    }
  }

  Future<VehicleModel> adminAddVehicle({
    required int houseId,
    required String plateNumber,
    required String vehicleType,
    String? brandModel,
  }) async {
    try {
      final res = await _dio.post(
        ApiConstants.adminHouseVehicles(houseId),
        data: {
          'plate_number': plateNumber.trim().toUpperCase(),
          'vehicle_type': vehicleType.trim().toLowerCase(),
          if (brandModel != null && brandModel.isNotEmpty) 'brand_model': brandModel.trim(),
        },
      );
      final data = res.data as Map<String, dynamic>;
      return VehicleModel.fromJson(data['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      final msg = e.response?.data is Map ? (e.response?.data as Map)['message'] : null;
      throw Exception(msg ?? 'Gagal menambahkan kendaraan');
    }
  }

  Future<void> adminDeleteVehicle({
    required int houseId,
    required int vehicleId,
  }) async {
    try {
      await _dio.delete(ApiConstants.adminDeleteHouseVehicle(houseId, vehicleId));
    } on DioException catch (e) {
      final msg = e.response?.data is Map ? (e.response?.data as Map)['message'] : null;
      throw Exception(msg ?? 'Gagal menghapus kendaraan');
    }
  }

  Future<List<ResidentUserModel>> getAdminUsers({
    String? search,
    String? status,
    String? role,
    int? houseId,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (search != null && search.isNotEmpty) queryParams['search'] = search;
      if (status != null && status.isNotEmpty) queryParams['status'] = status;
      if (role != null && role.isNotEmpty) queryParams['role'] = role;
      if (houseId != null) queryParams['house_id'] = houseId;

      final res = await _dio.get(ApiConstants.adminUsers, queryParameters: queryParams);
      final data = res.data as Map<String, dynamic>;
      final list = (data['data'] as List<dynamic>? ?? [])
          .map((e) => ResidentUserModel.fromJson(e as Map<String, dynamic>))
          .toList();
      return list;
    } on DioException catch (e) {
      final msg = e.response?.data is Map ? (e.response?.data as Map)['message'] : null;
      throw Exception(msg ?? 'Gagal memuat data warga');
    }
  }

  Future<ResidentUserModel> adminCreateUser({
    String salutation = HonorificHelper.bapak,
    required String name,
    required String phone,
    required String email,
    required String password,
    int? houseId,
    String role = 'RESIDENT',
    String status = 'active',
    String ownershipStatus = 'pemilik',
  }) async {
    try {
      final res = await _dio.post(
        ApiConstants.adminUsers,
        data: {
          'salutation': HonorificHelper.normalize(salutation),
          'name': name.trim(),
          'phone': phone.trim(),
          'email': email.trim().toLowerCase(),
          'password': password.trim(),
          if (houseId != null) 'house_id': houseId,
          'role': role,
          'status': status,
          'ownership_status': ownershipStatus,
        },
      );
      final data = res.data as Map<String, dynamic>;
      return ResidentUserModel.fromJson(data['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      final msg = e.response?.data is Map ? (e.response?.data as Map)['message'] : null;
      throw Exception(msg ?? 'Gagal mendaftarkan warga baru');
    }
  }

  Future<ResidentUserModel> adminUpdateUser({
    required int userId,
    String salutation = HonorificHelper.bapak,
    required String name,
    required String phone,
    required String email,
    int? houseId,
    String role = 'RESIDENT',
    String status = 'active',
    String ownershipStatus = 'pemilik',
  }) async {
    try {
      final res = await _dio.put(
        ApiConstants.adminUserDetail(userId),
        data: {
          'salutation': HonorificHelper.normalize(salutation),
          'name': name.trim(),
          'phone': phone.trim(),
          'email': email.trim().toLowerCase(),
          'house_id': houseId,
          'role': role,
          'status': status,
          'ownership_status': ownershipStatus,
        },
      );
      final data = res.data as Map<String, dynamic>;
      return ResidentUserModel.fromJson(data['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      final msg = e.response?.data is Map ? (e.response?.data as Map)['message'] : null;
      throw Exception(msg ?? 'Gagal memperbarui data warga');
    }
  }

  Future<void> adminDeleteUser(int userId) async {
    try {
      await _dio.delete(ApiConstants.adminUserDetail(userId));
    } on DioException catch (e) {
      final msg = e.response?.data is Map ? (e.response?.data as Map)['message'] : null;
      throw Exception(msg ?? 'Gagal menghapus warga');
    }
  }

  Future<void> adminResetPassword({
    required int userId,
    required String newPassword,
  }) async {
    try {
      await _dio.post(
        ApiConstants.adminResetPassword(userId),
        data: {'new_password': newPassword.trim()},
      );
    } on DioException catch (e) {
      final msg = e.response?.data is Map ? (e.response?.data as Map)['message'] : null;
      throw Exception(msg ?? 'Gagal mereset kata sandi');
    }
  }

  Future<void> adminAssignRole({
    required int userId,
    required String role,
  }) async {
    try {
      await _dio.put(
        ApiConstants.adminAssignRole(userId),
        data: {'role': role.trim().toUpperCase()},
      );
    } on DioException catch (e) {
      final msg = e.response?.data is Map ? (e.response?.data as Map)['message'] : null;
      throw Exception(msg ?? 'Gagal memperbarui peran organisasi');
    }
  }
}
