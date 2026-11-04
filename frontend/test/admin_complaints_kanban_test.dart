import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:tetanggo_frontend/core/network/dio_client.dart';
import 'package:tetanggo_frontend/core/storage/secure_storage_service.dart';
import 'package:tetanggo_frontend/features/auth/domain/models/user_model.dart';
import 'package:tetanggo_frontend/features/complaint/data/repositories/complaint_repository.dart';
import 'package:tetanggo_frontend/features/complaint/domain/models/complaint_model.dart';
import 'package:tetanggo_frontend/features/complaint/presentation/bloc/admin_complaint_bloc.dart';
import 'package:tetanggo_frontend/features/complaint/presentation/bloc/admin_complaint_event.dart';
import 'package:tetanggo_frontend/features/complaint/presentation/bloc/admin_complaint_state.dart';
import 'package:tetanggo_frontend/features/complaint/presentation/bloc/complaint_bloc.dart';
import 'package:tetanggo_frontend/features/complaint/presentation/screens/admin_complaints_screen.dart';
import 'package:tetanggo_frontend/features/complaint/presentation/widgets/assign_officer_dialog.dart';
import 'package:tetanggo_frontend/features/home/presentation/widgets/dashboard_sidebar.dart';
import 'resident_complaints_test.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('id_ID', null);
  });

  UserModel createAdminUser({int? houseId = 101}) {
    return UserModel(
      id: 1,
      roleId: 1,
      salutation: 'Bpk.',
      name: 'Admin TetangGo',
      phone: '081234567890',
      email: 'admin@tetanggo.id',
      role: 'ADMIN',
      status: 'active',
      ownershipStatus: 'owner',
      houseId: houseId,
    );
  }

  group('US-5.4: Admin Complaint BLoC Tests', () {
    test('LoadKanbanComplaintsEvent groups complaints into Menunggu, Diproses, Selesai', () async {
      final fakeRepo = FakeComplaintRepository();
      fakeRepo.items.addAll([
        ComplaintModel(
          id: 1,
          ticketNumber: 'TKT-001',
          userId: 1,
          houseId: 10,
          title: 'Lampu Padam Blok A',
          description: 'Lampu jalan mati',
          category: ComplaintCategory.lampuJalan,
          status: ComplaintStatus.menunggu,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        ComplaintModel(
          id: 2,
          ticketNumber: 'TKT-002',
          userId: 1,
          houseId: 10,
          title: 'Sampah Menumpuk',
          description: 'Bau sampah',
          category: ComplaintCategory.sampah,
          status: ComplaintStatus.diproses,
          assignedOfficer: 'Pak Joko',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        ComplaintModel(
          id: 3,
          ticketNumber: 'TKT-003',
          userId: 1,
          houseId: 10,
          title: 'Jalan Rusak',
          description: 'Berlubang',
          category: ComplaintCategory.jalanan,
          status: ComplaintStatus.selesai,
          assignedOfficer: 'Pak Budi',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ]);

      final bloc = AdminComplaintBloc(repository: fakeRepo);
      bloc.add(const LoadKanbanComplaintsEvent());

      await expectLater(
        bloc.stream,
        emitsInOrder([
          predicate<AdminComplaintState>((s) => s.isLoadingKanban == true),
          predicate<AdminComplaintState>((s) {
            return s.isLoadingKanban == false &&
                s.kanbanData != null &&
                s.kanbanData!.menunggu.length == 1 &&
                s.kanbanData!.diproses.length == 1 &&
                s.kanbanData!.selesai.length == 1 &&
                s.kanbanData!.counts['Menunggu'] == 1;
          }),
        ]),
      );
    });

    test('AssignOfficerSubmittedEvent assigns officer and updates status to Diproses', () async {
      final fakeRepo = FakeComplaintRepository();
      fakeRepo.items.add(
        ComplaintModel(
          id: 1,
          ticketNumber: 'TKT-001',
          userId: 1,
          houseId: 10,
          title: 'Lampu Padam',
          description: 'Mati',
          category: ComplaintCategory.lampuJalan,
          status: ComplaintStatus.menunggu,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      final bloc = AdminComplaintBloc(repository: fakeRepo);
      bloc.add(const AssignOfficerSubmittedEvent(
        complaintId: 1,
        officerName: 'Pak Joko (Teknisi Listrik)',
        status: 'Diproses',
        notes: 'Segera cek gardu listrik',
      ));

      await expectLater(
        bloc.stream,
        emitsThrough(
          predicate<AdminComplaintState>((s) {
            return s.actionStatus == AdminComplaintActionStatus.success &&
                s.selectedComplaint?.assignedOfficer == 'Pak Joko (Teknisi Listrik)' &&
                s.selectedComplaint?.status == ComplaintStatus.diproses &&
                s.assignments.isNotEmpty;
          }),
        ),
      );
    });
  });

  group('US-5.4: Admin Complaints Multi-Platform UI Tests', () {
    testWidgets('Desktop / Web renders 3 Kanban columns: Menunggu, Dalam Pengerjaan, Selesai', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final fakeRepo = FakeComplaintRepository();
      fakeRepo.items.add(
        ComplaintModel(
          id: 1,
          ticketNumber: 'TKT-20261027-001',
          userId: 1,
          houseId: 10,
          title: 'Lampu Padam Lapangan',
          description: 'Tiang nomor 4 mati',
          category: ComplaintCategory.lampuJalan,
          status: ComplaintStatus.menunggu,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          reporterName: 'Warga Boni',
          houseBlock: 'B1',
          houseNumber: '01',
        ),
      );

      final dioClient = DioClient(storageService: SecureStorageService());

      await tester.pumpWidget(
        MultiRepositoryProvider(
          providers: [
            RepositoryProvider<ComplaintRepository>.value(value: fakeRepo),
            RepositoryProvider<DioClient>.value(value: dioClient),
          ],
          child: MaterialApp(
            home: BlocProvider(
              create: (_) => AdminComplaintBloc(repository: fakeRepo),
              child: AdminComplaintsScreen(currentUser: createAdminUser()),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify Header & Kanban columns exist
      expect(find.text('Kelola Pengaduan'), findsOneWidget);
      expect(find.text('Menunggu'), findsWidgets);
      expect(find.text('Dalam Pengerjaan'), findsWidgets);
      expect(find.text('Selesai'), findsWidgets);
      expect(find.text('Lampu Padam Lapangan'), findsOneWidget);
      expect(find.text('Belum ada petugas'), findsOneWidget);
    });

    testWidgets('Mobile screen renders TabBar responsive navigation (Semua, Menunggu, Diproses, Selesai)', (tester) async {
      tester.view.physicalSize = const Size(390, 844); // Mobile viewport
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final fakeRepo = FakeComplaintRepository();
      fakeRepo.items.add(
        ComplaintModel(
          id: 1,
          ticketNumber: 'TKT-20261027-001',
          userId: 1,
          houseId: 10,
          title: 'Pohon Tumbang Halangi Jalan',
          description: 'Perlu gergaji mesin',
          category: ComplaintCategory.jalanan,
          status: ComplaintStatus.menunggu,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      final dioClient = DioClient(storageService: SecureStorageService());

      await tester.pumpWidget(
        MultiRepositoryProvider(
          providers: [
            RepositoryProvider<ComplaintRepository>.value(value: fakeRepo),
            RepositoryProvider<DioClient>.value(value: dioClient),
          ],
          child: MaterialApp(
            home: BlocProvider(
              create: (_) => AdminComplaintBloc(repository: fakeRepo),
              child: AdminComplaintsScreen(currentUser: createAdminUser()),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Mobile should show TabBar tabs
      expect(find.byType(TabBar), findsWidgets);
      expect(find.text('Semua (1)'), findsOneWidget);
      expect(find.text('Menunggu (1)'), findsOneWidget);
      expect(find.text('Diproses (0)'), findsOneWidget);
      expect(find.text('Selesai (0)'), findsOneWidget);
      expect(find.text('Pohon Tumbang Halangi Jalan'), findsOneWidget);
    });

    testWidgets('Assign officer dialog allows officer selection and submission', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final fakeRepo = FakeComplaintRepository();
      final complaint = ComplaintModel(
        id: 1,
        ticketNumber: 'TKT-20261027-001',
        userId: 1,
        houseId: 10,
        title: 'Sampah Menumpuk di Gerbang',
        description: 'Truk sampah belum datang',
        category: ComplaintCategory.sampah,
        status: ComplaintStatus.menunggu,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      fakeRepo.items.add(complaint);

      String? assignedName;
      String? assignedStatus;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    AssignOfficerDialog.show(
                      context,
                      complaint: complaint,
                      eligibleOfficers: const [
                        EligibleOfficerModel(
                          id: 10,
                          name: 'Pak Joko (Teknisi)',
                          role: 'SECURITY',
                          phone: '08123456789',
                          status: 'active',
                        ),
                      ],
                      onAssign: ({
                        required officerName,
                        officerUserId,
                        notes,
                        status,
                      }) {
                        assignedName = officerName;
                        assignedStatus = status;
                      },
                    );
                  },
                  child: const Text('Buka Dialog Penugasan'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Buka Dialog Penugasan'));
      await tester.pumpAndSettle();

      expect(find.text('Tugaskan Petugas Lapangan'), findsOneWidget);
      expect(find.text('Tiket: TKT-20261027-001'), findsOneWidget);

      // Select dropdown officer
      await tester.tap(find.byType(DropdownButtonFormField<EligibleOfficerModel>));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Pak Joko (Teknisi) (SECURITY)').last);
      await tester.pumpAndSettle();

      // Submit assignment
      await tester.tap(find.text('Tugaskan'));
      await tester.pumpAndSettle();

      expect(assignedName, 'Pak Joko (Teknisi)');
      expect(assignedStatus, 'Diproses');
    });

    test('Merged sidebar: admin roles only see Kelola Pengaduan and not Lapor Cluster', () {
      final adminRoles = [
        'ADMIN',
        'CHAIRPERSON',
        'VICE_CHAIRPERSON',
        'TREASURER',
        'SECRETARY',
      ];

      for (final role in adminRoles) {
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

        final items = NavigationItemBuilder.buildNavigationItems(user);
        final hasAdminComplaints = items.any((it) => it.keyId == 'admin_complaints');
        final hasResidentComplaints = items.any((it) => it.keyId == 'complaints');

        expect(hasAdminComplaints, isTrue, reason: 'Role $role must have Kelola Pengaduan');
        expect(hasResidentComplaints, isFalse, reason: 'Role $role must NOT have duplicate Lapor Cluster menu');

        final adminItem = items.firstWhere((it) => it.keyId == 'admin_complaints');
        expect(adminItem.title, equals('Kelola Pengaduan'));
      }
    });

    test('Merged sidebar: RESIDENT role has Lapor Cluster and not Kelola Pengaduan', () {
      const residentUser = UserModel(
        id: 99,
        name: 'Warga Biasa',
        email: 'warga@tetanggo.id',
        phone: '081234567899',
        role: 'RESIDENT',
        roleId: 6,
        status: 'active',
        houseId: 101,
      );

      final items = NavigationItemBuilder.buildNavigationItems(residentUser);
      final hasAdminComplaints = items.any((it) => it.keyId == 'admin_complaints');
      final hasResidentComplaints = items.any((it) => it.keyId == 'complaints');

      expect(hasAdminComplaints, isFalse, reason: 'RESIDENT must NOT have Kelola Pengaduan');
      expect(hasResidentComplaints, isTrue, reason: 'RESIDENT with house must have Lapor Cluster');
    });

    testWidgets('AdminComplaintsScreen integrates Lapor Cluster sub-navigation for eligible admin', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final fakeRepo = FakeComplaintRepository();
      fakeRepo.items.add(
        ComplaintModel(
          id: 1,
          ticketNumber: 'TKT-ADMIN-001',
          userId: 1,
          houseId: 10,
          title: 'Lampu Padam Lapangan',
          description: 'Lampu mati sejak semalam',
          category: ComplaintCategory.lampuJalan,
          status: ComplaintStatus.menunggu,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      final dioClient = DioClient(storageService: SecureStorageService());

      await tester.pumpWidget(
        MultiRepositoryProvider(
          providers: [
            RepositoryProvider<ComplaintRepository>.value(value: fakeRepo),
            RepositoryProvider<DioClient>.value(value: dioClient),
          ],
          child: MaterialApp(
            home: MultiBlocProvider(
              providers: [
                BlocProvider(create: (_) => AdminComplaintBloc(repository: fakeRepo)),
                BlocProvider(create: (_) => ComplaintBloc(repository: fakeRepo)),
              ],
              child: AdminComplaintsScreen(currentUser: createAdminUser()),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Check sub-navigation chips
      expect(find.text('Semua Pengaduan Cluster'), findsOneWidget);
      expect(find.text('Lapor Cluster (Laporan Saya)'), findsOneWidget);

      // Initially on Kanban
      expect(find.text('Lampu Padam Lapangan'), findsOneWidget);

      // Switch to Lapor Cluster tab
      await tester.tap(find.text('Lapor Cluster (Laporan Saya)'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Lapor Cluster resident screen should be rendered inside
      expect(find.text('Lapor Cluster'), findsWidgets);
    });

    testWidgets('AdminComplaintsScreen hides Lapor Cluster tab when admin has no house association', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final fakeRepo = FakeComplaintRepository();
      const adminWithoutHouse = UserModel(
        id: 1,
        roleId: 1,
        name: 'Super Admin',
        phone: '081234567890',
        email: 'admin@tetanggo.id',
        role: 'ADMIN',
        status: 'active',
        houseId: null,
      );

      await tester.pumpWidget(
        MultiRepositoryProvider(
          providers: [
            RepositoryProvider<ComplaintRepository>.value(value: fakeRepo),
          ],
          child: MaterialApp(
            home: BlocProvider(
              create: (_) => AdminComplaintBloc(repository: fakeRepo),
              child: const AdminComplaintsScreen(currentUser: adminWithoutHouse),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Should NOT render sub-navigation tabs because admin has no house
      expect(find.text('Semua Pengaduan Cluster'), findsNothing);
      expect(find.text('Lapor Cluster (Laporan Saya)'), findsNothing);
    });
  });
}
