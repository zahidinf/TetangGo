import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tetanggo_frontend/features/auth/domain/models/user_model.dart';
import 'package:tetanggo_frontend/features/invitation/data/repositories/invitation_repository.dart';
import 'package:tetanggo_frontend/features/invitation/domain/models/invitation_model.dart';
import 'package:tetanggo_frontend/features/invitation/presentation/screens/security_guestbook_screen.dart';

class MockGuestbookRepo implements InvitationRepository {
  List<GuestVisitModel> mockVisits = [
    GuestVisitModel(
      id: 1,
      invitationID: 101,
      invitationCode: 'INV-TEST-001',
      guestName: 'Pak Joko Satpam',
      visitType: VisitType.tamu,
      checkInAt: DateTime.now().subtract(const Duration(minutes: 30)),
      checkInBy: 3,
      checkInByName: 'Satpam Pos 1',
      status: VisitStatus.checkedIn,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      hostName: 'Budi Santoso',
      houseBlock: 'B',
      houseNumber: '10',
    ),
  ];

  @override
  Future<List<GuestVisitModel>> getGuestVisits({
    int page = 1,
    int limit = 50,
    String? status,
    String? search,
    String? visitType,
  }) async {
    return mockVisits;
  }

  @override
  Future<List<GuestVisitGroupModel>> getGroupedGuestVisits({
    int page = 1,
    int limit = 50,
    String? status,
    String? search,
    String? visitType,
  }) async {
    final Map<int, List<GuestVisitModel>> byInv = {};
    for (final v in mockVisits) {
      byInv.putIfAbsent(v.invitationID, () => []).add(v);
    }
    return byInv.entries.map((entry) {
      final visits = entry.value;
      final first = visits.first;
      final hasActive = visits.any((v) => v.status == VisitStatus.checkedIn);
      final activeVisit = visits.where((v) => v.status == VisitStatus.checkedIn).firstOrNull;
      return GuestVisitGroupModel(
        invitationID: first.invitationID,
        invitationCode: first.invitationCode ?? 'INV-001',
        guestName: first.guestName ?? 'Tamu',
        visitType: first.visitType,
        hostName: first.hostName ?? 'Budi',
        houseBlock: first.houseBlock ?? 'A',
        houseNumber: first.houseNumber ?? '10',
        invitationStatus: InvitationStatus.active,
        validFrom: DateTime.now().subtract(const Duration(hours: 1)),
        validUntil: DateTime.now().add(const Duration(hours: 23)),
        hasActiveSession: hasActive,
        activeVisitID: activeVisit?.id,
        firstCheckInAt: first.checkInAt,
        latestActivityAt: visits.last.checkOutAt ?? visits.last.checkInAt,
        totalVisits: visits.length,
        visits: visits,
      );
    }).toList();
  }

  @override
  Future<VerifyInvitationResult> verifyInvitation(String rawCodeOrPayload) async {
    if (rawCodeOrPayload == 'VALID-CODE') {
      return VerifyInvitationResult(
        valid: true,
        status: InvitationStatus.active,
        message: 'Undangan aktif dan sah.',
        invitation: GuestInvitationModel(
          id: 1,
          invitationCode: 'INV-VALID-01',
          hostUserId: 1,
          houseId: 1,
          guestName: 'Tamu Resmi',
          visitType: VisitType.tamu,
          validFrom: DateTime.now(),
          validUntil: DateTime.now().add(const Duration(hours: 24)),
          status: InvitationStatus.active,
          qrPayload: 'payload',
          createdAt: DateTime.now(),
        ),
      );
    }
    return const VerifyInvitationResult(
      valid: false,
      status: InvitationStatus.cancelled,
      message: 'Undangan telah dibatalkan.',
    );
  }

