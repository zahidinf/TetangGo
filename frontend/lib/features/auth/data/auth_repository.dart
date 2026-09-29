import 'dart:convert';
import 'package:dio/dio.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/storage/secure_storage_service.dart';
import '../domain/models/user_model.dart';

class AuthRepository {
  final Dio _dio;
  final SecureStorageService _storageService;

  AuthRepository({
    required Dio dio,
    required SecureStorageService storageService,
  })  : _dio = dio,
        _storageService = storageService;

  Future<UserModel> login({
    required String identifier,
    required String password,
  }) async {
    try {
      final response = await _dio.post(
        ApiConstants.login,
        data: {
          'identifier': identifier.trim(),
          'password': password,
        },
      );

      final data = response.data as Map<String, dynamic>;
      final payload = data['data'] as Map<String, dynamic>;

      final accessToken = payload['access_token'] as String;
      final refreshToken = payload['refresh_token'] as String;
      final userJson = payload['user'] as Map<String, dynamic>;

      final user = UserModel.fromJson(userJson);

      // Persist secure tokens and cached user
      await _storageService.saveTokens(
        accessToken: accessToken,
        refreshToken: refreshToken,
      );
      await _storageService.saveUserRaw(jsonEncode(user.toJson()));

      return user;
    } on DioException catch (e) {
      if (e.response != null && e.response?.data is Map) {
        final message = (e.response?.data as Map)['message'] as String?;
        throw Exception(message ?? 'Gagal login, periksa koneksi server');
      }
      throw Exception('Tidak dapat terhubung ke server TetangGo');
    }
  }

  Future<UserModel> register({
    required String name,
    required String phone,
    required String email,
    required String password,
    required int houseId,
    required String ownershipStatus,
  }) async {
    try {
      final response = await _dio.post(
        ApiConstants.register,
        data: {
          'name': name.trim(),
          'phone': phone.trim(),
          'email': email.trim(),
          'password': password,
          'house_id': houseId,
          'ownership_status': ownershipStatus,
        },
      );

      final data = response.data as Map<String, dynamic>;
      final userJson = data['data'] as Map<String, dynamic>;
      return UserModel.fromJson(userJson);
    } on DioException catch (e) {
      if (e.response != null && e.response?.data is Map) {
        final message = (e.response?.data as Map)['message'] as String?;
        throw Exception(message ?? 'Gagal mendaftar');
      }
      throw Exception('Tidak dapat terhubung ke server TetangGo');
    }
  }

  Future<UserModel?> checkCurrentUser() async {
    final token = await _storageService.getAccessToken();
    if (token == null || token.isEmpty) {
      return null;
    }

    try {
      final response = await _dio.get(ApiConstants.profile);
      final data = response.data as Map<String, dynamic>;
      final profilePayload = data['data'] as Map<String, dynamic>;
      final userJson = profilePayload['user'] as Map<String, dynamic>;
      final user = UserModel.fromJson(userJson);

      // Update cached user
      await _storageService.saveUserRaw(jsonEncode(user.toJson()));
      return user;
    } catch (_) {
      // Fallback local cache
      final rawUser = await _storageService.getUserRaw();
      if (rawUser != null && rawUser.isNotEmpty) {
        try {
          return UserModel.fromJson(jsonDecode(rawUser) as Map<String, dynamic>);
        } catch (_) {}
      }
      await logout();
      return null;
    }
  }

  Future<void> logout() async {
    await _storageService.clearAll();
  }
}
