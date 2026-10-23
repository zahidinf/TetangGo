import 'package:flutter/foundation.dart';

class ApiConstants {
  // Base URL configuration:
  // - Supports --dart-define=API_URL=http://<IP>:8000 when running/building
  // - If running on web: localhost:8000
  // - If running on Android/iOS: defaults to Wi-Fi IP or localhost (with adb reverse)
  static const String _defaultUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: '',
  );

  static String get baseUrl {
    if (_defaultUrl.isNotEmpty) {
      return _defaultUrl;
    }
    if (kIsWeb) {
      return 'http://localhost:8000';
    }
    // Android device
    if (defaultTargetPlatform == TargetPlatform.android) {
      // Both http://localhost:8000 (via adb reverse) and http://192.168.18.178:8000 work.
      // Use localhost:8000 with adb reverse for zero-firewall friction on Wireless Debugging.
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
  static String adminAssignRole(int id) => '/api/v1/admin/users/$id/role';
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
  static const String adminEligibleResidents = '/api/v1/admin/bills/eligible-residents';
  static const String adminResidentPeriods = '/api/v1/admin/bills/resident-periods';
  static const String adminRecordCash = '/api/v1/admin/bills/record-cash';
  static const String adminBulkPay = '/api/v1/admin/bills/bulk-pay';

  static const String residentBills = '/api/v1/resident/bills';
  static const String residentInitiateBill = '/api/v1/resident/bills/initiate';
  static String residentBillDetail(int id) => '/api/v1/resident/bills/$id';
  static String residentPayBill(int id) => '/api/v1/resident/bills/$id/pay';

  // Sprint 3: Cashbook Endpoints
  static const String cashbookSummary = '/api/v1/cashbook/summary';
  static const String cashbookTransactions = '/api/v1/cashbook/transactions';
  static const String adminCashbookTransactions = '/api/v1/admin/cashbook/transactions';
  static String adminDeleteCashbookTransaction(int id) => '/api/v1/admin/cashbook/transactions/$id';

  // Sprint 3: Announcements Endpoints
  static const String announcements = '/api/v1/announcements';
  static String announcementDetail(int id) => '/api/v1/announcements/$id';
  static const String adminAnnouncements = '/api/v1/admin/announcements';
  static String adminAnnouncementDetail(int id) => '/api/v1/admin/announcements/$id';

  // Storage Keys
  static const String tokenKey = 'tetanggo_access_token';
  static const String refreshTokenKey = 'tetanggo_refresh_token';
  static const String userKey = 'tetanggo_user_data';
}
