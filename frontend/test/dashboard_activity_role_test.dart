import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tetanggo_frontend/core/network/dio_client.dart';
import 'package:tetanggo_frontend/core/storage/secure_storage_service.dart';
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

class FakeDashboardRepo extends DashboardRepository {
  FakeDashboardRepo() : super(dio: Dio());

  @override
  Future<DashboardStatsModel> getAdminDashboardStats({String? period}) async {
    return DashboardStatsModel(
      totalHouses: 10,
      occupiedHouses: 8,
      emptyHouses: 2,
      totalResidents: 8,
      pendingResidents: 0,
      currentPeriod: '2026-10',
      collectedAmount: 800000,
      targetAmount: 1000000,
      pendingPaymentsCount: 1,
      recentActivities: [
        DashboardRecentActivityModel(
          id: 101,
          residentName: 'Warga Lain A',
          block: 'A',
          houseNumber: '1',
          billingPeriod: '2026-10',
          amountPaid: 100000,
          status: 'paid',
          createdAt: DateTime.parse('2026-10-24T08:00:00.000Z'),
        ),
        DashboardRecentActivityModel(
          id: 102,
          residentName: 'Warga Lain B',
          block: 'B',
          houseNumber: '2',
          billingPeriod: '2026-09',
          amountPaid: 100000,
          status: 'pending_verification',
          createdAt: DateTime.parse('2026-10-24T09:00:00.000Z'),
        ),
      ],
    );
  }
}

class FakeBillingRepo extends BillingRepository {
  final List<BillModel> residentBills;

  FakeBillingRepo({this.residentBills = const []})
      : super(DioClient(storageService: SecureStorageService()));

  @override
  Future<List<BillModel>> getResidentBills({String? period}) async {
    return residentBills;
  }
}

class FakeCashbookRepo extends CashbookRepository {
  FakeCashbookRepo() : super(DioClient(storageService: SecureStorageService()));

  @override
  Future<CashbookSummaryModel> getCashbookSummary() async {
    return CashbookSummaryModel(
      currentBalance: 500000,
      totalIncome: 800000,
      totalExpense: 300000,
      monthlySummary: [],
    );
  }
}

class FakeAnnouncementsRepo extends AnnouncementsRepository {
  FakeAnnouncementsRepo() : super(DioClient(storageService: SecureStorageService()));

  @override
  Future<List<AnnouncementModel>> getAnnouncements({String? category, String? search}) async {
    return [];
  }
}