  @override
  Future<GuestVisitModel> checkInGuest({required String code, String? notes}) async {
    final v = GuestVisitModel(
      id: 2,
      invitationID: 102,
      invitationCode: code,
      guestName: 'Tamu Baru',
      visitType: VisitType.tamu,
      checkInAt: DateTime.now(),
      checkInBy: 3,
      status: VisitStatus.checkedIn,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    mockVisits.add(v);
    return v;
  }

  @override
  Future<GuestVisitModel> checkOutGuest({int? visitID, String? code, String? notes, bool endInvitation = false}) async {
    final v = mockVisits.firstWhere((x) => x.id == visitID);
    return GuestVisitModel(
      id: v.id,
      invitationID: v.invitationID,
      checkInAt: v.checkInAt,
      checkInBy: v.checkInBy,
      checkOutAt: DateTime.now(),
      checkOutBy: 3,
      status: VisitStatus.checkedOut,
      createdAt: v.createdAt,
      updatedAt: DateTime.now(),
    );
  }

  @override
  Future<GuestVisitModel> getGuestVisitDetail(int id) async {
    return mockVisits.firstWhere((x) => x.id == id);
  }

  @override
  Future<GuestInvitationModel> createInvitation({
    required String guestName,
    required VisitType visitType,
    String? phone,
    String? notes,
    int validHours = 24,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<List<GuestInvitationModel>> getMyInvitations({int page = 1, int limit = 50}) async {
    return [];
  }

  @override
  Future<GuestInvitationModel> getInvitationDetail(int id) async {
    throw UnimplementedError();
  }

  @override
  Future<void> cancelInvitation(int id, {String? reason}) async {}

  @override
  Future<void> completeInvitation(int id) async {}
}

void main() {
  testWidgets('1. Security sees scanner tab and operational controls', (tester) async {
    final repo = MockGuestbookRepo();
    const securityUser = UserModel(
      id: 3,
      name: 'Satpam Pak Herman',
      email: 'satpam@tetanggo.id',
      phone: '08123456789',
      roleId: 7,
      role: 'SECURITY',
      status: 'active',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: RepositoryProvider<InvitationRepository>.value(
          value: repo,
          child: const SecurityGuestbookScreen(user: securityUser),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Pastikan judul Buku Tamu Satpam ada
    expect(find.text('Buku Tamu Satpam'), findsOneWidget);
    expect(find.text('Operasional Pemindaian & Log Akses Gerbang'), findsOneWidget);

    // Tab scanner ada untuk Satpam
    expect(find.text('Pemindai QR Gerbang'), findsOneWidget);
    expect(find.text('Riwayat Kunjungan'), findsOneWidget);

    // Form input manual tersedia
    expect(find.text('Input Manual Kode Undangan'), findsOneWidget);
    expect(find.text('Verifikasi'), findsOneWidget);
  });

  testWidgets('2. Admin and Pengurus (Ketua, Bendahara, etc.) see read-only history without scanner', (tester) async {
    final repo = MockGuestbookRepo();
    const adminUser = UserModel(
      id: 2,
      name: 'Admin TetangGo',
      email: 'admin@tetanggo.id',
      phone: '08123456788',
      roleId: 1,
      role: 'ADMIN',
      status: 'active',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: RepositoryProvider<InvitationRepository>.value(
          value: repo,
          child: const SecurityGuestbookScreen(user: adminUser),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Buku Tamu Satpam'), findsOneWidget);
    expect(find.text('Log Kunjungan Tamu & Kurir (Mode Read-Only)'), findsOneWidget);

    // Scanner TIDAK boleh ada untuk Admin
    expect(find.text('Pemindai QR Gerbang'), findsNothing);
    expect(find.text('Input Manual Kode Undangan'), findsNothing);

    // Menampilkan riwayat kunjungan
    expect(find.text('Pak Joko Satpam'), findsOneWidget);
    expect(find.text('Sedang Berkunjung'), findsOneWidget);

    // Tombol Check-Out operasional TIDAK boleh ada untuk Admin
    expect(find.text('Check-Out'), findsNothing);
  });

  testWidgets('3. Tab switching back and forth 10 times does not throw MobileScannerController disposed error', (tester) async {
    final repo = MockGuestbookRepo();
    const securityUser = UserModel(
      id: 3,
      name: 'Satpam Pak Herman',
      email: 'satpam@tetanggo.id',
      phone: '08123456789',
      roleId: 7,
      role: 'SECURITY',
      status: 'active',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: RepositoryProvider<InvitationRepository>.value(
          value: repo,
          child: const SecurityGuestbookScreen(user: securityUser),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final scannerTab = find.text('Pemindai QR Gerbang');
    final historyTab = find.text('Riwayat Kunjungan');

    expect(scannerTab, findsOneWidget);
    expect(historyTab, findsOneWidget);

    // Switch between tabs 10 times
    for (int i = 0; i < 10; i++) {
      await tester.tap(historyTab);
      await tester.pumpAndSettle();

      await tester.tap(scannerTab);
      await tester.pumpAndSettle();
    }

    // Verify scanner and manual input are still intact and no unhandled exceptions
    expect(find.text('Input Manual Kode Undangan'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('4. History tab renders grouped invitation card and toggles cycle details',
      (WidgetTester tester) async {
    final repo = MockGuestbookRepo();
    final securityUser = UserModel(
      id: 3,
      name: 'Satpam Pak Herman',
      email: 'satpam@tetanggo.id',
      phone: '08123456789',
      roleId: 7,
      role: 'SECURITY',
      status: 'active',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: RepositoryProvider<InvitationRepository>.value(
          value: repo,
          child: SecurityGuestbookScreen(user: securityUser),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Buka tab Riwayat Kunjungan
    await tester.tap(find.text('Riwayat Kunjungan'));
    await tester.pumpAndSettle();

    // Pastikan satu kartu grup per kode undangan muncul
    expect(find.text('Pak Joko Satpam'), findsOneWidget);
    expect(find.text('Total Sesi: 1'), findsOneWidget);

    // Detail siklus tersembunyi sebelum expand
    expect(find.text('Rincian Seluruh Siklus Kunjungan (1 Sesi)'), findsNothing);

    // Klik tombol expand riwayat sesi
    final expandBtn = find.byTooltip('Buka Riwayat Sesi');
    expect(expandBtn, findsOneWidget);
    await tester.tap(expandBtn);
    await tester.pumpAndSettle();

    // Rincian siklus sekarang terlihat
    expect(find.text('Rincian Seluruh Siklus Kunjungan (1 Sesi)'), findsOneWidget);
    expect(find.textContaining('Masuk:'), findsOneWidget);
    expect(find.textContaining('Status: Masih Berada di Dalam'), findsOneWidget);

    // Tombol checkout pada kartu grup memunculkan dialog pilihan
    final checkoutBtn = find.widgetWithText(OutlinedButton, 'Checkout');
    expect(checkoutBtn, findsOneWidget);
    await tester.tap(checkoutBtn);
    await tester.pumpAndSettle();

    expect(find.text('Pilihan Check-Out'), findsOneWidget);
    expect(find.text('Checkout saja'), findsOneWidget);
    expect(find.text('Checkout dan akhiri undangan'), findsOneWidget);
  });
}
