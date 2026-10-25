import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tetanggo_frontend/features/auth/domain/models/user_model.dart';
import 'package:tetanggo_frontend/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:tetanggo_frontend/features/auth/presentation/bloc/auth_state.dart';
import 'package:tetanggo_frontend/features/home/presentation/widgets/dashboard_sidebar.dart';
import 'package:tetanggo_frontend/features/security/data/security_repository.dart';
import 'package:tetanggo_frontend/features/security/domain/models/security_models.dart';
import 'package:tetanggo_frontend/features/security/presentation/security_management_view.dart';
import 'package:tetanggo_frontend/features/security/presentation/widgets/add_security_dialog.dart';
import 'package:tetanggo_frontend/features/security/presentation/widgets/security_assignment_dialog.dart';

class MockSecurityRepository extends Fake implements SecurityRepository {
  List<SecurityUserModel> usersToReturn = [];
  List<SecurityAssignmentModel> assignmentsToReturn = [];
  List<NeighborhoodModel> neighborhoodsToReturn = [];

  bool createSecurityUserCalled = false;
  String? createdName;
  String? createdPhone;
  String? createdEmail;

  bool setStatusCalled = false;
  int? statusTargetId;
  String? newStatusVal;

  bool createAssignmentCalled = false;
  int? assignTargetUserId;
  int? assignTargetNeighborhoodId;

  bool revokeAssignmentCalled = false;
  int? revokeTargetAssignmentId;

  @override
  Future<List<SecurityUserModel>> getAdminSecurityUsers() async {
    return usersToReturn;
  }

  @override
  Future<List<SecurityAssignmentModel>> getAdminAssignments({
    int? userId,
    int? neighborhoodId,
    bool? activeOnly,
  }) async {
    if (userId != null) {
      return assignmentsToReturn.where((a) => a.userId == userId).toList();
    }
    return assignmentsToReturn;
  }

  @override
  Future<List<NeighborhoodModel>> getAdminNeighborhoods() async {
    return neighborhoodsToReturn;
  }

  @override
  Future<SecurityUserModel> createSecurityUser({
    required String name,
    required String phone,
    required String email,
    required String password,
    String salutation = 'Bapak',
  }) async {
    createSecurityUserCalled = true;
    createdName = name;
    createdPhone = phone;
    createdEmail = email;
    final newUser = SecurityUserModel(
      id: 999,
      salutation: salutation,
      name: name,
      phone: phone,
      email: email,
      role: 'SECURITY',
      status: 'active',
      houseId: null, // strictly null
      createdAt: DateTime.now(),
    );
    usersToReturn.add(newUser);
    return newUser;
  }

  @override
  Future<void> setSecurityUserStatus(int userId, String status) async {
    setStatusCalled = true;
    statusTargetId = userId;
    newStatusVal = status;
    final idx = usersToReturn.indexWhere((u) => u.id == userId);
    if (idx != -1) {
      usersToReturn[idx] = usersToReturn[idx].copyWith(status: status);
    }
  }

  @override
  Future<SecurityAssignmentModel> createSecurityAssignment({
    required int userId,
    required int neighborhoodId,
    String? notes,
  }) async {
    createAssignmentCalled = true;
    assignTargetUserId = userId;
    assignTargetNeighborhoodId = neighborhoodId;
    final n = neighborhoodsToReturn.firstWhere(
      (n) => n.id == neighborhoodId,
      orElse: () => const NeighborhoodModel(id: 1, name: 'Lingkungan 1'),
    );
    final assign = SecurityAssignmentModel(
      id: 501,
      userId: userId,
      neighborhoodId: neighborhoodId,
      neighborhoodName: n.name,
      neighborhoodCode: n.code,
      isActive: true,
      notes: notes ?? '',
      assignedAt: DateTime.now(),
    );
    assignmentsToReturn.add(assign);
    return assign;
  }

  @override
  Future<void> revokeSecurityAssignment(int assignmentId,
      {String? notes}) async {
    revokeAssignmentCalled = true;
    revokeTargetAssignmentId = assignmentId;
    final idx = assignmentsToReturn.indexWhere((a) => a.id == assignmentId);
    if (idx != -1) {
      final old = assignmentsToReturn[idx];
      assignmentsToReturn[idx] = SecurityAssignmentModel(
        id: old.id,
        userId: old.userId,
        neighborhoodId: old.neighborhoodId,
        neighborhoodName: old.neighborhoodName,
        neighborhoodCode: old.neighborhoodCode,
        isActive: false,
        notes: notes ?? old.notes,
        assignedAt: old.assignedAt,
        revokedAt: DateTime.now(),
      );
    }
  }
}

