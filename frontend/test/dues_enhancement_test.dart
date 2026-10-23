import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tetanggo_frontend/features/admin_billing/presentation/admin_billing_view.dart';
import 'package:tetanggo_frontend/features/admin_billing/presentation/widgets/bulk_process_payment_dialog.dart';
import 'package:tetanggo_frontend/features/billing/data/billing_repository.dart';
import 'package:tetanggo_frontend/features/billing/domain/models/billing_models.dart';

class FakeBulkBillingRepository extends Fake implements BillingRepository {
  bool bulkProcessCalled = false;
  String? lastPeriod;
  String? lastPaymentMethod;
  List<int>? lastBillIds;
  String? lastNotes;

  BulkProcessResultModel? mockResult;
  BillingSummaryModel? mockSummary;

  @override
  Future<PaymentSettingModel> getPaymentSettings() async {
    return PaymentSettingModel(
      id: 1,
      monthlyFee: 50000.0,
      bankName: 'BCA',
      accountNumber: '1234567890',
      accountHolder: 'Kas RT',
    );
  }

  @override
  Future<List<PendingPaymentModel>> getPendingPayments() async {
    return [];
  }

  @override
  Future<List<String>> getHouseBlocks() async {
    return ['A', 'B'];
  }

  @override
  Future<BillingSummaryModel> getBillingSummary({String? period, String? block}) async {
    return mockSummary ??
        BillingSummaryModel(
          period: period ?? '2026-10',
          isPeriodGenerated: true,
          totalHouses: 2,
          paidHouses: 0,
          unpaidHouses: 2,
          totalPaidAmount: 0.0,
          totalUnpaidAmount: 100000.0,
          houseBills: [
            HouseBillStatusModel(
              houseId: 1,
              block: 'A',
              houseNumber: '1',
              residentName: 'Warga 1',
              residentPhone: '08111',
              status: 'unpaid',
              billId: 101,
              amount: 50000.0,
            ),
          ],
        );
  }

  @override
  Future<BulkProcessResultModel> bulkProcessPayments({
    required String period,
    required String paymentMethod,
    required List<int> billIds,
    String? notes,
  }) async {
    bulkProcessCalled = true;
    lastPeriod = period;
    lastPaymentMethod = paymentMethod;
    lastBillIds = billIds;
    lastNotes = notes;

    return mockResult ??
        BulkProcessResultModel(
          period: period,
          paymentMethod: paymentMethod,
          totalProcessed: billIds.length,
          successCount: billIds.length,
          failedCount: 0,
          results: billIds
              .map((id) => BulkProcessItemResultModel(
                    billId: id,
                    houseId: id * 10,
                    houseBlock: 'A',
                    houseNumber: '$id',
                    residentName: 'Warga $id',
                    success: true,
                    status: paymentMethod == 'CASH' ? 'paid' : 'pending_verification',
                    message: 'Success',
                    amount: 50000.0,
                  ))
              .toList(),
        );
  }
}