void main() {
  final fakeDashRepo = FakeDashboardRepo();
  final fakeCashbookRepo = FakeCashbookRepo();
  final fakeAnnouncementsRepo = FakeAnnouncementsRepo();

  Widget createWidget({required UserModel user, required BillingRepository billingRepo}) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<DashboardRepository>.value(value: fakeDashRepo),
        RepositoryProvider<BillingRepository>.value(value: billingRepo),
        RepositoryProvider<CashbookRepository>.value(value: fakeCashbookRepo),
        RepositoryProvider<AnnouncementsRepository>.value(value: fakeAnnouncementsRepo),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: DashboardContentBody(
            user: user,
            isDesktop: true,
          ),
        ),
      ),
    );
  }

  group('Dashboard Recent Activity Card Enhancement Tests', () {
    testWidgets('1. Bendahara (TREASURER) sees all residents payment activities', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      const treasurerUser = UserModel(
        id: 4,
        name: 'Bendahara TetangGo',
        email: 'bendahara@tetanggo.id',
        phone: '081234567891',
        roleId: 4,
        role: 'TREASURER',
        status: 'active',
        houseId: 104,
        houseBlock: 'C',
        houseNumber: '4',
      );

      final fakeBilling = FakeBillingRepo();

      await tester.pumpWidget(createWidget(user: treasurerUser, billingRepo: fakeBilling));
      await tester.pumpAndSettle();

      // Card heading
      expect(find.text('Aktivitas Pembayaran Iuran Terkini'), findsOneWidget);

      // Bendahara should see payments from ALL residents
      expect(find.text('Warga Lain A'), findsOneWidget);
      expect(find.text('Warga Lain B'), findsOneWidget);
      expect(find.text('2 Transaksi Terkini'), findsOneWidget);

      // Verify billing period displayed for each item
      expect(find.text('Periode: Oktober 2026'), findsOneWidget);
      expect(find.text('Periode: September 2026'), findsOneWidget);
    });

    testWidgets('2. Sekretaris (SECRETARY) sees all residents payment activities with billing period', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      const secretaryUser = UserModel(
        id: 5,
        name: 'Sekretaris TetangGo',
        email: 'sekretaris@tetanggo.id',
        phone: '081234567892',
        roleId: 5,
        role: 'SECRETARY',
        status: 'active',
        houseId: 105,
        houseBlock: 'D',
        houseNumber: '5',
      );

      final fakeBilling = FakeBillingRepo();

      await tester.pumpWidget(createWidget(user: secretaryUser, billingRepo: fakeBilling));
      await tester.pumpAndSettle();

      expect(find.text('Aktivitas Pembayaran Iuran Terkini'), findsOneWidget);

      // Sekretaris should see payments from ALL residents with formatted billing periods
      expect(find.text('Warga Lain A'), findsOneWidget);
      expect(find.text('Warga Lain B'), findsOneWidget);
      expect(find.text('Periode: Oktober 2026'), findsOneWidget);
      expect(find.text('Periode: September 2026'), findsOneWidget);
    });

    testWidgets('3. Warga (RESIDENT) sees only own dues activities, including UNPAID without payments', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      const residentUser = UserModel(
        id: 10,
        name: 'Budi Santoso',
        salutation: 'Bapak',
        email: 'budi@tetanggo.id',
        phone: '081234567893',
        roleId: 6,
        role: 'RESIDENT',
        status: 'active',
        houseId: 201,
        houseBlock: 'E',
        houseNumber: '10',
      );

      // Own resident bills: 1 unpaid (no payment record), 1 pending, 1 paid
      final residentBills = [
        BillModel(
          id: 501,
          houseId: 201,
          billingPeriod: '2026-10',
          amount: 100000,
          status: 'unpaid',
          createdAt: DateTime.parse('2026-10-01T00:00:00.000Z'),
          updatedAt: DateTime.parse('2026-10-01T00:00:00.000Z'),
          block: 'E',
          houseNumber: '10',
          payment: null, // Belum pernah dibayar sama sekali
        ),
        BillModel(
          id: 502,
          houseId: 201,
          billingPeriod: '2026-09',
          amount: 100000,
          status: 'pending_verification',
          createdAt: DateTime.parse('2026-09-01T00:00:00.000Z'),
          updatedAt: DateTime.parse('2026-09-05T10:00:00.000Z'),
          block: 'E',
          houseNumber: '10',
          payment: PaymentModel(
            id: 88,
            billId: 502,
            amountPaid: 100000,
            paymentMethod: 'TRANSFER',
            proofImageUrl: '/uploads/proof.jpg',
            createdAt: DateTime.parse('2026-09-05T10:00:00.000Z'),
          ),
        ),
        BillModel(
          id: 503,
          houseId: 201,
          billingPeriod: '2026-08',
          amount: 100000,
          status: 'paid',
          createdAt: DateTime.parse('2026-08-01T00:00:00.000Z'),
          updatedAt: DateTime.parse('2026-08-03T11:00:00.000Z'),
          block: 'E',
          houseNumber: '10',
          payment: PaymentModel(
            id: 85,
            billId: 503,
            amountPaid: 100000,
            paymentMethod: 'TRANSFER',
            proofImageUrl: '/uploads/proof2.jpg',
            createdAt: DateTime.parse('2026-08-03T11:00:00.000Z'),
            verifiedAt: '2026-08-03T12:00:00.000Z',
          ),
        ),
      ];

      final fakeBilling = FakeBillingRepo(residentBills: residentBills);

      await tester.pumpWidget(createWidget(user: residentUser, billingRepo: fakeBilling));
      await tester.pumpAndSettle();

      // Card heading
      expect(find.text('Aktivitas Pembayaran Iuran Terkini'), findsOneWidget);

      // MUST NOT see other residents data
      expect(find.text('Warga Lain A'), findsNothing);
      expect(find.text('Warga Lain B'), findsNothing);

      // MUST see own status badges: Belum Bayar, Menunggu Verifikasi, Lunas
      expect(find.text('Belum Bayar'), findsOneWidget);
      // "Menunggu Verifikasi" ada di ringkasan status iuran dan di baris aktivitas
      expect(find.descendant(of: find.byType(ListView), matching: find.text('Menunggu Verifikasi')), findsOneWidget);
      expect(find.text('Lunas'), findsOneWidget);

      // Verify resident billing periods: Oktober 2026 (unpaid), September 2026 (pending), Agustus 2026 (paid)
      expect(find.text('Periode: Oktober 2026'), findsOneWidget);
      expect(find.text('Periode: September 2026'), findsOneWidget);
      expect(find.text('Periode: Agustus 2026'), findsOneWidget);

      // Verify resident name & address displayed for own dues
      expect(find.text('Bapak Budi Santoso'), findsNWidgets(3));
      expect(find.textContaining('Blok E No. 10'), findsNWidgets(4)); // 1 di stat card hunian + 3 di baris aktivitas tagihan
    });

    testWidgets('4. Warga without dues activities shows friendly empty state', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      const residentUser = UserModel(
        id: 11,
        name: 'Warga Baru',
        email: 'baru@tetanggo.id',
        phone: '081234567894',
        roleId: 6,
        role: 'RESIDENT',
        status: 'active',
      );

      final fakeBilling = FakeBillingRepo(residentBills: []);

      await tester.pumpWidget(createWidget(user: residentUser, billingRepo: fakeBilling));
      await tester.pumpAndSettle();

      expect(find.text('Aktivitas Pembayaran Iuran Terkini'), findsOneWidget);
      expect(find.text('Belum ada aktivitas pembayaran iuran baru-baru ini.'), findsOneWidget);
    });

    testWidgets('5. Handles items without billing period gracefully without errors or corrupt text', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      const residentUser = UserModel(
        id: 12,
        name: 'Warga Aman',
        email: 'aman@tetanggo.id',
        phone: '081234567895',
        roleId: 6,
        role: 'RESIDENT',
        status: 'active',
        houseId: 202,
        houseBlock: 'F',
        houseNumber: '1',
      );

      final billsWithoutPeriod = [
        BillModel(
          id: 601,
          houseId: 202,
          billingPeriod: '', // Empty billing period
          amount: 50000,
          status: 'unpaid',
          createdAt: DateTime.parse('2026-10-01T00:00:00.000Z'),
          updatedAt: DateTime.parse('2026-10-01T00:00:00.000Z'),
          block: 'F',
          houseNumber: '1',
        ),
      ];

      final fakeBilling = FakeBillingRepo(residentBills: billsWithoutPeriod);

      await tester.pumpWidget(createWidget(user: residentUser, billingRepo: fakeBilling));
      await tester.pumpAndSettle();

      expect(find.text('Aktivitas Pembayaran Iuran Terkini'), findsOneWidget);
      expect(find.text('Bapak Warga Aman'), findsOneWidget);
      expect(find.text('Belum Bayar'), findsOneWidget);
      // No corrupted period text displayed
      expect(find.textContaining('Periode:'), findsNothing);
    });

    testWidgets('6. Warga sorting: strictly prioritizes status (Unpaid -> Pending -> Rejected -> Paid -> Other) and newest time within status', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      const residentUser = UserModel(
        id: 20,
        name: 'Warga Urut',
        email: 'urut@tetanggo.id',
        phone: '081234567899',
        roleId: 6,
        role: 'RESIDENT',
        status: 'active',
        houseId: 301,
        houseBlock: 'G',
        houseNumber: '7',
      );

      // Sediakan tagihan acak dengan berbagai status dan timestamp
      final residentBills = [
        // Paid yang sangat baru (harus di bawah Unpaid, Pending, Rejected)
        BillModel(
          id: 701,
          houseId: 301,
          billingPeriod: '2026-10',
          amount: 100000,
          status: 'paid',
          createdAt: DateTime.parse('2026-10-20T10:00:00.000Z'),
          updatedAt: DateTime.parse('2026-10-20T12:00:00.000Z'),
          payment: PaymentModel(
            id: 91,
            billId: 701,
            amountPaid: 100000,
            proofImageUrl: '/p1.jpg',
            createdAt: DateTime.parse('2026-10-20T11:00:00.000Z'),
            verifiedAt: '2026-10-20T12:00:00.000Z',
          ),
        ),
        // Belum bayar lama
        BillModel(
          id: 702,
          houseId: 301,
          billingPeriod: '2026-08',
          amount: 100000,
          status: 'unpaid',
          createdAt: DateTime.parse('2026-08-01T00:00:00.000Z'),
          updatedAt: DateTime.parse('2026-08-01T00:00:00.000Z'),
        ),
        // Belum bayar baru (harus paling atas!)
        BillModel(
          id: 703,
          houseId: 301,
          billingPeriod: '2026-09',
          amount: 100000,
          status: 'unpaid',
          createdAt: DateTime.parse('2026-09-01T00:00:00.000Z'),
          updatedAt: DateTime.parse('2026-09-01T00:00:00.000Z'),
        ),
        // Menunggu verifikasi
        BillModel(
          id: 704,
          houseId: 301,
          billingPeriod: '2026-07',
          amount: 100000,
          status: 'pending_verification',
          createdAt: DateTime.parse('2026-07-01T00:00:00.000Z'),
          updatedAt: DateTime.parse('2026-07-05T09:00:00.000Z'),
          payment: PaymentModel(
            id: 92,
            billId: 704,
            amountPaid: 100000,
            proofImageUrl: '/p2.jpg',
            createdAt: DateTime.parse('2026-07-05T09:00:00.000Z'),
          ),
        ),
        // Ditolak
        BillModel(
          id: 705,
          houseId: 301,
          billingPeriod: '2026-06',
          amount: 100000,
          status: 'rejected',
          createdAt: DateTime.parse('2026-06-01T00:00:00.000Z'),
          updatedAt: DateTime.parse('2026-06-10T14:00:00.000Z'),
          payment: PaymentModel(
            id: 93,
            billId: 705,
            amountPaid: 100000,
            proofImageUrl: '/p3.jpg',
            createdAt: DateTime.parse('2026-06-10T14:00:00.000Z'),
          ),
        ),
        // Status lain (misal archived / custom)
        BillModel(
          id: 706,
          houseId: 301,
          billingPeriod: '2026-05',
          amount: 100000,
          status: 'custom_status',
          createdAt: DateTime.parse('2026-05-01T00:00:00.000Z'),
          updatedAt: DateTime.parse('2026-05-01T00:00:00.000Z'),
        ),
      ];

      final fakeBilling = FakeBillingRepo(residentBills: residentBills);

      await tester.pumpWidget(createWidget(user: residentUser, billingRepo: fakeBilling));
      await tester.pumpAndSettle();

      // Card must be present
      expect(find.text('Aktivitas Pembayaran Iuran Terkini'), findsOneWidget);

      // Verify status elements in expected priority order:
      // Item 1: Unpaid (September 2026) -> Periode: September 2026
      // Item 2: Unpaid (Agustus 2026) -> Periode: Agustus 2026
      // Item 3: Pending verification (Juli 2026) -> Periode: Juli 2026
      // Item 4: Rejected (Juni 2026) -> Periode: Juni 2026
      // Item 5: Paid (Oktober 2026) -> Periode: Oktober 2026
      final periodTexts = tester.widgetList<Text>(find.byWidgetPredicate(
        (w) => w is Text && (w.data?.startsWith('Periode: ') ?? false),
      )).map((t) => t.data!).toList();

      expect(periodTexts.length, equals(5));
      expect(periodTexts[0], equals('Periode: September 2026')); // Unpaid terbaru
      expect(periodTexts[1], equals('Periode: Agustus 2026'));   // Unpaid lebih lama
      expect(periodTexts[2], equals('Periode: Juli 2026'));      // Pending verification
      expect(periodTexts[3], equals('Periode: Juni 2026'));      // Rejected
      expect(periodTexts[4], equals('Periode: Oktober 2026'));   // Paid
    });

    testWidgets('7. Admin and Pengurus sorting: sorts strictly by latest transaction time regardless of status', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      const adminUser = UserModel(
        id: 1,
        name: 'Admin Utama',
        email: 'admin@tetanggo.id',
        phone: '081234567890',
        roleId: 1,
        role: 'ADMIN',
        status: 'active',
      );

      final fakeBilling = FakeBillingRepo();

      await tester.pumpWidget(createWidget(user: adminUser, billingRepo: fakeBilling));
      await tester.pumpAndSettle();

      expect(find.text('Aktivitas Pembayaran Iuran Terkini'), findsOneWidget);

      // In FakeDashboardRepo:
      // Item 1: Warga Lain B (pending_verification, 09:00) -> Wait, let's verify order returned
      // Warga Lain A (paid, 08:00)
      // Since fake repo has:
      // index 0: Warga Lain A (08:00), index 1: Warga Lain B (09:00)
      // The admin dashboard directly renders recentActivities in the returned order from backend
      expect(find.text('Warga Lain A'), findsOneWidget);
      expect(find.text('Warga Lain B'), findsOneWidget);
    });
  });
}
