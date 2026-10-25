import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tetanggo_frontend/features/announcements/data/announcements_repository.dart';
import 'package:tetanggo_frontend/features/announcements/domain/models/announcement_model.dart';
import 'package:tetanggo_frontend/features/auth/domain/models/user_model.dart';
import 'package:tetanggo_frontend/features/billing/data/billing_repository.dart';
import 'package:tetanggo_frontend/features/billing/domain/models/billing_models.dart';
import 'package:tetanggo_frontend/features/cashbook/data/cashbook_repository.dart';
import 'package:tetanggo_frontend/features/cashbook/domain/models/cashbook_models.dart';
import 'package:tetanggo_frontend/features/home/data/dashboard_repository.dart';
import 'package:tetanggo_frontend/features/home/domain/models/dashboard_stats_model.dart';
import 'package:tetanggo_frontend/features/home/presentation/widgets/dashboard_content_body.dart';
import 'package:tetanggo_frontend/features/home/presentation/widgets/dashboard_sidebar.dart';

class MockDashboardRepo implements DashboardRepository {
  final DashboardStatsModel stats;
  MockDashboardRepo(this.stats);

  @override
  Future<DashboardStatsModel> getAdminDashboardStats({String? period}) async =>
      stats;
}

class MockBillingRepo implements BillingRepository {
  final List<BillModel> bills;
  MockBillingRepo(this.bills);

