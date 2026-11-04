import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tetanggo_frontend/features/auth/domain/models/user_model.dart';
import 'package:tetanggo_frontend/features/home/presentation/widgets/dashboard_sidebar.dart';
import 'package:tetanggo_frontend/features/profile/data/profile_repository.dart';
import 'package:tetanggo_frontend/features/profile/domain/models/profile_detail_model.dart';
import 'package:tetanggo_frontend/features/resident_management/data/resident_repository.dart';
import 'package:tetanggo_frontend/features/resident_management/domain/models/house_model.dart';
import 'package:tetanggo_frontend/features/resident_management/domain/models/pending_user_model.dart';
import 'package:tetanggo_frontend/features/resident_management/presentation/manajemen_hunian_warga_screen.dart';

class FakeResidentRepository extends ResidentRepository {
  FakeResidentRepository() : super(dio: Dio());

  @override
  Future<List<PendingUserModel>> getPendingUsers() async => [];

  @override
  Future<List<HouseModel>> getHouses({String? block, String? status, String? search}) async => [];

  @override
  Future<List<String>> getHouseBlocks() async => ['A', 'B'];
}

class FakeProfileRepository extends ProfileRepository {
  FakeProfileRepository() : super(dio: Dio());

  @override
  Future<ProfileDetailModel> getProfile() async {
    return const ProfileDetailModel(
      user: UserModel(
        id: 1,
        name: 'Ketua RT',
        phone: '081234567890',
        email: 'ketua@tetanggo.id',
        role: 'CHAIRPERSON',
        roleId: 2,
        status: 'active',
        houseId: 101,
      ),
      house: null,
      familyMembers: [],
      vehicles: [],
    );
  }
}

