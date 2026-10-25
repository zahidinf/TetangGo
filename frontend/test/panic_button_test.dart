import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tetanggo_frontend/core/network/dio_client.dart';
import 'package:tetanggo_frontend/core/storage/secure_storage_service.dart';
import 'package:tetanggo_frontend/features/auth/domain/models/user_model.dart';
import 'package:tetanggo_frontend/features/panic/data/panic_repository.dart';
import 'package:tetanggo_frontend/features/panic/domain/models/panic_models.dart';
import 'package:tetanggo_frontend/features/panic/presentation/widgets/panic_button_fab.dart';
import 'package:tetanggo_frontend/features/panic/presentation/widgets/panic_confirmation_dialog.dart';

class FakePanicRepository extends PanicRepository {
  FakePanicRepository()
      : super(DioClient(storageService: SecureStorageService()));

  int callCount = 0;
  int delayMs = 0;
  List<Map<String, dynamic>> recordedCalls = [];
  bool shouldFail = false;
  String failureMessage = 'Simulated network error';

  @override
  Future<IncidentReportModel> sendEmergencyAlarm({
    required String category,
    String? title,
    String? description,
    double? latitude,
    double? longitude,
    String? locationSource,
    double? locationAccuracy,
    String? idempotencyKey,
  }) async {
    callCount++;
    recordedCalls.add({
      'category': category,
      'title': title,
      'description': description,
      'latitude': latitude,
      'longitude': longitude,
      'locationSource': locationSource,
      'idempotencyKey': idempotencyKey,
    });

    if (delayMs > 0) {
      await Future.delayed(Duration(milliseconds: delayMs));
    }

    if (shouldFail) {
      throw Exception(failureMessage);
    }

    return IncidentReportModel(
      id: 99,
      category: category,
      title: title ?? 'Laporan Darurat',
      description: description ?? '',
      status: 'ACTIVE',
      neighborhoodId: 1,
      reportedAt: DateTime.now(),
      latitude: latitude,
      longitude: longitude,
      locationSource: locationSource,
    );
  }
}

