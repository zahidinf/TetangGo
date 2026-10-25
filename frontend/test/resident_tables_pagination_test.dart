import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tetanggo_frontend/features/resident_management/data/resident_repository.dart';
import 'package:tetanggo_frontend/features/resident_management/domain/models/house_model.dart';
import 'package:tetanggo_frontend/features/resident_management/domain/models/resident_user_model.dart';
import 'package:tetanggo_frontend/features/resident_management/presentation/houses_management_view.dart';
import 'package:tetanggo_frontend/features/resident_management/presentation/residents_management_view.dart';

class FakeResidentRepository extends ResidentRepository {
  final List<HouseModel> fakeHouses;
  final List<ResidentUserModel> fakeUsers;

  FakeResidentRepository({
    this.fakeHouses = const [],
    this.fakeUsers = const [],
  }) : super(dio: Dio());

  @override
  Future<List<String>> getHouseBlocks() async {
    return ['A', 'B', 'C'];
  }

  @override
  Future<List<HouseModel>> getHouses(
      {String? block, String? status, String? search}) async {
    return fakeHouses.where((h) {
      if (block != null && block.isNotEmpty && h.block != block) return false;
      if (status != null && status.isNotEmpty && h.status != status)
        return false;
      if (search != null && search.isNotEmpty) {
        final query = search.toLowerCase();
        final matchesNumber = h.houseNumber.toLowerCase().contains(query);
        final matchesResident =
            (h.residentName ?? '').toLowerCase().contains(query);
        if (!matchesNumber && !matchesResident) return false;
      }
      return true;
    }).toList();
  }

  @override
  Future<List<ResidentUserModel>> getAdminUsers({
    String? search,
    String? status,
    String? role,
    int? houseId,
  }) async {
    return fakeUsers.where((u) {
      if (status != null && status.isNotEmpty && u.status != status)
        return false;
      if (role != null && role.isNotEmpty && u.role != role) return false;
      if (houseId != null && u.houseId != houseId) return false;
      if (search != null && search.isNotEmpty) {
        final query = search.toLowerCase();
        final matchesName = u.name.toLowerCase().contains(query);
        final matchesPhone = u.phone.toLowerCase().contains(query);
        final matchesEmail = u.email.toLowerCase().contains(query);
        if (!matchesName && !matchesPhone && !matchesEmail) return false;
      }
      return true;
    }).toList();
  }
}

void main() {
  group('Houses & Residents Table Virtualization / Pagination Tests', () {
    testWidgets(
        'HousesManagementView membatasi rendering 15 baris per halaman dan mendukung navigasi',
        (tester) async {
      tester.view.physicalSize = const Size(1600, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final dummyHouses = List.generate(
        35,
        (i) => HouseModel(
          id: i + 1,
          block: 'A',
          houseNumber: '${i + 1}',
          status: 'milik',
          residentName: 'Warga ${i + 1}',
          totalOccupants: 3,
          vehicleCount: 1,
        ),
      );

      final fakeRepo = FakeResidentRepository(fakeHouses: dummyHouses);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RepositoryProvider<ResidentRepository>.value(
              value: fakeRepo,
              child: const HousesManagementView(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Memastikan hanya 15 baris rendered di DataTable (halaman 1)
      expect(find.text('Blok A No. 1'), findsOneWidget);
      expect(find.text('Blok A No. 15'), findsOneWidget);
      expect(find.text('Blok A No. 16'), findsNothing);

      // Verifikasi indikator pagination
      expect(find.text('Menampilkan 1–15 dari 35 data (Hal 1 dari 3)'),
          findsOneWidget);

      // Navigasi ke halaman 2
      final page2Finder = find.byKey(const Key('houses_pagination_page_2'));
      await tester.scrollUntilVisible(
        page2Finder,
        100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(page2Finder);
      await tester.pumpAndSettle();

      expect(find.text('Blok A No. 1'), findsNothing);
      expect(find.text('Blok A No. 16'), findsOneWidget);
      expect(find.text('Blok A No. 30'), findsOneWidget);
      expect(find.text('Blok A No. 31'), findsNothing);
      expect(find.text('Menampilkan 16–30 dari 35 data (Hal 2 dari 3)'),
          findsOneWidget);

      // Navigasi ke halaman 3
      final nextFinder = find.byKey(const Key('houses_pagination_next'));
      await tester.tap(nextFinder);
      await tester.pumpAndSettle();

      expect(find.text('Blok A No. 31'), findsOneWidget);
      expect(find.text('Blok A No. 35'), findsOneWidget);
      expect(find.text('Menampilkan 31–35 dari 35 data (Hal 3 dari 3)'),
          findsOneWidget);
    });

    testWidgets(
        'ResidentsManagementView membatasi rendering 15 baris dan mendukung navigasi',
        (tester) async {
      tester.view.physicalSize = const Size(1600, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final dummyUsers = List.generate(
        25,
        (i) => ResidentUserModel(
          id: i + 1,
          salutation: 'Bapak',
          name: 'Penduduk ${i + 1}',
          phone: '0812000000${i + 1}',
          email: 'user${i + 1}@example.com',
          role: 'resident',
          status: 'active',
          ownershipStatus: 'owner',
          createdAt: DateTime.now(),
        ),
      );

      final fakeRepo = FakeResidentRepository(fakeUsers: dummyUsers);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RepositoryProvider<ResidentRepository>.value(
              value: fakeRepo,
              child: const ResidentsManagementView(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Memastikan 15 data rendered di halaman 1
      expect(find.text('Bapak Penduduk 1'), findsOneWidget);
      expect(find.text('Bapak Penduduk 15'), findsOneWidget);
      expect(find.text('Bapak Penduduk 16'), findsNothing);
      expect(find.text('Menampilkan 1–15 dari 25 data (Hal 1 dari 2)'),
          findsOneWidget);

      // Navigasi ke halaman 2
      final page2Finder = find.byKey(const Key('residents_pagination_page_2'));
      await tester.scrollUntilVisible(
        page2Finder,
        100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(page2Finder);
      await tester.pumpAndSettle();

      expect(find.text('Bapak Penduduk 1'), findsNothing);
      expect(find.text('Bapak Penduduk 16'), findsOneWidget);
      expect(find.text('Bapak Penduduk 25'), findsOneWidget);
      expect(find.text('Menampilkan 16–25 dari 25 data (Hal 2 dari 2)'),
          findsOneWidget);
    });
  });
}