class FakeAuthBloc extends Fake implements AuthBloc {
  final UserModel currentUser;
  FakeAuthBloc(this.currentUser);

  @override
  AuthState get state => AuthState(
        status: AuthStatus.authenticated,
        user: currentUser,
      );

  @override
  Stream<AuthState> get stream => const Stream.empty();
}

void main() {
  group('Security Management RBAC & Navigation Tests', () {
    test(
        '1. Admin, Chairperson, and Vice Chairperson see "security_management" in navigation items',
        () {
      const admin = UserModel(
        id: 1,
        name: 'Admin TetangGo',
        email: 'admin@tetanggo.id',
        phone: '08111111111',
        roleId: 1,
        role: 'ADMIN',
        status: 'active',
      );
      const ketua = UserModel(
        id: 2,
        name: 'Ketua Lingkungan',
        email: 'ketua@tetanggo.id',
        phone: '08122222222',
        roleId: 2,
        role: 'CHAIRPERSON',
        status: 'active',
      );
      const wakil = UserModel(
        id: 3,
        name: 'Wakil Ketua',
        email: 'wakil@tetanggo.id',
        phone: '08133333333',
        roleId: 3,
        role: 'VICE_CHAIRPERSON',
        status: 'active',
      );

      final adminKeys = NavigationItemBuilder.buildNavigationItems(admin)
          .map((i) => i.keyId)
          .toList();
      final ketuaKeys = NavigationItemBuilder.buildNavigationItems(ketua)
          .map((i) => i.keyId)
          .toList();
      final wakilKeys = NavigationItemBuilder.buildNavigationItems(wakil)
          .map((i) => i.keyId)
          .toList();

      expect(adminKeys, contains('security_management'));
      expect(ketuaKeys, contains('security_management'));
      expect(wakilKeys, contains('security_management'));
    });

    test(
        '2. Treasurer, Secretary, Resident, and Security DO NOT see "security_management" in navigation items',
        () {
      const treasurer = UserModel(
        id: 4,
        name: 'Bendahara',
        email: 'bendahara@tetanggo.id',
        phone: '08144444444',
        roleId: 4,
        role: 'TREASURER',
        status: 'active',
      );
      const secretary = UserModel(
        id: 5,
        name: 'Sekretaris',
        email: 'sekretaris@tetanggo.id',
        phone: '08155555555',
        roleId: 5,
        role: 'SECRETARY',
        status: 'active',
      );
      const resident = UserModel(
        id: 6,
        name: 'Warga',
        email: 'warga@tetanggo.id',
        phone: '08166666666',
        roleId: 6,
        role: 'RESIDENT',
        status: 'active',
      );
      const security = UserModel(
        id: 7,
        name: 'Petugas Satpam',
        email: 'satpam@tetanggo.id',
        phone: '08177777777',
        roleId: 7,
        role: 'SECURITY',
        status: 'active',
      );

      final treasurerKeys =
          NavigationItemBuilder.buildNavigationItems(treasurer)
              .map((i) => i.keyId)
              .toList();
      final secretaryKeys =
          NavigationItemBuilder.buildNavigationItems(secretary)
              .map((i) => i.keyId)
              .toList();
      final residentKeys = NavigationItemBuilder.buildNavigationItems(resident)
          .map((i) => i.keyId)
          .toList();
      final securityKeys = NavigationItemBuilder.buildNavigationItems(security)
          .map((i) => i.keyId)
          .toList();

      expect(treasurerKeys, isNot(contains('security_management')));
      expect(secretaryKeys, isNot(contains('security_management')));
      expect(residentKeys, isNot(contains('security_management')));
      expect(securityKeys, isNot(contains('security_management')));
    });
  });

  group('SecurityManagementView Widget Tests', () {
    late MockSecurityRepository mockRepo;
    late UserModel chairpersonUser;

    setUp(() {
      mockRepo = MockSecurityRepository();
      chairpersonUser = const UserModel(
        id: 2,
        name: 'Ketua Lingkungan',
        email: 'ketua@tetanggo.id',
        phone: '08122222222',
        roleId: 2,
        role: 'CHAIRPERSON',
        status: 'active',
      );

      mockRepo.neighborhoodsToReturn = [
        const NeighborhoodModel(
            id: 1, name: 'Lingkungan TetangGo 01', code: 'RT01-DEFAULT'),
        const NeighborhoodModel(
            id: 2, name: 'Lingkungan TetangGo 02', code: 'RT02-EAST'),
      ];

      mockRepo.usersToReturn = [
        const SecurityUserModel(
          id: 101,
          salutation: 'Bapak',
          name: 'Slamet Satpam',
          phone: '08123456789',
          email: 'slamet@satpam.id',
          role: 'SECURITY',
          status: 'active',
          houseId: null,
        ),
        const SecurityUserModel(
          id: 102,
          salutation: 'Bapak',
          name: 'Joko Satpam',
          phone: '08129876543',
          email: 'joko@satpam.id',
          role: 'SECURITY',
          status: 'inactive',
          houseId: null,
        ),
      ];

      mockRepo.assignmentsToReturn = [
        const SecurityAssignmentModel(
          id: 1,
          userId: 101,
          neighborhoodId: 1,
          neighborhoodName: 'Lingkungan TetangGo 01',
          neighborhoodCode: 'RT01-DEFAULT',
          isActive: true,
        ),
      ];
    });

    testWidgets('1. Renders summary statistics and guard table with real data',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MultiRepositoryProvider(
          providers: [
            RepositoryProvider<SecurityRepository>.value(value: mockRepo),
          ],
          child: MultiBlocProvider(
            providers: [
              BlocProvider<AuthBloc>.value(
                  value: FakeAuthBloc(chairpersonUser)),
            ],
            child: const MaterialApp(
              home: Scaffold(
                body: SecurityManagementView(),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Title & Subtitle
      expect(find.text('Manajemen Petugas Keamanan (Satpam)'), findsOneWidget);
      expect(find.text('+ Tambah Satpam Baru'), findsOneWidget);

      // Summary counts
      expect(find.text('Total Akun Satpam'), findsOneWidget);
      expect(find.text('2'), findsWidgets); // Total: 2
      expect(find.text('Satpam Aktif'), findsOneWidget);
      expect(
          find.text('1'), findsWidgets); // Aktif: 1, Nonaktif: 1, Penugasan: 1

      // Guard rows
      expect(find.text('Bapak Slamet Satpam'), findsOneWidget);
      expect(find.text('08123456789'), findsOneWidget);
      expect(find.text('slamet@satpam.id'), findsOneWidget);
      expect(find.text('Aktif'), findsWidgets);
      expect(find.text('Lingkungan TetangGo 01'), findsOneWidget);

      expect(find.text('Bapak Joko Satpam'), findsOneWidget);
      expect(find.text('08129876543'), findsOneWidget);
      expect(find.text('Belum Ditugaskan'), findsOneWidget);
      expect(find.text('Non-Aktif'), findsWidgets);
    });

    testWidgets('2. Search filter correctly filters guards by name',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MultiRepositoryProvider(
          providers: [
            RepositoryProvider<SecurityRepository>.value(value: mockRepo),
          ],
          child: MultiBlocProvider(
            providers: [
              BlocProvider<AuthBloc>.value(
                  value: FakeAuthBloc(chairpersonUser)),
            ],
            child: const MaterialApp(
              home: Scaffold(
                body: SecurityManagementView(),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Enter search query "Joko"
      final searchField = find.byType(TextField).first;
      await tester.enterText(searchField, 'Joko');
      await tester.pumpAndSettle();

      expect(find.text('Bapak Joko Satpam'), findsOneWidget);
      expect(find.text('Bapak Slamet Satpam'), findsNothing);
    });

    testWidgets('3. Toggle status shows confirmation dialog and updates status',
        (tester) async {
      tester.view.physicalSize = const Size(1600, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MultiRepositoryProvider(
          providers: [
            RepositoryProvider<SecurityRepository>.value(value: mockRepo),
          ],
          child: MultiBlocProvider(
            providers: [
              BlocProvider<AuthBloc>.value(
                  value: FakeAuthBloc(chairpersonUser)),
            ],
            child: const MaterialApp(
              home: Scaffold(
                body: SecurityManagementView(),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Click toggle on Slamet Satpam (active -> nonaktifkan)
      final toggleButton = find.byIcon(Icons.toggle_on_rounded).first;
      await tester.ensureVisible(toggleButton);
      await tester.pumpAndSettle();
      await tester.tap(toggleButton);
      await tester.pumpAndSettle();

      // Confirmation dialog opens
      expect(find.text('Nonaktifkan Akun Satpam'), findsOneWidget);
      expect(find.text('Batal'), findsOneWidget);
      final confirmBtn = find.widgetWithText(ElevatedButton, 'Nonaktifkan');
      expect(confirmBtn, findsOneWidget);

      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();

      expect(mockRepo.setStatusCalled, isTrue);
      expect(mockRepo.statusTargetId, 101);
      expect(mockRepo.newStatusVal, 'inactive');
    });

    testWidgets(
        '4. AddSecurityDialog creates independent security user without housing requirement',
        (tester) async {
      bool onSavedCalled = false;

      await tester.pumpWidget(
        MultiRepositoryProvider(
          providers: [
            RepositoryProvider<SecurityRepository>.value(value: mockRepo),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: AddSecurityDialog(
                onSaved: () => onSavedCalled = true,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check title and absence of housing input
      expect(find.text('Tambah Petugas Keamanan Baru'), findsOneWidget);
      expect(
          find.textContaining('tidak mewajibkan data hunian'), findsOneWidget);
      expect(find.text('Hunian (Kavling / Nomor Rumah)'), findsNothing);
      expect(find.text('Blok'), findsNothing);

      // Fill form
      final textFields = find.byType(TextFormField);
      expect(textFields, findsNWidgets(4)); // Name, Phone, Email, Password

      await tester.enterText(textFields.at(0), 'Agus Security');
      await tester.enterText(textFields.at(1), '081233445566');
      await tester.enterText(textFields.at(2), 'agus.satpam@tetanggo.id');
      await tester.enterText(textFields.at(3), 'secure123');
      await tester.pumpAndSettle();

      // Submit
      final saveBtn =
          find.widgetWithText(ElevatedButton, 'Simpan Petugas Satpam');
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      expect(mockRepo.createSecurityUserCalled, isTrue);
      expect(mockRepo.createdName, 'Agus Security');
      expect(mockRepo.createdPhone, '081233445566');
      expect(mockRepo.createdEmail, 'agus.satpam@tetanggo.id');
      expect(onSavedCalled, isTrue);
    });

    testWidgets(
        '5. SecurityAssignmentDialog allows assigning and revoking assignments',
        (tester) async {
      bool updatedCalled = false;
      final targetUser =
          mockRepo.usersToReturn.first; // Slamet Satpam (has assignment 1)

      await tester.pumpWidget(
        MultiRepositoryProvider(
          providers: [
            RepositoryProvider<SecurityRepository>.value(value: mockRepo),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SecurityAssignmentDialog(
                user: targetUser,
                onUpdated: () => updatedCalled = true,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Displays guard name and current active assignment
      expect(find.text('Atur Penugasan: Bapak Slamet Satpam'), findsOneWidget);
      expect(find.text('Lingkungan TetangGo 01'), findsOneWidget);
      expect(find.text('Cabut'), findsOneWidget);

      // Available neighborhood 2 can be assigned
      expect(find.text('Tugaskan ke Lingkungan'), findsOneWidget);
      await tester.tap(find.text('Tugaskan ke Lingkungan'));
      await tester.pumpAndSettle();

      expect(mockRepo.createAssignmentCalled, isTrue);
      expect(mockRepo.assignTargetUserId, 101);
      expect(mockRepo.assignTargetNeighborhoodId, 2);
      expect(updatedCalled, isTrue);

      // Revoke assignment
      await tester.tap(find.text('Cabut').first);
      await tester.pumpAndSettle();

      expect(find.text('Cabut Penugasan Satpam'), findsOneWidget);
      final confirmRevokeBtn =
          find.widgetWithText(ElevatedButton, 'Cabut Penugasan');
      await tester.tap(confirmRevokeBtn);
      await tester.pumpAndSettle();

      expect(mockRepo.revokeAssignmentCalled, isTrue);
      expect(mockRepo.revokeTargetAssignmentId, 1);
    });
  });
}
