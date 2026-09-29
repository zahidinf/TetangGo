import 'package:flutter/foundation.dart';

class ApiConstants {
  // Web uses localhost, Android emulator uses 10.0.2.2, iOS simulator uses localhost
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:8000';
    }
    // Android device with adb reverse tcp:8000 tcp:8000 or emulator
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://localhost:8000';
    }
    return 'http://localhost:8000';
  }

  // Endpoints
  static const String health = '/health';
  static const String login = '/api/v1/auth/login';
  static const String register = '/api/v1/auth/register';
  static const String housesAvailable = '/api/v1/public/houses-available';
  
  // Admin Endpoints
  static const String adminDashboardStats = '/api/v1/admin/dashboard/stats';
  static const String adminUsers = '/api/v1/admin/users';
  static String adminUserDetail(int id) => '/api/v1/admin/users/$id';
  static String adminResetPassword(int id) => '/api/v1/admin/users/$id/reset-password';
  static const String pendingUsers = '/api/v1/admin/pending-users';
  static String approveUser(int id) => '/api/v1/admin/users/$id/approve';
  static String rejectUser(int id) => '/api/v1/admin/users/$id/reject';
  static String houseOccupants(int id) => '/api/v1/admin/houses/$id/occupants';
  static String houseDetails(int id) => '/api/v1/admin/houses/$id/details';
  static const String unassignedResidents = '/api/v1/admin/unassigned-residents';
  static String assignResident(int id) => '/api/v1/admin/houses/$id/assign-resident';
  static String removeResident(int houseId, int userId) => '/api/v1/admin/houses/$houseId/remove-resident/$userId';
  static String transferHouse(int userId) => '/api/v1/admin/users/$userId/transfer-house';
  static String adminHouseFamily(int houseId) => '/api/v1/admin/houses/$houseId/family';
  static String adminDeleteHouseFamily(int houseId, int familyId) => '/api/v1/admin/houses/$houseId/family/$familyId';
  static String adminHouseVehicles(int houseId) => '/api/v1/admin/houses/$houseId/vehicles';
  static String adminDeleteHouseVehicle(int houseId, int vehicleId) => '/api/v1/admin/houses/$houseId/vehicles/$vehicleId';
  static const String bulkDeleteHouses = '/api/v1/admin/houses/bulk-delete';
  
  // Houses Endpoints
  static const String houses = '/api/v1/houses';
  static const String houseBlocks = '/api/v1/houses/blocks';
  static String houseDetail(int id) => '/api/v1/houses/$id';

  // Profile Endpoints
  static const String profile = '/api/v1/profile';
  static const String family = '/api/v1/profile/family';
  static String familyDetail(int id) => '/api/v1/profile/family/$id';
  static const String vehicles = '/api/v1/profile/vehicles';
  static String vehicleDetail(int id) => '/api/v1/profile/vehicles/$id';

  // Sprint 2: Billing & Payment Endpoints
  static const String paymentSettings = '/api/v1/payment-settings';
  static const String adminPaymentSettings = '/api/v1/admin/payment-settings';
  static const String adminGenerateBills = '/api/v1/admin/bills/generate';
  static const String adminPendingBills = '/api/v1/admin/bills/pending';
  static String adminVerifyBill(int id) => '/api/v1/admin/bills/$id/verify';
  static const String adminBillsSummary = '/api/v1/admin/bills/summary';

  static const String residentBills = '/api/v1/resident/bills';
  static const String residentInitiateBill = '/api/v1/resident/bills/initiate';
  static String residentBillDetail(int id) => '/api/v1/resident/bills/$id';
  static String residentPayBill(int id) => '/api/v1/resident/bills/$id/pay';

  // Storage Keys
  static const String tokenKey = 'tetanggo_access_token';
  static const String refreshTokenKey = 'tetanggo_refresh_token';
  static const String userKey = 'tetanggo_user_data';
}