  @override
  Future<List<BillModel>> getResidentBills({String? period}) async => bills;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockCashbookRepo implements CashbookRepository {
  final CashbookSummaryModel summary;
  MockCashbookRepo(this.summary);

  @override
  Future<CashbookSummaryModel> getCashbookSummary() async => summary;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockAnnouncementsRepo implements AnnouncementsRepository {
  final List<AnnouncementModel> announcements;
  MockAnnouncementsRepo(this.announcements);

  @override
  Future<List<AnnouncementModel>> getAnnouncements(
          {String? category, bool? pinnedOnly, String? search}) async =>
      announcements;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final dummyCashbook = CashbookSummaryModel(
    currentBalance: 5000000,
    totalIncome: 7500000,
    totalExpense: 2500000,
    monthlySummary: [],
  );

  final emptyStats = DashboardStatsModel(
    totalHouses: 0,
    occupiedHouses: 0,
    emptyHouses: 0,
    totalResidents: 0,
    pendingResidents: 0,
    currentPeriod: '2026-10',
    collectedAmount: 0,
    targetAmount: 0,
    pendingPaymentsCount: 0,
    recentActivities: [],
  );

  Widget createTestWidget({
    required UserModel user,
    DashboardStatsModel? stats,
    List<BillModel> bills = const [],
    List<AnnouncementModel> announcements = const [],
    void Function(String)? onNavigate,
  }) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<DashboardRepository>.value(
          value: MockDashboardRepo(stats ?? emptyStats),
        ),
        RepositoryProvider<BillingRepository>.value(
          value: MockBillingRepo(bills),
        ),
        RepositoryProvider<CashbookRepository>.value(
          value: MockCashbookRepo(dummyCashbook),
        ),
        RepositoryProvider<AnnouncementsRepository>.value(
          value: MockAnnouncementsRepo(announcements),
        ),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: DashboardContentBody(
            user: user,
            isDesktop: true,
            onNavigate: onNavigate,
          ),
        ),
      ),
    );
  }

  group('Dashboard WARGA Role Tests', () {
    testWidgets('Priority 1: Unpaid dues banner & dues summary card rendered',
        (tester) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const residentUser = UserModel(
        id: 10,
        email: 'warga@tetanggo.id',
        name: 'Budi Santoso',
        phone: '08123456789',
        role: 'RESIDENT',
        roleId: 6,
        status: 'active',
        houseBlock: 'C',
        houseNumber: '12',
      );

      final bills = [
        BillModel(
          id: 1,
          houseId: 5,
          billingPeriod: '2026-10',
          amount: 150000,
          status: 'unpaid',
          createdAt: DateTime(2026, 10, 1),
          updatedAt: DateTime(2026, 10, 1),
        ),
        BillModel(
          id: 2,
          houseId: 5,
          billingPeriod: '2026-09',
          amount: 100000,
          status: 'paid',
          createdAt: DateTime(2026, 9, 1),
          updatedAt: DateTime(2026, 9, 1),
        ),
      ];

      String? navigatedKey;
      await tester.pumpWidget(createTestWidget(
        user: residentUser,
        bills: bills,
        onNavigate: (k) => navigatedKey = k,
      ));
      await tester.pumpAndSettle();

      // Banner checks
      expect(find.byKey(const Key('resident_unpaid_banner')), findsOneWidget);
      expect(find.text('Ada 1 iuran yang belum dibayar.'), findsOneWidget);
      expect(find.textContaining('Rp 150.000'), findsWidgets);

      // Summary Card checks
      expect(
          find.byKey(const Key('resident_dues_summary_card')), findsOneWidget);
      expect(find.text('Belum Dibayar'), findsOneWidget);
      expect(find.text('1 Tagihan'), findsOneWidget);
      expect(find.text('Perlu Bayar'), findsOneWidget);

      // Tap banner action
      await tester.tap(find.byKey(const Key('resident_banner_action_unpaid')));
      expect(navigatedKey, 'resident_billing');
    });

    testWidgets('Priority 2: Rejected dues banner rendered when no unpaid dues',
        (tester) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const residentUser = UserModel(
        id: 10,
        email: 'warga@tetanggo.id',
        name: 'Siti Aminah',
        phone: '08123456789',
        role: 'RESIDENT',
        roleId: 6,
        status: 'active',
      );

      final bills = [
        BillModel(
          id: 3,
          houseId: 5,
          billingPeriod: '2026-10',
          amount: 100000,
          status: 'rejected',
          createdAt: DateTime(2026, 10, 1),
          updatedAt: DateTime(2026, 10, 2),
        ),
      ];

      await tester
          .pumpWidget(createTestWidget(user: residentUser, bills: bills));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('resident_rejected_banner')), findsOneWidget);
      expect(
          find.text(
              'Pembayaran Anda ditolak. Periksa detail dan tindak lanjuti.'),
          findsOneWidget);
      expect(find.text('1 Pembayaran'), findsOneWidget);
      expect(find.text('Tindak Lanjut'), findsOneWidget);
    });

    testWidgets('Priority 3: Pending verification banner rendered',
        (tester) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const residentUser = UserModel(
        id: 10,
        email: 'warga@tetanggo.id',
        name: 'Joko',
        phone: '08123456789',
        role: 'RESIDENT',
        roleId: 6,
        status: 'active',
      );

      final bills = [
        BillModel(
          id: 4,
          houseId: 5,
          billingPeriod: '2026-10',
          amount: 100000,
          status: 'pending_verification',
          createdAt: DateTime(2026, 10, 1),
          updatedAt: DateTime(2026, 10, 1),
        ),
      ];

      await tester
          .pumpWidget(createTestWidget(user: residentUser, bills: bills));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('resident_pending_banner')), findsOneWidget);
      expect(find.text('Pembayaran Anda sedang menunggu verifikasi.'),
          findsOneWidget);
    });

    testWidgets(
        'Priority 4: Urgent announcement banner when all dues are clear',
        (tester) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const residentUser = UserModel(
        id: 10,
        email: 'warga@tetanggo.id',
        name: 'Dewi',
        phone: '08123456789',
        role: 'RESIDENT',
        roleId: 6,
        status: 'active',
      );

      final announcements = [
        AnnouncementModel(
          id: 1,
          title: 'Pemadaman Listrik Bergilir',
          content: 'Harap siapkan penerangan darurat',
          category: 'darurat',
          isPinned: true,
          authorName: 'Pengurus',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      await tester.pumpWidget(createTestWidget(
        user: residentUser,
        bills: [],
        announcements: announcements,
      ));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('resident_announcement_banner')),
          findsOneWidget);
      expect(find.text('Pengumuman Darurat'), findsOneWidget);
      expect(find.text('Pemadaman Listrik Bergilir'), findsWidgets);
    });

    testWidgets(
        'Normal status banner when all dues paid and no urgent announcements',
        (tester) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const residentUser = UserModel(
        id: 10,
        email: 'warga@tetanggo.id',
        name: 'Dewi',
        phone: '08123456789',
        role: 'RESIDENT',
        roleId: 6,
        status: 'active',
      );

      await tester.pumpWidget(createTestWidget(user: residentUser, bills: []));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('resident_normal_banner')), findsOneWidget);
      expect(find.textContaining('Status Iuran Tertib'), findsOneWidget);
    });

    test('Sidebar items display unpaid dues badge for resident', () {
      const residentUser = UserModel(
        id: 10,
        email: 'warga@tetanggo.id',
        name: 'Budi Santoso',
        phone: '08123456789',
        role: 'RESIDENT',
        roleId: 6,
        status: 'active',
        houseBlock: 'C',
        houseNumber: '12',
      );

      final items = NavigationItemBuilder.buildNavigationItems(
        residentUser,
        residentUnpaidBillsCount: 2,
      );

      final billingItem =
          items.firstWhere((it) => it.keyId == 'resident_billing');
      expect(billingItem.badge, '2 Belum Bayar');
    });
  });

  group('Dashboard ADMIN and Pengurus Role Adaptation Tests', () {
    testWidgets(
        'ADMIN sees combined "Perlu Ditindaklanjuti" card with pending counts',
        (tester) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const adminUser = UserModel(
        id: 1,
        email: 'admin@tetanggo.id',
        name: 'Admin Utama',
        phone: '08123456789',
        role: 'ADMIN',
        roleId: 1,
        status: 'active',
      );

      final stats = DashboardStatsModel(
        totalHouses: 20,
        occupiedHouses: 15,
        emptyHouses: 5,
        totalResidents: 35,
        pendingResidents: 3,
        currentPeriod: '2026-10',
        collectedAmount: 2000000,
        targetAmount: 3000000,
        pendingPaymentsCount: 4,
        recentActivities: [],
      );

      String? navigatedKey;
      await tester.pumpWidget(createTestWidget(
        user: adminUser,
        stats: stats,
        onNavigate: (k) => navigatedKey = k,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Perlu Ditindaklanjuti'), findsOneWidget);
      expect(find.text('7 Antrean'), findsOneWidget);
      expect(find.text('4 Iuran, 3 Calon Warga'), findsOneWidget);
      expect(find.text('Total Hunian'), findsOneWidget);
      expect(find.text('Warga Terdaftar'), findsOneWidget);
      expect(find.text('Saldo Kas Transparan'), findsOneWidget);

      await tester.tap(find.text('Perlu Ditindaklanjuti'));
      expect(navigatedKey, 'billing');
    });

    testWidgets(
        'BENDAHARA (TREASURER) sees finance-specific cards and actions only',
        (tester) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const treasurerUser = UserModel(
        id: 2,
        email: 'bendahara@tetanggo.id',
        name: 'Bendahara Keuangan',
        phone: '08123456789',
        role: 'TREASURER',
        roleId: 4,
        status: 'active',
      );

      final stats = DashboardStatsModel(
        totalHouses: 20,
        occupiedHouses: 15,
        emptyHouses: 5,
        totalResidents: 35,
        pendingResidents: 2,
        currentPeriod: '2026-10',
        collectedAmount: 2500000,
        targetAmount: 3000000,
        pendingPaymentsCount: 3,
        recentActivities: [],
      );

      String? navigatedKey;
      await tester.pumpWidget(createTestWidget(
        user: treasurerUser,
        stats: stats,
        onNavigate: (k) => navigatedKey = k,
      ));
      await tester.pumpAndSettle();

      // Bendahara melihat Kas, Perlu Ditindaklanjuti (khusus pembayaran), Realisasi Iuran, Pengumuman
      expect(find.text('Saldo Kas Transparan'), findsOneWidget);
      expect(find.text('Perlu Ditindaklanjuti'), findsOneWidget);
      expect(find.text('3 Transaksi'), findsOneWidget);
      expect(find.text('Bukti transfer iuran menunggu verifikasi'),
          findsOneWidget);
      expect(find.text('Iuran Periode Berjalan'), findsOneWidget);

      // Bendahara TIDAK melihat card hunian/warga di dashboard utama
      expect(find.text('Total Hunian'), findsNothing);
      expect(find.text('Warga Terdaftar'), findsNothing);

      await tester.tap(find.text('Perlu Ditindaklanjuti'));
      expect(navigatedKey, 'billing');
    });

    testWidgets(
        'SEKRETARIS (SECRETARY) sees resident administration cards only',
        (tester) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const secretaryUser = UserModel(
        id: 3,
        email: 'sekretaris@tetanggo.id',
        name: 'Sekretaris Lingkungan',
        phone: '08123456789',
        role: 'SECRETARY',
        roleId: 5,
        status: 'active',
      );

      final stats = DashboardStatsModel(
        totalHouses: 20,
        occupiedHouses: 15,
        emptyHouses: 5,
        totalResidents: 35,
        pendingResidents: 5,
        currentPeriod: '2026-10',
        collectedAmount: 2500000,
        targetAmount: 3000000,
        pendingPaymentsCount: 2,
        recentActivities: [],
      );

      String? navigatedKey;
      await tester.pumpWidget(createTestWidget(
        user: secretaryUser,
        stats: stats,
        onNavigate: (k) => navigatedKey = k,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Perlu Ditindaklanjuti'), findsOneWidget);
      expect(find.text('5 Pendaftaran'), findsOneWidget);
      expect(find.text('Pendaftaran calon warga baru menunggu verifikasi'),
          findsOneWidget);
      expect(find.text('Warga Terdaftar'), findsOneWidget);
      expect(find.text('Total Hunian'), findsOneWidget);
      expect(find.text('Saldo Kas Transparan'), findsOneWidget);

      await tester.tap(find.text('Perlu Ditindaklanjuti'));
      expect(navigatedKey, 'verification');
    });

    testWidgets('KETUA (CHAIRPERSON) sees comprehensive governance layout',
        (tester) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const chairUser = UserModel(
        id: 4,
        email: 'ketua@tetanggo.id',
        name: 'Ketua Pengurus',
        phone: '08123456789',
        role: 'CHAIRPERSON',
        roleId: 2,
        status: 'active',
      );

      final stats = DashboardStatsModel(
        totalHouses: 20,
        occupiedHouses: 15,
        emptyHouses: 5,
        totalResidents: 35,
        pendingResidents: 0,
        currentPeriod: '2026-10',
        collectedAmount: 3000000,
        targetAmount: 3000000,
        pendingPaymentsCount: 0,
        recentActivities: [],
      );

      await tester.pumpWidget(createTestWidget(
        user: chairUser,
        stats: stats,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Saldo Kas Transparan'), findsOneWidget);
      expect(find.text('Perlu Ditindaklanjuti'), findsOneWidget);
      expect(find.text('Semua Tuntas'), findsOneWidget);
      expect(find.text('Total Hunian'), findsOneWidget);
      expect(find.text('Warga Terdaftar'), findsOneWidget);
    });
  });
}
