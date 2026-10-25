import 'package:dio/dio.dart';
import '../../../../core/constants/api_constants.dart';
import '../domain/models/family_member_model.dart';
import '../domain/models/profile_detail_model.dart';
import '../domain/models/vehicle_model.dart';

class ProfileRepository {
  final Dio _dio;

  ProfileRepository({required Dio dio}) : _dio = dio;

  Future<ProfileDetailModel> getProfile() async {
    try {
      final res = await _dio.get(ApiConstants.profile);
      final data = res.data as Map<String, dynamic>;
      final payload = data['data'] as Map<String, dynamic>;
      return ProfileDetailModel.fromJson(payload);
    } on DioException catch (e) {
      final msg =
          e.response?.data is Map ? (e.response?.data as Map)['message'] : null;
      throw Exception(msg ?? 'Gagal memuat profil');
    }
  }

  Future<void> updateProfile({
    required String name,
    required String phone,
    String? photoUrl,
  }) async {
    try {
      await _dio.put(
        ApiConstants.profile,
        data: {
          'name': name.trim(),
          'phone': phone.trim(),
          'profile_photo_url': photoUrl,
        },
      );
    } on DioException catch (e) {
      final msg =
          e.response?.data is Map ? (e.response?.data as Map)['message'] : null;
      throw Exception(msg ?? 'Gagal memperbarui profil');
    }
  }

  Future<FamilyMemberModel> addFamilyMember({
    required String name,
    required String relation,
    String? phone,
  }) async {
    try {
      final res = await _dio.post(
        ApiConstants.family,
        data: {
          'name': name.trim(),
          'relation': relation.trim().toLowerCase(),
          'phone': phone?.trim(),
        },
      );
      final data = res.data as Map<String, dynamic>;
      return FamilyMemberModel.fromJson(data['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      final msg =
          e.response?.data is Map ? (e.response?.data as Map)['message'] : null;
      throw Exception(msg ?? 'Gagal menambah anggota keluarga');
    }
  }

  Future<void> deleteFamilyMember(int id) async {
    try {
      await _dio.delete(ApiConstants.familyDetail(id));
    } on DioException catch (e) {
      final msg =
          e.response?.data is Map ? (e.response?.data as Map)['message'] : null;
      throw Exception(msg ?? 'Gagal menghapus anggota keluarga');
    }
  }

  Future<VehicleModel> addVehicle({
    required String plateNumber,
    required String vehicleType,
    String? brandModel,
  }) async {
    try {
      final res = await _dio.post(
        ApiConstants.vehicles,
        data: {
          'plate_number': plateNumber.trim().toUpperCase(),
          'vehicle_type': vehicleType.trim().toLowerCase(),
          'brand_model': brandModel?.trim(),
        },
      );
      final data = res.data as Map<String, dynamic>;
      return VehicleModel.fromJson(data['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      final msg =
          e.response?.data is Map ? (e.response?.data as Map)['message'] : null;
      throw Exception(msg ?? 'Gagal mendaftarkan kendaraan');
    }
  }

  Future<void> deleteVehicle(int id) async {
    try {
      await _dio.delete(ApiConstants.vehicleDetail(id));
    } on DioException catch (e) {
      final msg =
          e.response?.data is Map ? (e.response?.data as Map)['message'] : null;
      throw Exception(msg ?? 'Gagal menghapus kendaraan');
    }
  }
}