void main() {
  const testResident = UserModel(
    id: 42,
    salutation: 'Bapak',
    name: 'Budi Santoso',
    phone: '081234567890',
    email: 'budi@tetanggo.id',
    roleId: 2,
    role: 'RESIDENT',
    houseId: 15,
    status: 'active',
    houseBlock: 'B',
    houseNumber: '07',
  );

  group('User Story US-4.4: Panic Button Widget & Repository Tests', () {
    testWidgets(
        '1. Long-press less than 3 seconds cancels and does not trigger dialog',
        (WidgetTester tester) async {
      final fakeRepo = FakePanicRepository();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            floatingActionButton: PanicButtonFab(
              user: testResident,
              repository: fakeRepo,
            ),
          ),
        ),
      );

      final fabFinder = find.byType(PanicButtonFab);
      expect(fabFinder, findsOneWidget);

      // Press down
      final gesture = await tester.startGesture(tester.getCenter(fabFinder));
      await tester.pump(const Duration(milliseconds: 1000)); // Only 1 second

      // Indicator shows holding text
      expect(find.textContaining('Tahan...'), findsOneWidget);

      // Release before 3 seconds
      await gesture.up();
      await tester.pumpAndSettle();

      // Dialog should NOT be shown
      expect(find.byType(PanicConfirmationDialog), findsNothing);
      expect(fakeRepo.callCount, 0);
    });

    testWidgets(
        '2. Long-press full 3 seconds opens PanicConfirmationDialog with verified resident info',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final fakeRepo = FakePanicRepository();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            floatingActionButton: PanicButtonFab(
              user: testResident,
              repository: fakeRepo,
            ),
          ),
        ),
      );

      final fabFinder = find.byType(PanicButtonFab);

      // Press down and hold for full 3 seconds (driven frame-by-frame)
      final gesture = await tester.startGesture(tester.getCenter(fabFinder));
      for (int i = 0; i < 35; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await gesture.up();
      await tester.pumpAndSettle();

      // Dialog should now be open
      expect(find.byType(PanicConfirmationDialog), findsOneWidget);
      expect(find.text('Peringatan Darurat'), findsOneWidget);

      // Verified resident and house info displayed (no manual user/house ID input)
      expect(find.text('Pelapor: Bapak Budi Santoso'), findsOneWidget);
      expect(find.text('Lokasi: Blok B No. 07'), findsOneWidget);
      expect(find.text('Fallback: Alamat Rumah Terdaftar'), findsOneWidget);

      // Categories available
      expect(find.text('Maling / Kejahatan'), findsOneWidget);
      expect(find.text('Kebakaran'), findsOneWidget);
      expect(find.text('Darurat Medis'), findsOneWidget);
    });

    testWidgets(
        '3. Category selection & confirmation sends incident without crash',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final fakeRepo = FakePanicRepository();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PanicConfirmationDialog(
              user: testResident,
              repository: fakeRepo,
            ),
          ),
        ),
      );

      // Switch category to Kebakaran
      await tester.tap(find.text('Kebakaran'));
      await tester.pumpAndSettle();

      // Confirm alarm send
      await tester.tap(find.text('KIRIM ALARM SEKARANG'));
      await tester.pumpAndSettle();

      // Verifications
      expect(fakeRepo.callCount, 1);
      final call = fakeRepo.recordedCalls.first;
      expect(call['category'], 'KEBAKARAN');
      expect(call['locationSource'], 'HOUSE_FALLBACK');
      expect(call['idempotencyKey'], isNotNull);

      // Success screen shown
      expect(find.text('SINYAL DARURAT TERKIRIM!'), findsOneWidget);
      expect(find.textContaining('Laporan insiden #99 (KEBAKARAN)'),
          findsOneWidget);
    });

    testWidgets(
        '4. Concurrency & double-tap protection prevents duplicate incident dispatch',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final fakeRepo = FakePanicRepository();
      fakeRepo.delayMs = 100;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PanicConfirmationDialog(
              user: testResident,
              repository: fakeRepo,
            ),
          ),
        ),
      );

      // Tap send button
      await tester.tap(find.text('KIRIM ALARM SEKARANG'));
      // Immediate second tap while submitting (in-flight network request)
      await tester.tap(find.text('KIRIM ALARM SEKARANG'), warnIfMissed: false);
      await tester.pumpAndSettle();

      // Only exactly 1 call dispatched
      expect(fakeRepo.callCount, 1);
    });

    testWidgets(
        '5. Failure shows error banner and retry preserves idempotency key without duplicate',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final fakeRepo = FakePanicRepository();
      fakeRepo.shouldFail = true;
      fakeRepo.failureMessage = 'Koneksi ke pos satpam terputus';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PanicConfirmationDialog(
              user: testResident,
              repository: fakeRepo,
            ),
          ),
        ),
      );

      // Initial send attempt fails
      await tester.tap(find.text('KIRIM ALARM SEKARANG'));
      await tester.pumpAndSettle();

      expect(fakeRepo.callCount, 1);
      expect(find.text('Koneksi ke pos satpam terputus'), findsOneWidget);
      expect(find.text('Coba Lagi'), findsOneWidget);

      // Recover and click retry
      fakeRepo.shouldFail = false;
      await tester.tap(find.text('Coba Lagi'));
      await tester.pumpAndSettle();

      expect(fakeRepo.callCount, 2);
      // Both attempts must use the same session idempotency key to prevent duplicates
      final firstKey = fakeRepo.recordedCalls[0]['idempotencyKey'];
      final secondKey = fakeRepo.recordedCalls[1]['idempotencyKey'];
      expect(firstKey, equals(secondKey));

      // Successfully resolved
      expect(find.text('SINYAL DARURAT TERKIRIM!'), findsOneWidget);
    });
  });
}
