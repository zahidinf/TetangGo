import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tetanggo_frontend/features/invitation/data/repositories/invitation_repository.dart';
import 'package:tetanggo_frontend/features/invitation/domain/models/invitation_model.dart';
import 'package:tetanggo_frontend/features/invitation/presentation/bloc/invitation_bloc.dart';
import 'package:tetanggo_frontend/features/invitation/presentation/screens/resident_invitations_screen.dart';
import 'package:tetanggo_frontend/features/invitation/presentation/utils/qr_image_generator.dart';
import 'package:tetanggo_frontend/features/invitation/presentation/widgets/create_invitation_dialog.dart';
import 'package:tetanggo_frontend/features/invitation/presentation/widgets/qr_code_display_dialog.dart';

class MockInvitationRepository implements InvitationRepository {
  List<GuestInvitationModel> items = [];
  bool shouldFail = false;

  @override
  Future<GuestInvitationModel> createInvitation({
    required String guestName,
    required VisitType visitType,
    String? phone,
    String? notes,
    int validHours = 24,
  }) async {
    if (shouldFail) throw Exception('Gagal membuat undangan');
    final inv = GuestInvitationModel(
      id: items.length + 1,
      invitationCode: 'INV-1234-TEST',
      hostUserId: 1,
      houseId: 10,
      guestName: guestName,
      visitType: visitType,
      phone: phone,
      notes: notes,
      validFrom: DateTime.now(),
      validUntil: DateTime.now().add(Duration(hours: validHours)),
      status: InvitationStatus.active,
      qrPayload: 'eyJ2IjoiMSIsImNvZGUiOiJJTlYtMTIzNC1URVNUIiwidHlwZSI6IlRBTVUifQ==',
      createdAt: DateTime.now(),
      hostName: 'Warga Budi',
      houseBlock: 'B',
      houseNumber: '12',
    );
    items.insert(0, inv);
    return inv;
  }

  @override
  Future<List<GuestInvitationModel>> getMyInvitations({int page = 1, int limit = 50}) async {
    if (shouldFail) throw Exception('Gagal mengambil daftar undangan');
    return items;
  }

  @override
  Future<GuestInvitationModel> getInvitationDetail(int id) async {
    final found = items.firstWhere((x) => x.id == id);
    return found;
  }

  @override
  Future<void> cancelInvitation(int id, {String? reason}) async {
    if (shouldFail) throw Exception('Gagal membatalkan');
    final index = items.indexWhere((x) => x.id == id);
    if (index != -1) {
      final old = items[index];
      items[index] = GuestInvitationModel(
        id: old.id,
        invitationCode: old.invitationCode,
        hostUserId: old.hostUserId,
        houseId: old.houseId,
        guestName: old.guestName,
        visitType: old.visitType,
        phone: old.phone,
        notes: old.notes,
        validFrom: old.validFrom,
        validUntil: old.validUntil,
        status: InvitationStatus.cancelled,
        qrPayload: old.qrPayload,
        createdAt: old.createdAt,
        cancelledAt: DateTime.now(),
        cancellationReason: reason,
        hostName: old.hostName,
        houseBlock: old.houseBlock,
        houseNumber: old.houseNumber,
      );
    }
  }

  @override
  Future<void> completeInvitation(int id) async {
    if (shouldFail) throw Exception('Gagal menyelesaikan kunjungan');
    final index = items.indexWhere((element) => element.id == id);
    if (index != -1) {
      final old = items[index];
      items[index] = GuestInvitationModel(
        id: old.id,
        invitationCode: old.invitationCode,
        hostUserId: old.hostUserId,
        houseId: old.houseId,
        guestName: old.guestName,
        visitType: old.visitType,
        phone: old.phone,
        notes: old.notes,
        validFrom: old.validFrom,
        validUntil: old.validUntil,
        status: InvitationStatus.completed,
        qrPayload: old.qrPayload,
        createdAt: old.createdAt,
        hostName: old.hostName,
        houseBlock: old.houseBlock,
        houseNumber: old.houseNumber,
      );
    }
  }