void main() {
  group('1. Models Serialization Tests', () {
    test('BillingSummaryModel parses is_period_generated correctly', () {
      final jsonIssued = {
        'period': '2026-10',
        'is_period_generated': true,
        'total_houses': 10,
        'paid_houses': 6,
        'unpaid_houses': 4,
        'total_paid_amount': 300000.0,
        'total_unpaid_amount': 200000.0,
        'house_bills': [],
      };
      final summaryIssued = BillingSummaryModel.fromJson(jsonIssued);
      expect(summaryIssued.isPeriodGenerated, isTrue);

      final jsonUnissued = {
        'period': '2026-11',
        'is_period_generated': false,
        'total_houses': 10,
        'paid_houses': 0,
        'unpaid_houses': 0,
        'total_paid_amount': 0.0,
        'total_unpaid_amount': 0.0,
        'house_bills': [
          {
            'house_id': 1,
            'block': 'A',
            'house_number': '1',
            'resident_name': 'Budi',
            'resident_phone': '08123',
            'status': 'no_bill',
            'amount': 0.0,
          }
        ],
      };
      final summaryUnissued = BillingSummaryModel.fromJson(jsonUnissued);
      expect(summaryUnissued.isPeriodGenerated, isFalse);
      expect(summaryUnissued.houseBills.first.status, equals('no_bill'));
      expect(summaryUnissued.houseBills.first.billId, isNull);
    });

    test('BulkProcessResultModel parses results and items accurately', () {
      final json = {
        'period': '2026-10',
        'payment_method': 'CASH',
        'total_processed': 2,
        'success_count': 1,
        'failed_count': 1,
        'results': [
          {
            'bill_id': 101,
            'house_id': 1,
            'house_block': 'A',
            'house_number': '01',
            'resident_name': 'Pak RT',
            'success': true,
            'status': 'paid',
            'message': 'Pembayaran tunai berhasil dicatat',
            'amount': 50000.0,
          },
          {
            'bill_id': 102,
            'house_id': 2,
            'house_block': 'A',
            'house_number': '02',
            'resident_name': 'Pak Budi',
            'success': false,
            'status': 'already_paid',
            'message': 'Tagihan sudah lunas sebelumnya',
            'amount': 50000.0,
          }
        ],
      };

      final result = BulkProcessResultModel.fromJson(json);
      expect(result.period, equals('2026-10'));
      expect(result.paymentMethod, equals('CASH'));
      expect(result.totalProcessed, equals(2));
      expect(result.successCount, equals(1));
      expect(result.failedCount, equals(1));
      expect(result.results.length, equals(2));
      expect(result.results[0].success, isTrue);
      expect(result.results[1].success, isFalse);
    });
  });

  group('2. BulkProcessPaymentDialog Widget Tests', () {
    late FakeBulkBillingRepository fakeRepo;
    late List<HouseBillStatusModel> unpaidBills;

    setUp(() {
      fakeRepo = FakeBulkBillingRepository();
      unpaidBills = [
        HouseBillStatusModel(
          houseId: 1,
          block: 'A',
          houseNumber: '1',
          residentName: 'Warga 1',
          residentPhone: '08111',
          status: 'unpaid',
          billId: 101,
          amount: 50000.0,
        ),
        HouseBillStatusModel(
          houseId: 2,
          block: 'A',
          houseNumber: '2',
          residentName: 'Warga 2',
          residentPhone: '08222',
          status: 'unpaid',
          billId: 102,
          amount: 50000.0,
        ),
        HouseBillStatusModel(
          houseId: 3,
          block: 'B',
          houseNumber: '1',
          residentName: 'Warga 3',
          residentPhone: '08333',
          status: 'unpaid',
          billId: 103,
          amount: 75000.0,
        ),
      ];
    });

    testWidgets('Displays all unpaid bills and allows toggling selection and payment methods',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1024, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      bool successCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BulkProcessPaymentDialog(
              repository: fakeRepo,
              period: '2026-10',
              unpaidBills: unpaidBills,
              onSuccess: () => successCalled = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify title & initial selected total (3 bills = 175,000)
      expect(find.text('Proses Pembayaran Massal'), findsOneWidget);
      expect(find.text('Periode Iuran: 2026-10'), findsOneWidget);
      expect(find.text('Total Terpilih: 3 Unit'), findsOneWidget);
      expect(find.text('Rp 175.000'), findsOneWidget);

      // Deselect all
      await tester.tap(find.text('Batal Semua'));
      await tester.pumpAndSettle();

      expect(find.text('Total Terpilih: 0 Unit'), findsOneWidget);
      expect(find.text('Rp 0'), findsOneWidget);

      // Select first item
      await tester.tap(find.text('Blok A No. 1 - Warga 1'));
      await tester.pumpAndSettle();

      expect(find.text('Total Terpilih: 1 Unit'), findsOneWidget);
      expect(find.text('Rp 50.000'), findsOneWidget);

      // Switch to TRANSFER method
      await tester.tap(find.text('Transfer Bank'));
      await tester.pumpAndSettle();

      // Submit
      await tester.tap(find.byKey(const Key('submitBulkProcessBtn')));
      await tester.pumpAndSettle();

      expect(fakeRepo.bulkProcessCalled, isTrue);
      expect(fakeRepo.lastPaymentMethod, equals('TRANSFER'));
      expect(fakeRepo.lastBillIds, equals([101]));
      expect(fakeRepo.lastPeriod, equals('2026-10'));
      expect(successCalled, isTrue);

      // Result dialog displayed
      expect(find.text('Hasil Pembayaran Massal'), findsOneWidget);
      expect(find.text('Total'), findsOneWidget);
    });

    testWidgets('Submits CASH method and calls repository with selected IDs', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1024, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      bool successCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BulkProcessPaymentDialog(
              repository: fakeRepo,
              period: '2026-10',
              unpaidBills: unpaidBills,
              onSuccess: () => successCalled = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Submit with default CASH
      await tester.tap(find.byKey(const Key('submitBulkProcessBtn')));
      await tester.pumpAndSettle();

      expect(fakeRepo.bulkProcessCalled, isTrue);
      expect(fakeRepo.lastPaymentMethod, equals('CASH'));
      expect(fakeRepo.lastBillIds?.length, equals(3));
      expect(successCalled, isTrue);
    });
  });

  group('3. AdminBillingView Summary Period Status Validation Tests', () {
    late FakeBulkBillingRepository fakeRepo;

    setUp(() {
      fakeRepo = FakeBulkBillingRepository();
    });

    testWidgets('Shows unissued warning banner and hides bulk pay button when isPeriodGenerated is false',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      fakeRepo.mockSummary = BillingSummaryModel(
        period: '2026-11',
        isPeriodGenerated: false,
        totalHouses: 2,
        paidHouses: 0,
        unpaidHouses: 0,
        totalPaidAmount: 0.0,
        totalUnpaidAmount: 0.0,
        houseBills: [
          HouseBillStatusModel(
            houseId: 1,
            block: 'A',
            houseNumber: '1',
            residentName: 'Warga 1',
            residentPhone: '08111',
            status: 'no_bill',
            amount: 0.0,
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RepositoryProvider<BillingRepository>.value(
              value: fakeRepo,
              child: const AdminBillingView(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Switch to Summary Tab
      await tester.tap(find.text('Rekapitulasi Iuran Lingkungan'));
      await tester.pumpAndSettle();

      // Verify unissued warning banner
      expect(find.text('Periode 2026-11 Belum Diterbitkan'), findsOneWidget);
      expect(find.text('Belum Terbit'), findsOneWidget);
      expect(find.byKey(const Key('bulkPayBtn')), findsNothing);
    });

    testWidgets('Shows bulk pay button and no warning banner when isPeriodGenerated is true',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      fakeRepo.mockSummary = BillingSummaryModel(
        period: '2026-10',
        isPeriodGenerated: true,
        totalHouses: 2,
        paidHouses: 1,
        unpaidHouses: 1,
        totalPaidAmount: 50000.0,
        totalUnpaidAmount: 50000.0,
        houseBills: [
          HouseBillStatusModel(
            houseId: 1,
            block: 'A',
            houseNumber: '1',
            residentName: 'Warga 1',
            residentPhone: '08111',
            status: 'paid',
            billId: 101,
            amount: 50000.0,
          ),
          HouseBillStatusModel(
            houseId: 2,
            block: 'A',
            houseNumber: '2',
            residentName: 'Warga 2',
            residentPhone: '08222',
            status: 'unpaid',
            billId: 102,
            amount: 50000.0,
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RepositoryProvider<BillingRepository>.value(
              value: fakeRepo,
              child: const AdminBillingView(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Switch to Summary Tab
      await tester.tap(find.text('Rekapitulasi Iuran Lingkungan'));
      await tester.pumpAndSettle();

      // Verify no warning banner and bulk pay button is visible
      expect(find.text('Periode 2026-10 Belum Diterbitkan'), findsNothing);
      expect(find.byKey(const Key('bulkPayBtn')), findsOneWidget);
    });
  });
}