void main() {
  group('US: Konsolidasi Menu Manajemen Hunian & Warga', () {
    test('1. Role with all 3 features (ADMIN, CHAIRPERSON, VICE_CHAIRPERSON, SECRETARY) gets consolidated menu', () {
      final multiRoles = ['ADMIN', 'CHAIRPERSON', 'VICE_CHAIRPERSON', 'SECRETARY'];

      for (final role in multiRoles) {
        final user = UserModel(
          id: 1,
          name: 'User $role',
          email: '$role@tetanggo.id',
          phone: '081234567890',
          role: role,
          roleId: 1,
          status: 'active',
          houseId: 101,
        );

        expect(user.canAccessVerificationAdmin, isTrue);
        expect(user.canAccessHousesAdmin, isTrue);

        final items = NavigationItemBuilder.buildNavigationItems(user);
        final keys = items.map((it) => it.keyId).toList();

        expect(keys, contains('resident_management'), reason: '$role must have resident_management');
        expect(keys, isNot(contains('verification')), reason: '$role must not have separate verification');
        expect(keys, isNot(contains('houses')), reason: '$role must not have separate houses');
        expect(keys, isNot(contains('profile')), reason: '$role must not have separate profile');

        final item = items.firstWhere((it) => it.keyId == 'resident_management');
        expect(item.title, equals('Manajemen Hunian & Warga'));
      }
    });

    test('2. Role with only 1 feature (RESIDENT, TREASURER) keeps standalone menu and no consolidated menu', () {
      final singleRoles = ['RESIDENT', 'TREASURER'];

      for (final role in singleRoles) {
        final user = UserModel(
          id: 2,
          name: 'User $role',
          email: '$role@tetanggo.id',
          phone: '081234567891',
          role: role,
          roleId: 6,
          status: 'active',
          houseId: 101,
        );

        expect(user.canAccessVerificationAdmin, isFalse);
        expect(user.canAccessHousesAdmin, isFalse);

        final items = NavigationItemBuilder.buildNavigationItems(user);
        final keys = items.map((it) => it.keyId).toList();

        expect(keys, isNot(contains('resident_management')), reason: '$role must not have resident_management');
        expect(keys, isNot(contains('verification')), reason: '$role must not have verification');
        expect(keys, isNot(contains('houses')), reason: '$role must not have houses');
        expect(keys, contains('profile'), reason: '$role must retain standalone profile');

        final item = items.firstWhere((it) => it.keyId == 'profile');
        expect(item.title, equals('Profil Hunian & Keluarga'));
      }
    });

    testWidgets('3. ManajemenHunianWargaScreen renders 3 tabs in strict priority order for 3-access role', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const adminUser = UserModel(
        id: 1,
        name: 'Ketua RT',
        phone: '081234567890',
        email: 'ketua@tetanggo.id',
        role: 'CHAIRPERSON',
        roleId: 2,
        status: 'active',
        houseId: 101,
      );

      final residentRepo = FakeResidentRepository();
      final profileRepo = FakeProfileRepository();

      await tester.pumpWidget(
        MultiRepositoryProvider(
          providers: [
            RepositoryProvider<ResidentRepository>.value(value: residentRepo),
            RepositoryProvider<ProfileRepository>.value(value: profileRepo),
          ],
          child: const MaterialApp(
            home: ManajemenHunianWargaScreen(
              currentUser: adminUser,
              pendingCount: 3,
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Header title
      expect(find.text('Manajemen Hunian & Warga'), findsOneWidget);

      // 3 Tabs in exact order
      expect(find.text('Verifikasi Warga'), findsWidgets);
      expect(find.text('Data Hunian & Warga'), findsOneWidget);
      expect(find.text('Profil Hunian & Keluarga'), findsOneWidget);

      // Pending badge on Verifikasi Warga
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('4. ManajemenHunianWargaScreen renders only 2 tabs when user has Houses + Profile access', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Role with houses admin only (e.g. simulated user)
      const userHousesOnly = UserModel(
        id: 3,
        name: 'Pengurus Hunian',
        phone: '081234567892',
        email: 'hunian@tetanggo.id',
        role: 'SECRETARY',
        roleId: 5,
        status: 'active',
        houseId: 101,
      );

      final residentRepo = FakeResidentRepository();
      final profileRepo = FakeProfileRepository();

      await tester.pumpWidget(
        MultiRepositoryProvider(
          providers: [
            RepositoryProvider<ResidentRepository>.value(value: residentRepo),
            RepositoryProvider<ProfileRepository>.value(value: profileRepo),
          ],
          child: const MaterialApp(
            home: ManajemenHunianWargaScreen(
              currentUser: userHousesOnly,
              pendingCount: 0,
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Manajemen Hunian & Warga'), findsOneWidget);
      expect(find.text('Data Hunian & Warga'), findsOneWidget);
      expect(find.text('Profil Hunian & Keluarga'), findsOneWidget);
    });

    testWidgets('5. Tab switching and switchToTabKey works smoothly', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const adminUser = UserModel(
        id: 1,
        name: 'Ketua RT',
        phone: '081234567890',
        email: 'ketua@tetanggo.id',
        role: 'CHAIRPERSON',
        roleId: 2,
        status: 'active',
        houseId: 101,
      );

      final screenKey = GlobalKey<ManajemenHunianWargaScreenState>();
      final residentRepo = FakeResidentRepository();
      final profileRepo = FakeProfileRepository();

      await tester.pumpWidget(
        MultiRepositoryProvider(
          providers: [
            RepositoryProvider<ResidentRepository>.value(value: residentRepo),
            RepositoryProvider<ProfileRepository>.value(value: profileRepo),
          ],
          child: MaterialApp(
            home: ManajemenHunianWargaScreen(
              key: screenKey,
              currentUser: adminUser,
              pendingCount: 0,
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(screenKey.currentState?.activeTabKey, equals('verification'));

      // Switch to houses
      screenKey.currentState?.switchToTabKey('houses');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(screenKey.currentState?.activeTabKey, equals('houses'));

      // Switch to profile
      screenKey.currentState?.switchToTabKey('profile');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(screenKey.currentState?.activeTabKey, equals('profile'));
    });

    testWidgets('6. Responsive mobile view: renders on mobile screen without overflow', (tester) async {
      tester.view.physicalSize = const Size(390, 844); // iPhone 12/13/14
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const adminUser = UserModel(
        id: 1,
        name: 'Ketua RT',
        phone: '081234567890',
        email: 'ketua@tetanggo.id',
        role: 'CHAIRPERSON',
        roleId: 2,
        status: 'active',
        houseId: 101,
      );

      final residentRepo = FakeResidentRepository();
      final profileRepo = FakeProfileRepository();

      await tester.pumpWidget(
        MultiRepositoryProvider(
          providers: [
            RepositoryProvider<ResidentRepository>.value(value: residentRepo),
            RepositoryProvider<ProfileRepository>.value(value: profileRepo),
          ],
          child: const MaterialApp(
            home: ManajemenHunianWargaScreen(
              currentUser: adminUser,
              pendingCount: 2,
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Manajemen Hunian & Warga'), findsOneWidget);
      expect(find.text('Verifikasi Warga'), findsWidgets);
      expect(find.text('2'), findsOneWidget);
    });
  });
}