  @override
  Future<VerifyInvitationResult> verifyInvitation(String rawCodeOrPayload) async {
    return const VerifyInvitationResult(
      valid: true,
      status: InvitationStatus.active,
      message: 'Sah',
    );
  }

  @override
  Future<GuestVisitModel> checkInGuest({required String code, String? notes}) async {
    return GuestVisitModel(
      id: 1,
      invitationID: 1,
      checkInAt: DateTime.now(),
      checkInBy: 1,
      status: VisitStatus.checkedIn,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  @override
  Future<GuestVisitModel> checkOutGuest({int? visitID, String? code, String? notes, bool endInvitation = false}) async {
    return GuestVisitModel(
      id: 1,
      invitationID: 1,
      checkInAt: DateTime.now(),
      checkInBy: 1,
      status: VisitStatus.checkedOut,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  @override
  Future<List<GuestVisitGroupModel>> getGroupedGuestVisits({
    int page = 1,
    int limit = 50,
    String? status,
    String? search,
    String? visitType,
  }) async {
    return [];
  }

  @override
  Future<List<GuestVisitModel>> getGuestVisits({
    int page = 1,
    int limit = 50,
    String? status,
    String? search,
    String? visitType,
  }) async {
    return [];
  }

  @override
  Future<GuestVisitModel> getGuestVisitDetail(int id) async {
    return GuestVisitModel(
      id: id,
      invitationID: 1,
      checkInAt: DateTime.now(),
      checkInBy: 1,
      status: VisitStatus.checkedIn,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }
}

void main() {
  test('InvitationModel serialization and active validity', () {
    final now = DateTime.now();
    final model = GuestInvitationModel(
      id: 1,
      invitationCode: 'INV-001',
      hostUserId: 1,
      houseId: 5,
      guestName: 'Pak Joko',
      visitType: VisitType.tamu,
      validFrom: now,
      validUntil: now.add(const Duration(hours: 24)),
      status: InvitationStatus.active,
      qrPayload: 'payload-test',
      createdAt: now,
      houseBlock: 'C',
      houseNumber: '10',
    );

    expect(model.isActive, isTrue);
    expect(model.canBeCancelled, isTrue);
    expect(model.houseDisplay, 'Blok C No. 10');

    final json = model.toJson();
    expect(json['invitation_code'], 'INV-001');
    expect(json['visit_type'], 'TAMU');
  });

  testWidgets('ResidentInvitationsScreen displays empty state and opens Create Dialog',
      (tester) async {
    final mockRepo = MockInvitationRepository();
    final bloc = InvitationBloc(repository: mockRepo);

    await tester.pumpWidget(
      MaterialApp(
        home: RepositoryProvider<InvitationRepository>.value(
          value: mockRepo,
          child: BlocProvider<InvitationBloc>.value(
            value: bloc,
            child: const ResidentInvitationsScreen(),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Undang Tamu & Kurir'), findsOneWidget);
    expect(find.text('Belum Ada Undangan Tamu'), findsOneWidget);

    // Tap create button
    await tester.tap(find.text('Buat Undangan Baru'));
    await tester.pumpAndSettle();

    expect(find.byType(CreateInvitationDialog), findsOneWidget);
    expect(find.text('Nama Tamu / Kurir *'), findsOneWidget);

    // Fill form
    await tester.enterText(find.byType(TextFormField).first, 'Bapak Joko Susilo');
    await tester.pumpAndSettle();

    // Submit
    await tester.tap(find.text('Terbitkan QR Code'));
    await tester.pumpAndSettle();

    // Dialog closed and card rendered
    expect(find.byType(CreateInvitationDialog), findsNothing);
    expect(find.text('Bapak Joko Susilo'), findsWidgets);
    expect(find.text('Kode: INV-1234-TEST'), findsOneWidget);
  });

  testWidgets('QRCodeDisplayDialog renders QR code with WhatsApp & Native Share options',
      (tester) async {
    final now = DateTime.now();
    final model = GuestInvitationModel(
      id: 1,
      invitationCode: 'INV-1234-TEST',
      hostUserId: 1,
      houseId: 5,
      guestName: 'Bapak Joko Susilo',
      visitType: VisitType.tamu,
      phone: '08123456789',
      validFrom: now,
      validUntil: now.add(const Duration(hours: 24)),
      status: InvitationStatus.active,
      qrPayload: 'eyJ2IjoiMSIsImNvZGUiOiJJTlYtMTIzNC1URVNUIiwidHlwZSI6IlRBTVUifQ==',
      createdAt: now,
      hostName: 'Budi Santoso',
      houseBlock: 'B',
      houseNumber: '12',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () => QRCodeDisplayDialog.show(ctx, invitation: model),
              child: const Text('Open QR'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open QR'));
    await tester.pumpAndSettle();

    expect(find.text('QR Undangan Masuk'), findsOneWidget);
    expect(find.text('INV-1234-TEST'), findsOneWidget);
    expect(find.text('Bapak Joko Susilo'), findsOneWidget);
    expect(find.text('Unduh Gambar'), findsOneWidget);
    expect(find.text('Kirim ke WhatsApp'), findsOneWidget);
    // Tombol Bagikan Teks sudah dihapus
    expect(find.text('Bagikan Teks'), findsNothing);
  });

  testWidgets('QrImageGenerator generates valid full invitation card PNG bytes and clean filename', (tester) async {
    final now = DateTime.now();
    final model = GuestInvitationModel(
      id: 1,
      invitationCode: 'INV-5678-ABC',
      hostUserId: 1,
      houseId: 5,
      guestName: 'Siti Aminah',
      visitType: VisitType.tamu,
      validFrom: now,
      validUntil: now.add(const Duration(hours: 24)),
      status: InvitationStatus.active,
      qrPayload: 'eyJ2IjoiMSIsImNvZGUiOiJJTlYtNTY3OC1BQkMiLCJ0eXBlIjoiVEFNVSJ9',
      createdAt: now,
      hostName: 'Budi Santoso',
      houseBlock: 'B',
      houseNumber: '12',
    );

    final filename = QrImageGenerator.getFilename(model);
    expect(filename, 'undangan_tetanggo_INV-5678-ABC.png');

    Uint8List? pngBytes;
    await tester.runAsync(() async {
      pngBytes = await QrImageGenerator.generateQrPng(invitation: model, width: 600, height: 920);
    });

    expect(pngBytes, isNotNull);
    expect(pngBytes!.length, greaterThan(100));
    // Header PNG check: 0x89 0x50 0x4E 0x47 (PNG signature)
    expect(pngBytes![0], 0x89);
    expect(pngBytes![1], 0x50);
    expect(pngBytes![2], 0x4E);
    expect(pngBytes![3], 0x47);
  });

  testWidgets('Cancel invitation flow updates status to Dibatalkan', (tester) async {
    final mockRepo = MockInvitationRepository();
    // Pre-populate
    await mockRepo.createInvitation(
      guestName: 'Tamu Mau Dibatalkan',
      visitType: VisitType.tamu,
    );

    final bloc = InvitationBloc(repository: mockRepo);

    await tester.pumpWidget(
      MaterialApp(
        home: RepositoryProvider<InvitationRepository>.value(
          value: mockRepo,
          child: BlocProvider<InvitationBloc>.value(
            value: bloc,
            child: const ResidentInvitationsScreen(),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Tamu Mau Dibatalkan'), findsOneWidget);
    expect(find.text('Aktif'), findsOneWidget);

    // Click cancel button icon
    await tester.tap(find.byIcon(Icons.cancel_outlined));
    await tester.pumpAndSettle();

    expect(find.text('Batalkan Undangan?'), findsOneWidget);

    // Confirm cancel
    await tester.tap(find.widgetWithText(ElevatedButton, 'Batalkan Undangan'));
    await tester.pumpAndSettle();

    expect(find.text('Dibatalkan'), findsOneWidget);
  });

  testWidgets('Cancelled invitation displays revocation banner and hides active QR and action buttons (US-2)',
      (tester) async {
    final now = DateTime.now();
    final cancelledModel = GuestInvitationModel(
      id: 2,
      invitationCode: 'INV-CANCELLED-99',
      hostUserId: 1,
      houseId: 5,
      guestName: 'Tamu Batal Hadir',
      visitType: VisitType.tamu,
      validFrom: now.subtract(const Duration(hours: 1)),
      validUntil: now.add(const Duration(hours: 23)),
      status: InvitationStatus.cancelled,
      qrPayload: '', // Zeroed out upon cancellation
      cancelledAt: now,
      cancellationReason: 'Acara dibatalkan',
      createdAt: now.subtract(const Duration(hours: 1)),
      hostName: 'Budi Santoso',
      houseBlock: 'B',
      houseNumber: '12',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () => QRCodeDisplayDialog.show(ctx, invitation: cancelledModel),
              child: const Text('Open Cancelled QR'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Cancelled QR'));
    await tester.pumpAndSettle();

    // Pastikan QR aktif TIDAK ditampilkan
    expect(find.text('QR DIBATALKAN'), findsOneWidget);
    expect(find.text('Undangan Dibatalkan — QR Tidak Berlaku'), findsOneWidget);
    expect(find.text('Tidak Berlaku Lagi'), findsOneWidget);
    expect(find.text('Acara dibatalkan'), findsOneWidget);

    // Pastikan tombol aksi aktif tidak muncul
    expect(find.text('Unduh QR'), findsNothing);
    expect(find.text('Kirim ke WhatsApp'), findsNothing);
    expect(find.text('Bagikan Teks'), findsNothing);

    // Tombol tutup tetap ada
    expect(find.text('Tutup'), findsOneWidget);
  });

  testWidgets('US-5.2 Resident ends invitation updates status to Diakhiri and disables QR', (tester) async {
    final mockRepo = MockInvitationRepository();
    final created = await mockRepo.createInvitation(
      guestName: 'Tamu Sudah Selesai',
      visitType: VisitType.tamu,
    );
    // Simulasikan tamu sudah checkout (completedVisitsCount = 1, tidak ada sesi aktif)
    mockRepo.items[0] = GuestInvitationModel(
      id: created.id,
      invitationCode: created.invitationCode,
      hostUserId: created.hostUserId,
      houseId: created.houseId,
      guestName: created.guestName,
      visitType: created.visitType,
      validFrom: created.validFrom,
      validUntil: created.validUntil,
      status: created.status,
      qrPayload: created.qrPayload,
      createdAt: created.createdAt,
      hostName: created.hostName,
      houseBlock: created.houseBlock,
      houseNumber: created.houseNumber,
      hasActiveSession: false,
      completedVisitsCount: 1,
    );

    final bloc = InvitationBloc(repository: mockRepo);

    await tester.pumpWidget(
      MaterialApp(
        home: RepositoryProvider<InvitationRepository>.value(
          value: mockRepo,
          child: BlocProvider<InvitationBloc>.value(
            value: bloc,
            child: const ResidentInvitationsScreen(),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Tamu Sudah Selesai'), findsOneWidget);
    expect(find.text('Aktif'), findsOneWidget);

    // Tap complete button (Akhiri Undangan)
    await tester.tap(find.byIcon(Icons.check_circle_outline));
    await tester.pumpAndSettle();

    expect(find.descendant(of: find.byType(AlertDialog), matching: find.widgetWithText(ElevatedButton, 'Akhiri Undangan')), findsOneWidget);

    // Confirm complete
    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.widgetWithText(ElevatedButton, 'Akhiri Undangan')));
    await tester.pumpAndSettle();

    expect(find.text('Diakhiri'), findsOneWidget);

    // Aksi akhiri dan batalkan hilang setelah diakhiri
    expect(find.byIcon(Icons.check_circle_outline), findsNothing);
    expect(find.byIcon(Icons.cancel_outlined), findsNothing);
  });

  testWidgets('US-5.2 Button visibility matrix for Resident Invitations', (tester) async {
    final now = DateTime.now();
    // 1. Undangan aktif & belum pernah dikunjungi: Batalkan muncul, Akhiri TIDAK muncul
    final invNeverVisited = GuestInvitationModel(
      id: 1,
      invitationCode: 'INV-1',
      hostUserId: 1,
      houseId: 10,
      guestName: 'Tamu Baru',
      visitType: VisitType.tamu,
      validFrom: now.subtract(const Duration(hours: 1)),
      validUntil: now.add(const Duration(hours: 23)),
      status: InvitationStatus.active,
      qrPayload: 'payload1',
      createdAt: now,
      hasActiveSession: false,
      completedVisitsCount: 0,
    );
    expect(invNeverVisited.canBeCancelled, isTrue);
    expect(invNeverVisited.canBeCompleted, isFalse);

    // 2. Tamu sedang di dalam (ada sesi aktif): Batalkan TIDAK muncul, Akhiri TIDAK muncul
    final invGuestInside = GuestInvitationModel(
      id: 2,
      invitationCode: 'INV-2',
      hostUserId: 1,
      houseId: 10,
      guestName: 'Tamu Di Dalam',
      visitType: VisitType.tamu,
      validFrom: now.subtract(const Duration(hours: 2)),
      validUntil: now.add(const Duration(hours: 22)),
      status: InvitationStatus.active,
      qrPayload: 'payload2',
      createdAt: now,
      hasActiveSession: true,
      completedVisitsCount: 0,
    );
    expect(invGuestInside.canBeCancelled, isFalse);
    expect(invGuestInside.canBeCompleted, isFalse);

    // 3. Tamu sudah checkout, masa berlaku masih ada: Akhiri MUNCUL, Batalkan TIDAK muncul
    final invCheckedOut = GuestInvitationModel(
      id: 3,
      invitationCode: 'INV-3',
      hostUserId: 1,
      houseId: 10,
      guestName: 'Tamu Sudah Checkout',
      visitType: VisitType.tamu,
      validFrom: now.subtract(const Duration(hours: 3)),
      validUntil: now.add(const Duration(hours: 21)),
      status: InvitationStatus.active,
      qrPayload: 'payload3',
      createdAt: now,
      hasActiveSession: false,
      completedVisitsCount: 1,
    );
    expect(invCheckedOut.canBeCancelled, isFalse);
    expect(invCheckedOut.canBeCompleted, isTrue);

    // 4. Undangan sudah diakhiri (COMPLETED): Akhiri TIDAK muncul, Batalkan TIDAK muncul
    final invCompleted = GuestInvitationModel(
      id: 4,
      invitationCode: 'INV-4',
      hostUserId: 1,
      houseId: 10,
      guestName: 'Tamu Selesai',
      visitType: VisitType.tamu,
      validFrom: now.subtract(const Duration(hours: 4)),
      validUntil: now.add(const Duration(hours: 20)),
      status: InvitationStatus.completed,
      qrPayload: '',
      createdAt: now,
      hasActiveSession: false,
      completedVisitsCount: 1,
    );
    expect(invCompleted.canBeCancelled, isFalse);
    expect(invCompleted.canBeCompleted, isFalse);

    // 5. Undangan dibatalkan (CANCELLED): Akhiri TIDAK muncul, Batalkan TIDAK muncul
    final invCancelled = GuestInvitationModel(
      id: 5,
      invitationCode: 'INV-5',
      hostUserId: 1,
      houseId: 10,
      guestName: 'Tamu Batal',
      visitType: VisitType.tamu,
      validFrom: now.subtract(const Duration(hours: 5)),
      validUntil: now.add(const Duration(hours: 19)),
      status: InvitationStatus.cancelled,
      qrPayload: '',
      createdAt: now,
      hasActiveSession: false,
      completedVisitsCount: 0,
    );
    expect(invCancelled.canBeCancelled, isFalse);
    expect(invCancelled.canBeCompleted, isFalse);

    // 6. Masa berlaku habis (EXPIRED): Akhiri TIDAK muncul, Batalkan TIDAK muncul
    final invExpired = GuestInvitationModel(
      id: 6,
      invitationCode: 'INV-6',
      hostUserId: 1,
      houseId: 10,
      guestName: 'Tamu Expired',
      visitType: VisitType.tamu,
      validFrom: now.subtract(const Duration(hours: 26)),
      validUntil: now.subtract(const Duration(hours: 2)),
      status: InvitationStatus.active,
      qrPayload: 'payload6',
      createdAt: now,
      hasActiveSession: false,
      completedVisitsCount: 1,
    );
    expect(invExpired.canBeCancelled, isFalse);
    expect(invExpired.canBeCompleted, isFalse);
  });
}
