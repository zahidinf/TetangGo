import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tetanggo_frontend/features/auth/domain/models/user_model.dart';
import 'package:tetanggo_frontend/features/home/data/dashboard_repository.dart';
import 'package:tetanggo_frontend/features/home/domain/models/dashboard_stats_model.dart';
import 'package:tetanggo_frontend/features/home/presentation/widgets/dashboard_content_body.dart';
import 'package:dio/dio.dart';

class FakeDashboardRepository extends DashboardRepository {
  FakeDashboardRepository() : super(dio: Dio());

  @override
  Future<DashboardStatsModel> getAdminDashboardStats({String? period}) async {
    return DashboardStatsModel(
      totalHouses: 13,
      occupiedHouses: 7,
      emptyHouses: 6,
      totalResidents: 1,
      pendingResidents: 0,
      currentPeriod: '2026-09',
      collectedAmount: 35000,
      targetAmount: 245000,
      pendingPaymentsCount: 0,
      recentActivities: [
        DashboardRecentActivityModel(
          id: 4,
          residentName: 'Farhan Tamtsil Hasanudin',
          block: 'B1',
          houseNumber: '36',
          amountPaid: 35000,
          status: 'paid',
          createdAt: DateTime.parse('2026-09-29T09:19:50.194113+07:00'),
        ),
      ],
    );
  }
}

void main() {
  testWidgets('DashboardContentBody displays real DB data and zero dummy text', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final fakeRepo = FakeDashboardRepository();
    final testUser = const UserModel(
      id: 1,
      name: 'Admin RT TetangGo',
      phone: '081234567890',
      email: 'admin@tetanggo.id',
      roleId: 1,
      role: 'admin_rt',
      status: 'active',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: RepositoryProvider<DashboardRepository>.value(
          value: fakeRepo,
          child: Scaffold(
            body: DashboardContentBody(
              user: testUser,
              isDesktop: true,
            ),
          ),
        ),
      ),
    );

    // Initial state
    await tester.pump();
    // Complete Future
    await tester.pumpAndSettle();

    // Verify Real Data displayed
    expect(find.text('13 Rumah'), findsOneWidget);
    expect(find.text('7 Terisi, 6 Kosong'), findsOneWidget);
    expect(find.text('1 Warga Aktif'), findsOneWidget);
    expect(find.text('Semua Terverifikasi'), findsOneWidget);
    expect(find.text('Rp 35.000'), findsNWidgets(2)); // Card 3 value and table row amount
    expect(find.text('Target: Rp 245.000'), findsOneWidget);
    expect(find.text('0 Transaksi'), findsOneWidget);

    // Verify Real Activity Table
    expect(find.text('Farhan Tamtsil Hasanudin'), findsOneWidget);
    expect(find.textContaining('Blok B1 No. 36'), findsOneWidget);
    expect(find.text('Lunas'), findsOneWidget);

    // Verify Sprint 3 Placeholder for announcements
    expect(find.textContaining('Modul Pengumuman Aktif di Sprint 3'), findsOneWidget);

    // Verify ZERO dummy hardcoded data
    expect(find.text('124 Rumah'), findsNothing);
    expect(find.text('Rp 18.600.000'), findsNothing);
    expect(find.text('Rp 45.320.000'), findsNothing);
    expect(find.text('18 Pengunjung'), findsNothing);
    expect(find.text('Bpk. Hendra Wijaya'), findsNothing);
    expect(find.text('Ibu Siti Rahma'), findsNothing);
    expect(find.text('Bpk. Ahmad Fauzi'), findsNothing);
    expect(find.text('Bpk. Eko Prasetyo'), findsNothing);
    expect(find.textContaining('Kerja Bakti Bersama'), findsNothing);
  });
}
