import 'package:flutter_test/flutter_test.dart';
import 'package:tetanggo_frontend/features/auth/domain/models/user_model.dart';
import 'package:tetanggo_frontend/features/home/presentation/widgets/dashboard_sidebar.dart';

void main() {
  group('RBAC Navigation and Housing-based Iuran Tests', () {
    test('1. RESIDENT with housing association gets resident menus and resident billing', () {
      const user = UserModel(
        id: 10,
        name: 'Warga Berumah',
        email: 'warga@tetanggo.id',
        phone: '08123456789',
        roleId: 6,
        role: 'RESIDENT',
        status: 'active',
        houseId: 101,
        houseBlock: 'A',
        houseNumber: '1',
      );

      expect(user.hasHousingAssociation, isTrue);
      expect(user.canAccessResidentIuran, isTrue);
      expect(user.hasAdminAccess, isFalse);

      final items = NavigationItemBuilder.buildNavigationItems(user);
      final keys = items.map((it) => it.keyId).toList();

      expect(keys, contains('dashboard'));
      expect(keys, contains('profile'));
      expect(keys, contains('resident_billing'));
      expect(keys, contains('cashbook'));
      expect(keys, contains('announcements'));
      expect(keys, contains('panic'));

      // No administrative modules
      expect(keys, isNot(contains('verification')));
      expect(keys, isNot(contains('houses')));
      expect(keys, isNot(contains('billing')));
      expect(keys, isNot(contains('guestbook')));
    });

    test('2. RESIDENT without housing association does NOT get resident billing', () {
      const user = UserModel(
        id: 11,
        name: 'Warga Tanpa Rumah',
        email: 'wargano@tetanggo.id',
        phone: '08123456788',
        roleId: 6,
        role: 'RESIDENT',
        status: 'active',
        houseId: null,
      );

      expect(user.hasHousingAssociation, isFalse);
      expect(user.canAccessResidentIuran, isFalse);

      final items = NavigationItemBuilder.buildNavigationItems(user);
      final keys = items.map((it) => it.keyId).toList();

      expect(keys, contains('dashboard'));
      expect(keys, contains('profile'));
      expect(keys, contains('cashbook'));
      expect(keys, contains('announcements'));
      expect(keys, contains('panic'));

      // Resident billing must NOT be available without housing
      expect(keys, isNot(contains('resident_billing')));
    });

    test('3. CHAIRPERSON with housing association gets resident menus + all chairperson admin menus', () {
      const user = UserModel(
        id: 2,
        name: 'Ketua RT',
        email: 'ketua@tetanggo.id',
        phone: '08123456781',
        roleId: 2,
        role: 'CHAIRPERSON',
        status: 'active',
        houseId: 102,
        houseBlock: 'B',
        houseNumber: '2',
      );

      expect(user.hasHousingAssociation, isTrue);
      expect(user.canAccessResidentIuran, isTrue);
      expect(user.canAccessLeadership, isTrue);
      expect(user.canAccessBillingAdmin, isTrue);
      expect(user.canAccessVerificationAdmin, isTrue);
      expect(user.canAccessHousesAdmin, isTrue);
      expect(user.canAccessSecurityGuestbookAdmin, isTrue);

      final items = NavigationItemBuilder.buildNavigationItems(user);
      final keys = items.map((it) => it.keyId).toList();

      // Resident menus preserved
      expect(keys, contains('dashboard'));
      expect(keys, contains('profile'));
      expect(keys, contains('resident_billing'));
      expect(keys, contains('cashbook'));
      expect(keys, contains('announcements'));
      expect(keys, contains('panic'));

      // Administrative menus granted
      expect(keys, contains('verification'));
      expect(keys, contains('houses'));
      expect(keys, contains('billing'));
      expect(keys, contains('guestbook'));
    });

    test('4. VICE_CHAIRPERSON has same access as CHAIRPERSON', () {
      const user = UserModel(
        id: 3,
        name: 'Wakil Ketua RT',
        email: 'wakil@tetanggo.id',
        phone: '08123456782',
        roleId: 3,
        role: 'VICE_CHAIRPERSON',
        status: 'active',
        houseId: 103,
      );

      final items = NavigationItemBuilder.buildNavigationItems(user);
      final keys = items.map((it) => it.keyId).toList();

      expect(keys, contains('dashboard'));
      expect(keys, contains('verification'));
      expect(keys, contains('houses'));
      expect(keys, contains('profile'));
      expect(keys, contains('billing'));
      expect(keys, contains('resident_billing'));
      expect(keys, contains('cashbook'));
      expect(keys, contains('announcements'));
      expect(keys, contains('panic'));
      expect(keys, contains('guestbook'));
    });

    test('5. TREASURER with housing gets resident menus + billing admin only', () {
      const user = UserModel(
        id: 4,
        name: 'Bendahara RT',
        email: 'bendahara@tetanggo.id',
        phone: '08123456783',
        roleId: 4,
        role: 'TREASURER',
        status: 'active',
        houseId: 104,
      );

      expect(user.hasHousingAssociation, isTrue);
      expect(user.canAccessResidentIuran, isTrue);
      expect(user.canAccessBillingAdmin, isTrue);
      expect(user.canAccessCashbookAdmin, isTrue);
      expect(user.canAccessVerificationAdmin, isFalse);
      expect(user.canAccessHousesAdmin, isFalse);
      expect(user.canAccessSecurityGuestbookAdmin, isFalse);

      final items = NavigationItemBuilder.buildNavigationItems(user);
      final keys = items.map((it) => it.keyId).toList();

      // Resident menus preserved
      expect(keys, contains('dashboard'));
      expect(keys, contains('profile'));
      expect(keys, contains('resident_billing'));
      expect(keys, contains('cashbook'));
      expect(keys, contains('announcements'));
      expect(keys, contains('panic'));

      // Authorized admin menu
      expect(keys, contains('billing'));

      // Unauthorized admin menus DENIED
      expect(keys, isNot(contains('verification')));
      expect(keys, isNot(contains('houses')));
      expect(keys, isNot(contains('guestbook')));
    });

    test('6. SECRETARY with housing gets resident menus + verification, houses, guestbook admin', () {
      const user = UserModel(
        id: 5,
        name: 'Sekretaris RT',
        email: 'sekretaris@tetanggo.id',
        phone: '08123456784',
        roleId: 5,
        role: 'SECRETARY',
        status: 'active',
        houseId: 105,
      );

      expect(user.hasHousingAssociation, isTrue);
      expect(user.canAccessResidentIuran, isTrue);
      expect(user.canAccessBillingAdmin, isFalse);
      expect(user.canAccessCashbookAdmin, isFalse);
      expect(user.canAccessVerificationAdmin, isTrue);
      expect(user.canAccessHousesAdmin, isTrue);
      expect(user.canAccessSecurityGuestbookAdmin, isTrue);

      final items = NavigationItemBuilder.buildNavigationItems(user);
      final keys = items.map((it) => it.keyId).toList();

      // Resident menus preserved (including transparent cashbook and resident dues)
      expect(keys, contains('dashboard'));
      expect(keys, contains('profile'));
      expect(keys, contains('resident_billing'));
      expect(keys, contains('cashbook'));
      expect(keys, contains('announcements'));
      expect(keys, contains('panic'));

      // Authorized admin menus
      expect(keys, contains('verification'));
      expect(keys, contains('houses'));
      expect(keys, contains('guestbook'));

      // Unauthorized admin billing DENIED
      expect(keys, isNot(contains('billing')));
    });

    test('7. ADMIN with housing gets all admin menus + resident billing', () {
      const user = UserModel(
        id: 1,
        name: 'Admin TetangGo',
        email: 'admin@tetanggo.id',
        phone: '08123456780',
        roleId: 1,
        role: 'ADMIN',
        status: 'active',
        houseId: 100,
      );

      expect(user.canAccessResidentIuran, isTrue);
      final items = NavigationItemBuilder.buildNavigationItems(user);
      final keys = items.map((it) => it.keyId).toList();

      expect(keys, contains('resident_billing'));
      expect(keys, contains('billing'));
      expect(keys, contains('verification'));
      expect(keys, contains('houses'));
      expect(keys, contains('guestbook'));
    });

    test('8. ADMIN without housing does NOT get resident billing', () {
      const user = UserModel(
        id: 1,
        name: 'Admin TetangGo',
        email: 'admin@tetanggo.id',
        phone: '08123456780',
        roleId: 1,
        role: 'ADMIN',
        status: 'active',
        houseId: null,
      );

      expect(user.canAccessResidentIuran, isFalse);
      final items = NavigationItemBuilder.buildNavigationItems(user);
      final keys = items.map((it) => it.keyId).toList();

      expect(keys, isNot(contains('resident_billing')));
      expect(keys, contains('billing'));
    });
  });
}
