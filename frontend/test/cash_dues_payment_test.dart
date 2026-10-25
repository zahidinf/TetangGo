import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tetanggo_frontend/features/billing/data/billing_repository.dart';
import 'package:tetanggo_frontend/features/billing/domain/models/billing_models.dart';
import 'package:tetanggo_frontend/features/billing/presentation/widgets/payment_flow_dialog.dart';
import 'package:tetanggo_frontend/features/billing/presentation/widgets/digital_receipt_dialog.dart';
import 'package:tetanggo_frontend/features/admin_billing/presentation/widgets/record_cash_payment_dialog.dart';

class FakeBillingRepository extends Fake implements BillingRepository {
  bool submitPaymentCalled = false;
  String? lastPaymentMethod;
  double? lastAmount;
  String? lastNotes;

  bool recordDirectCashCalled = false;
  int? lastDirectCashResidentId;
  int? lastDirectCashBillId;
  double? lastDirectCashAmount;

  List<ResidentBillingOptionModel> mockResidents = [];
  List<EligibleDuesPeriodModel> mockPeriods = [];

  @override
  Future<void> submitPayment({
    required int billId,
    String paymentMethod = 'TRANSFER',
    String? senderBank,
    String? senderName,
    required double amount,
    String? notes,
    List<int>? imageBytes,
    String? fileName,
  }) async {
    submitPaymentCalled = true;
    lastPaymentMethod = paymentMethod;
    lastAmount = amount;
    lastNotes = notes;
  }

  @override
  Future<List<ResidentBillingOptionModel>> getEligibleResidents() async {
    return mockResidents;
  }

  @override
  Future<List<EligibleDuesPeriodModel>> getResidentEligiblePeriods(
      int residentId) async {
    return mockPeriods;
  }

  @override
  Future<PaymentModel> recordDirectCashPayment({
    required int residentId,
    required int billId,
    required double amount,
    DateTime? paymentDate,
    String? notes,
  }) async {
    recordDirectCashCalled = true;
    lastDirectCashResidentId = residentId;
    lastDirectCashBillId = billId;
    lastDirectCashAmount = amount;
    return PaymentModel(
      id: 99,
      billId: billId,
      paymentMethod: 'CASH',
      amountPaid: amount,
      proofImageUrl: '',
      notes: notes,
    );
  }
}

void main() {
  group('Cash Payment & Period Validation Tests', () {
    late FakeBillingRepository fakeRepo;

    setUp(() {
      fakeRepo = FakeBillingRepository();
    });

    test(
        '1. PaymentModel properly reflects cash payment method and proof image nullability',
        () {
      final json = {
        'id': 10,
        'bill_id': 20,
        'payment_method': 'CASH',
        'amount_paid': 35000.0,
        'proof_image_url': '',
        'notes': 'Bayar tunai ke pos RT',
      };
      final payment = PaymentModel.fromJson(json);

      expect(payment.isCash, isTrue);
      expect(payment.isTransfer, isFalse);
      expect(payment.paymentMethod, 'CASH');
      expect(payment.amountPaid, 35000.0);
      expect(payment.proofImageUrl, '');
    });

    test('2. PendingPaymentModel correctly parses cash method', () {
      final json = {
        'bill_id': 1,
        'payment_id': 2,
        'house_id': 101,
        'payment_method': 'CASH',
        'house_block': 'A',
        'house_number': '12',
        'resident_name': 'Budi Santoso',
        'resident_phone': '08123456789',
        'billing_period': '2026-10',
        'bill_amount': 35000.0,
        'amount_paid': 35000.0,
        'proof_image_url': '',
        'notes': 'Titip uang di satpam',
        'created_at': DateTime.now().toIso8601String(),
      };
      final item = PendingPaymentModel.fromJson(json);

      expect(item.isCash, isTrue);
      expect(item.paymentMethod, 'CASH');
      expect(item.residentName, 'Budi Santoso');
      expect(item.amountPaid, 35000.0);
    });

    testWidgets(
        '3. Resident PaymentFlowDialog allows cash declaration without proof image',
        (WidgetTester tester) async {
      final bill = BillModel(
        id: 1,
        houseId: 101,
        billingPeriod: '2026-10',
        amount: 35000.0,
        status: 'unpaid',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final setting = PaymentSettingModel(
        id: 1,
        bankName: 'BCA',
        accountNumber: '1234567890',
        accountHolder: 'KAS RT 05',
        monthlyFee: 35000.0,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PaymentFlowDialog(
              bill: bill,
              setting: setting,
              repository: fakeRepo,
              onPaymentSuccess: () {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check initially in transfer mode
      expect(find.text('Transfer Bank'), findsOneWidget);
      expect(find.text('Tunai / Cash'), findsOneWidget);
      expect(find.byKey(const Key('payMethodCashBtn')), findsOneWidget);

      // Switch to Cash payment method
      await tester.tap(find.byKey(const Key('payMethodCashBtn')));
      await tester.pumpAndSettle();

      // Verify cash declaration UI appeared and proof image upload is hidden
      expect(find.text('Deklarasi Pembayaran Tunai'), findsOneWidget);
      expect(find.text('Kirim Deklarasi Tunai'), findsOneWidget);
      expect(find.byKey(const Key('uploadProofBtn')), findsNothing);

      // Ensure the button is scrolled into view before tapping
      await tester.ensureVisible(find.byKey(const Key('submitPaymentBtn')));
      await tester.pumpAndSettle();

      // Submit cash declaration
      await tester.tap(find.byKey(const Key('submitPaymentBtn')));
      await tester.pumpAndSettle();

      expect(fakeRepo.submitPaymentCalled, isTrue);
      expect(fakeRepo.lastPaymentMethod, 'CASH');
      expect(fakeRepo.lastAmount, 35000.0);
    });

    testWidgets('4. DigitalReceiptDialog renders CASH payment method cleanly',
        (WidgetTester tester) async {
      final bill = BillModel(
        id: 5,
        houseId: 101,
        billingPeriod: '2026-10',
        amount: 35000.0,
        status: 'paid',
        block: 'B',
        houseNumber: '08',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        payment: PaymentModel(
          id: 50,
          billId: 5,
          paymentMethod: 'CASH',
          amountPaid: 35000.0,
          proofImageUrl: '',
          notes: 'Diterima tunai oleh Pak RT',
          verifiedByName: 'Pak RT Bambang',
          verifiedAt: DateTime.now().toIso8601String(),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DigitalReceiptDialog(
              bill: bill,
              residentName: 'Agus Salim',
              residentPhone: '0811223344',
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('KUITANSI PEMBAYARAN DIGITAL'), findsOneWidget);
      expect(find.text('TUNAI (CASH)'), findsOneWidget);
      expect(find.text('LUNAS'), findsNWidgets(2)); // in row and in stamp
      expect(find.text('Diterima / Diverifikasi Oleh'), findsOneWidget);
      expect(find.text('Pak RT Bambang'), findsOneWidget);
      expect(find.text('Catatan'), findsOneWidget);
      expect(find.text('Diterima tunai oleh Pak RT'), findsOneWidget);
      // Transfer proof button should not be present
      expect(find.text('Lihat Bukti Transfer'), findsNothing);
    });

    testWidgets(
        '5. RecordCashPaymentDialog enforces confirmation summary and triggers direct cash recording',
        (WidgetTester tester) async {
      fakeRepo.mockResidents = [
        ResidentBillingOptionModel(
          residentId: 10,
          residentName: 'Siti Rahma',
          residentPhone: '0899999999',
          houseId: 105,
          houseBlock: 'C',
          houseNumber: '02',
        ),
      ];

      fakeRepo.mockPeriods = [
        EligibleDuesPeriodModel(
          billId: 88,
          billingPeriod: '2026-11',
          amount: 35000.0,
          status: 'unpaid',
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RecordCashPaymentDialog(
              repository: fakeRepo,
              onSuccess: () {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check header
      expect(find.text('Catat Pembayaran Tunai (Cash)'), findsOneWidget);

      // Select resident
      await tester.tap(find.byKey(const Key('residentCashDropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Siti Rahma (Blok C/02)').last);
      await tester.pumpAndSettle();

      // Period should be loaded and automatically selected
      expect(find.text('2026-11'), findsOneWidget);

      // Ensure button is visible in scrollview before tapping
      await tester.ensureVisible(find.byKey(const Key('submitDirectCashBtn')));
      await tester.pumpAndSettle();

      // Tap submit to trigger confirmation summary modal
      await tester.tap(find.byKey(const Key('submitDirectCashBtn')));
      await tester.pumpAndSettle();

      // Verify Confirmation Modal appears with exact details
      expect(find.text('Konfirmasi Pembayaran Tunai'), findsOneWidget);
      expect(
          find.text(
              'Pastikan uang tunai fisik telah diterima bendahara/pengurus sebelum melanjutkan.'),
          findsOneWidget);
      expect(find.text('Konfirmasi & Catat Lunas'), findsOneWidget);

      // Confirm
      await tester.tap(find.text('Konfirmasi & Catat Lunas'));
      await tester.pumpAndSettle();

      expect(fakeRepo.recordDirectCashCalled, isTrue);
      expect(fakeRepo.lastDirectCashResidentId, 10);
      expect(fakeRepo.lastDirectCashBillId, 88);
      expect(fakeRepo.lastDirectCashAmount, 35000.0);
    });

    test(
        '6. ResidentBillingOptionModel formats display name with salutation and occupancy correctly',
        () {
      final r1 = ResidentBillingOptionModel(
        residentId: 1,
        residentName: 'Bapak Ridwan',
        residentPhone: '0812345678',
        houseId: 10,
        houseBlock: 'A1',
        houseNumber: '01',
      );
      expect(r1.occupancyIdentifier, 'Blok A1/01');
      expect(r1.displayName, 'Bapak Ridwan (Blok A1/01)');

      final r2 = ResidentBillingOptionModel(
        residentId: 2,
        residentName: 'Ibu Siti',
        residentPhone: '0812345679',
        houseId: 11,
        houseBlock: 'Blok B2',
        houseNumber: '05',
      );
      expect(r2.occupancyIdentifier, 'Blok B2/05');
      expect(r2.displayName, 'Ibu Siti (Blok B2/05)');
    });

    testWidgets(
        '7. RecordCashPaymentDialog displays all periods (including paid/pending) and blocks paid period submission',
        (WidgetTester tester) async {
      fakeRepo.mockResidents = [
        ResidentBillingOptionModel(
          residentId: 20,
          residentName: 'Bapak Ridwan',
          residentPhone: '0812345678',
          houseId: 200,
          houseBlock: 'A1',
          houseNumber: '01',
        ),
      ];

      fakeRepo.mockPeriods = [
        EligibleDuesPeriodModel(
          billId: 101,
          billingPeriod: '2026-08',
          amount: 35000.0,
          status: 'paid',
        ),
        EligibleDuesPeriodModel(
          billId: 102,
          billingPeriod: '2026-09',
          amount: 35000.0,
          status: 'pending_verification',
        ),
        EligibleDuesPeriodModel(
          billId: 103,
          billingPeriod: '2026-10',
          amount: 35000.0,
          status: 'unpaid',
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RecordCashPaymentDialog(
              repository: fakeRepo,
              onSuccess: () {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Select resident
      await tester.tap(find.byKey(const Key('residentCashDropdown')));
      await tester.pumpAndSettle();
      expect(find.text('Bapak Ridwan (Blok A1/01)').last, findsOneWidget);
      await tester.tap(find.text('Bapak Ridwan (Blok A1/01)').last);
      await tester.pumpAndSettle();

      // Open period dropdown to view all periods
      await tester.tap(find.byKey(const Key('periodCashDropdown')));
      await tester.pumpAndSettle();

      // Verify all periods are visible in dropdown with status labels
      expect(find.text('2026-08'), findsWidgets);
      expect(find.text('Lunas'), findsWidgets);
      expect(find.text('2026-09'), findsWidgets);
      expect(find.text('Menunggu'), findsWidgets);
      expect(find.text('2026-10'), findsWidgets);
      expect(find.text('Belum Bayar'), findsWidgets);

      // Select paid period '2026-08'
      await tester.tap(find.text('2026-08').last);
      await tester.pumpAndSettle();

      // Warning banner for paid period should appear
      expect(
          find.text(
              'Pembayaran untuk periode ini sudah lunas. Silakan periksa riwayat pembayaran sebelum melanjutkan.'),
          findsOneWidget);

      // Try submitting paid period
      await tester.ensureVisible(find.byKey(const Key('submitDirectCashBtn')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('submitDirectCashBtn')));
      await tester.pumpAndSettle();

      // Direct cash payment should NOT be called
      expect(fakeRepo.recordDirectCashCalled, isFalse);

      // Dismiss snackbars
      ScaffoldMessenger.of(tester.element(find.byType(RecordCashPaymentDialog)))
          .clearSnackBars();
      await tester.pumpAndSettle();

      // Select pending period '2026-09'
      await tester.tap(find.byKey(const Key('periodCashDropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('2026-09').last);
      await tester.pumpAndSettle();

      // Warning banner for pending period should appear
      expect(
          find.text(
              'Pembayaran untuk periode ini sedang menunggu verifikasi. Selesaikan verifikasi terlebih dahulu sebelum mencatat pembayaran tunai.'),
          findsOneWidget);

      // Try submitting pending period
      await tester.ensureVisible(find.byKey(const Key('submitDirectCashBtn')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('submitDirectCashBtn')));
      await tester.pumpAndSettle();

      // Direct cash payment should NOT be called
      expect(fakeRepo.recordDirectCashCalled, isFalse);

      // Dismiss snackbars
      ScaffoldMessenger.of(tester.element(find.byType(RecordCashPaymentDialog)))
          .clearSnackBars();
      await tester.pumpAndSettle();

      // Select unpaid period '2026-10'
      await tester.tap(find.byKey(const Key('periodCashDropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('2026-10').last);
      await tester.pumpAndSettle();

      // Warning banner should disappear
      expect(
          find.text(
              'Pembayaran untuk periode ini sudah lunas. Silakan periksa riwayat pembayaran sebelum melanjutkan.'),
          findsNothing);
      expect(
          find.text(
              'Pembayaran untuk periode ini sedang menunggu verifikasi. Selesaikan verifikasi terlebih dahulu sebelum mencatat pembayaran tunai.'),
          findsNothing);

      // Submit unpaid period
      await tester.ensureVisible(find.byKey(const Key('submitDirectCashBtn')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('submitDirectCashBtn')));
      await tester.pumpAndSettle();

      // Confirmation modal should appear
      expect(find.text('Konfirmasi Pembayaran Tunai'), findsOneWidget);
      await tester.tap(find.text('Konfirmasi & Catat Lunas'));
      await tester.pumpAndSettle();

      // Direct cash payment must be called for unpaid period
      expect(fakeRepo.recordDirectCashCalled, isTrue);
      expect(fakeRepo.lastDirectCashResidentId, 20);
      expect(fakeRepo.lastDirectCashBillId, 103);
    });
  });
}
