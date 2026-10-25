import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tetanggo_frontend/features/auth/domain/models/user_model.dart';
import 'package:tetanggo_frontend/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:tetanggo_frontend/features/auth/presentation/bloc/auth_state.dart';
import 'package:tetanggo_frontend/features/security/data/security_repository.dart';
import 'package:tetanggo_frontend/features/security/data/security_siren_service.dart';
import 'package:tetanggo_frontend/features/security/data/security_websocket_service.dart';
import 'package:tetanggo_frontend/features/security/domain/models/security_models.dart';
import 'package:tetanggo_frontend/features/security/presentation/security_standby_screen.dart';
import 'package:tetanggo_frontend/features/security/presentation/widgets/emergency_fullscreen_dialog.dart';

// --- Mocks ---
class MockAuthBloc extends Fake implements AuthBloc {
  final AuthState _state;
  final _controller = StreamController<AuthState>.broadcast();

  MockAuthBloc(this._state);

  @override
  AuthState get state => _state;

  @override
  Stream<AuthState> get stream => _controller.stream;
}

class FakeSecurityRepository extends Fake implements SecurityRepository {
  List<SecurityAssignmentModel> assignmentsToReturn = [];
  List<SecurityIncidentModel> activeIncidentsToReturn = [];
  SecurityIncidentModel? incidentDetailToReturn;

  bool acknowledgeCalled = false;
  int? acknowledgedId;
  String? acknowledgeNotes;
  Exception? acknowledgeException;

  bool resolveCalled = false;
  int? resolvedId;
  String? resolvedNotes;
  Exception? resolveException;

  @override
  Future<List<SecurityAssignmentModel>> getMyAssignments() async {
    return assignmentsToReturn;
  }

  @override
  Future<List<SecurityIncidentModel>> getActiveIncidents() async {
    return activeIncidentsToReturn;
  }

  @override
  Future<SecurityIncidentModel> getIncidentDetail(int id) async {
    if (incidentDetailToReturn != null) {
      return incidentDetailToReturn!;
    }
    throw Exception('Detail not found');
  }

  @override
  Future<SecurityIncidentModel> acknowledgeIncident(int id,
      {String? notes}) async {
    acknowledgeCalled = true;
    acknowledgedId = id;
    acknowledgeNotes = notes;

    if (acknowledgeException != null) {
      throw acknowledgeException!;
    }

    if (incidentDetailToReturn != null) {
      return incidentDetailToReturn!;
    }
    throw Exception('Acknowledge failed');
  }

  @override
  Future<SecurityIncidentModel> resolveIncident(
      int id, String resolutionNotes) async {
    resolveCalled = true;
    resolvedId = id;
    resolvedNotes = resolutionNotes;

    if (resolveException != null) {
      throw resolveException!;
    }

    if (incidentDetailToReturn != null) {
      return incidentDetailToReturn!;
    }
    throw Exception('Resolve failed');
  }
}

class FakeSecurityWebSocketService extends Fake
    implements SecurityWebSocketService {
  final _controller = StreamController<Map<String, dynamic>>.broadcast();

  @override
  final ValueNotifier<WsConnectionStatus> statusNotifier =
      ValueNotifier<WsConnectionStatus>(WsConnectionStatus.connected);

  @override
  Stream<Map<String, dynamic>> get eventStream => _controller.stream;

  @override
  WsConnectionStatus get status => statusNotifier.value;

  @override
  Future<void> connect() async {}

  @override
  void disconnect() {}

  void emitEvent(Map<String, dynamic> event) {
    _controller.add(event);
  }
}

class FakeSecuritySirenService extends Fake implements SecuritySirenService {
  bool sirenStarted = false;
  bool sirenStopped = false;
  bool sirenMuted = false;

  @override
  final ValueNotifier<bool> isPlayingNotifier = ValueNotifier<bool>(false);
  @override
  final ValueNotifier<bool> isMutedNotifier = ValueNotifier<bool>(false);

  @override
  bool get isPlaying => sirenStarted && !sirenStopped;

  @override
  bool get isMuted => sirenMuted;

  @override
  void startSiren() {
    sirenStarted = true;
    sirenStopped = false;
    isPlayingNotifier.value = true;
  }

  @override
  void stopSiren() {
    sirenStopped = true;
    isPlayingNotifier.value = false;
  }

  @override
  void muteSiren() {
    sirenMuted = true;
    isMutedNotifier.value = true;
  }

  @override
  void unmuteSiren() {
    sirenMuted = false;
    isMutedNotifier.value = false;
  }
}

void main() {
  const securityUser = UserModel(
    id: 10,
    name: 'Pak Satpam Budi',
    phone: '081234567890',
    email: 'satpam@tetanggo.com',
    roleId: 7,
    role: 'SECURITY',
    status: 'active',
    houseId: null,
  );

  const testAssignment = SecurityAssignmentModel(
    id: 1,
    userId: 10,
    neighborhoodId: 101,
    neighborhoodName: 'RT 01 Lingkungan A',
    neighborhoodCode: 'RT01A',
    isActive: true,
  );

  final activeIncident = SecurityIncidentModel(
    id: 100,
    category: 'KEJAHATAN',
    title: 'Pencurian Spion Mobil',
    description: 'Terlihat orang mencurigakan di depan rumah B2-15',
    status: 'ACTIVE',
    neighborhoodId: 101,
    neighborhoodName: 'RT 01 Lingkungan A',
    houseBlock: 'B2',
    houseNumber: '15',
    reporterId: 44,
    reporterName: 'Pak RT Bambang',
    reporterPhone: '081987654321',
    reportedAt: DateTime.now(),
  );

  final acknowledgedIncident = activeIncident.copyWith(
    status: 'ACKNOWLEDGED',
    assignedSecurityId: 10,
    assignedSecurityName: 'Pak Satpam Budi',
    handlingStartedAt: DateTime.now(),
  );

  final resolvedIncident = acknowledgedIncident.copyWith(
    status: 'RESOLVED',
    resolvedAt: DateTime.now(),
    resolutionNotes: 'Pelaku telah diamankan bersama Babinsa dan warga.',
  );

  Widget createTestWidget({
    required FakeSecurityRepository repo,
    required FakeSecurityWebSocketService ws,
    required FakeSecuritySirenService siren,
  }) {
    final mockBloc = MockAuthBloc(const AuthState(
      status: AuthStatus.authenticated,
      user: securityUser,
    ));

    return MaterialApp(
      home: BlocProvider<AuthBloc>.value(
        value: mockBloc,
        child: SecurityStandbyScreen(
          repository: repo,
          wsService: ws,
          sirenService: siren,
        ),
      ),
    );
  }

  group('US-4.6: Alur Penanganan Insiden oleh Security Tests', () {
    testWidgets(
        '1. Alur lengkap penanganan: ACTIVE -> Sedang Ditangani -> Situasi Terkendali dengan Catatan Akhir',
        (tester) async {
      final repo = FakeSecurityRepository()
        ..assignmentsToReturn = [testAssignment]
        ..activeIncidentsToReturn = [activeIncident]
        ..incidentDetailToReturn = activeIncident;
      final ws = FakeSecurityWebSocketService();
      final siren = FakeSecuritySirenService();

      await tester.pumpWidget(createTestWidget(
        repo: repo,
        ws: ws,
        siren: siren,
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Verify fullscreen dialog popped up with "Sedang Ditangani"
      expect(find.byType(EmergencyFullscreenDialog), findsOneWidget);
      expect(find.text('Sedang Ditangani'), findsOneWidget);
      expect(siren.sirenStarted, isTrue);

      // Transition to ACKNOWLEDGED
      repo.incidentDetailToReturn = acknowledgedIncident;
      repo.activeIncidentsToReturn = [acknowledgedIncident];

      // Tap "Sedang Ditangani"
      await tester.tap(find.text('Sedang Ditangani'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(repo.acknowledgeCalled, isTrue);
      expect(repo.acknowledgedId, equals(100));
      expect(siren.sirenStopped, isTrue);

      // Button now dynamically changes to "Situasi Terkendali"
      expect(find.text('Situasi Terkendali'), findsOneWidget);
      expect(find.text('Petugas Penanganan'), findsOneWidget);
      expect(find.text('Pak Satpam Budi'), findsWidgets);

      // Tap "Situasi Terkendali" to resolve
      await tester.tap(find.text('Situasi Terkendali'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Check resolution notes confirmation dialog appears
      expect(find.byKey(const Key('resolutionNotesDialog')), findsOneWidget);
      expect(find.byKey(const Key('resolutionNotesField')), findsOneWidget);

      // Test validation: empty notes cannot be submitted
      await tester.tap(find.byKey(const Key('confirmResolveBtn')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Catatan akhir penyelesaian wajib diisi'), findsOneWidget);
      expect(repo.resolveCalled, isFalse);

      // Enter valid notes and confirm
      repo.incidentDetailToReturn = resolvedIncident;
      repo.activeIncidentsToReturn = []; // Resolved, no longer in active list

      await tester.enterText(
          find.byKey(const Key('resolutionNotesField')),
          'Pelaku telah diamankan bersama Babinsa dan warga.');
      await tester.tap(find.byKey(const Key('confirmResolveBtn')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Verify resolve called with backend arguments
      expect(repo.resolveCalled, isTrue);
      expect(repo.resolvedId, equals(100));
      expect(repo.resolvedNotes,
          equals('Pelaku telah diamankan bersama Babinsa dan warga.'));
      expect(siren.sirenStopped, isTrue);

      // Dialog closed & Standby screen refreshed
      expect(find.byType(EmergencyFullscreenDialog), findsNothing);
      expect(find.text('Kondisi Lingkungan Aman'), findsOneWidget);
    });

    testWidgets(
        '2. Konflik penanganan: Petugas lain sudah mengambil insiden (409 Conflict) -> sinkronkan data & tolak sukses palsu',
        (tester) async {
      final handledByOther = activeIncident.copyWith(
        status: 'ACKNOWLEDGED',
        assignedSecurityId: 99,
        assignedSecurityName: 'Satpam Joko',
        handlingStartedAt: DateTime.now(),
      );

      final repo = FakeSecurityRepository()
        ..assignmentsToReturn = [testAssignment]
        ..activeIncidentsToReturn = [activeIncident]
        ..incidentDetailToReturn = activeIncident
        ..acknowledgeException = Exception(
            'insiden ini sudah diakui dan sedang dalam penanganan petugas keamanan lain');
      final ws = FakeSecurityWebSocketService();
      final siren = FakeSecuritySirenService();

      await tester.pumpWidget(createTestWidget(
        repo: repo,
        ws: ws,
        siren: siren,
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Sedang Ditangani'), findsOneWidget);

      // When acknowledge fails, backend returns conflict; repo getIncidentDetail returns handledByOther
      repo.incidentDetailToReturn = handledByOther;

      await tester.tap(find.text('Sedang Ditangani'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Verifikasi pesan konflik tampil & status tersinkronisasi ke data backend aktual
      expect(
          find.textContaining(
              'insiden ini sudah diakui dan sedang dalam penanganan petugas keamanan lain'),
          findsOneWidget);
      expect(find.text('Satpam Joko'), findsWidgets);
      // Tombol berubah sesuai status aktual backend (menjadi Situasi Terkendali)
      expect(find.text('Situasi Terkendali'), findsOneWidget);
    });

    testWidgets(
        '3. Penugasan dicabut (403 Forbidden): Operasi ditolak dan status tetap akurat',
        (tester) async {
      final repo = FakeSecurityRepository()
        ..assignmentsToReturn = [testAssignment]
        ..activeIncidentsToReturn = [activeIncident]
        ..incidentDetailToReturn = activeIncident
        ..acknowledgeException = Exception(
            'petugas keamanan tidak memiliki surat tugas aktif di lingkungan insiden ini');
      final ws = FakeSecurityWebSocketService();
      final siren = FakeSecuritySirenService();

      await tester.pumpWidget(createTestWidget(
        repo: repo,
        ws: ws,
        siren: siren,
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      await tester.tap(find.text('Sedang Ditangani'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(
          find.textContaining('tidak memiliki surat tugas aktif'), findsOneWidget);
      // Tetap tidak menghasilkan sukses palsu
      expect(find.text('Sedang Ditangani'), findsOneWidget);
    });

    testWidgets(
        '4. Kegagalan jaringan / timeout: Tombol reset status pengiriman dan data tidak rusak',
        (tester) async {
      final repo = FakeSecurityRepository()
        ..assignmentsToReturn = [testAssignment]
        ..activeIncidentsToReturn = [activeIncident]
        ..incidentDetailToReturn = activeIncident
        ..acknowledgeException = Exception('Koneksi timeout ke server');
      final ws = FakeSecurityWebSocketService();
      final siren = FakeSecuritySirenService();

      await tester.pumpWidget(createTestWidget(
        repo: repo,
        ws: ws,
        siren: siren,
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      await tester.tap(find.text('Sedang Ditangani'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Error ditampilkan
      expect(find.textContaining('Koneksi timeout ke server'), findsOneWidget);
      // Tombol aktif kembali dan memungkinkan retry
      expect(find.text('Sedang Ditangani'), findsOneWidget);
    });

    testWidgets(
        '5. Sinkronisasi antar perangkat via WebSocket: Status diperbarui seketika dan sirene dimatikan',
        (tester) async {
      final repo = FakeSecurityRepository()
        ..assignmentsToReturn = [testAssignment]
        ..activeIncidentsToReturn = [activeIncident]
        ..incidentDetailToReturn = activeIncident;
      final ws = FakeSecurityWebSocketService();
      final siren = FakeSecuritySirenService();

      await tester.pumpWidget(createTestWidget(
        repo: repo,
        ws: ws,
        siren: siren,
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Sedang Ditangani'), findsOneWidget);
      expect(siren.sirenStarted, isTrue);

      // Event masuk dari perangkat petugas lain: INCIDENT_ACKNOWLEDGED
      repo.incidentDetailToReturn = acknowledgedIncident;
      ws.emitEvent({
        'event_id': 'evt_ack_456',
        'event_type': 'INCIDENT_ACKNOWLEDGED',
        'neighborhood_id': 101,
        'data': {
          'incident_id': 100,
          'status': 'ACKNOWLEDGED',
        },
      });

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // UI dialog berubah seketika tanpa refresh manual
      expect(find.text('Situasi Terkendali'), findsOneWidget);
      expect(siren.sirenStopped, isTrue);

      // Event masuk: INCIDENT_RESOLVED
      repo.incidentDetailToReturn = resolvedIncident;
      ws.emitEvent({
        'event_id': 'evt_res_789',
        'event_type': 'INCIDENT_RESOLVED',
        'neighborhood_id': 101,
        'data': {
          'incident_id': 100,
          'status': 'RESOLVED',
        },
      });

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Insiden Telah Diselesaikan'), findsOneWidget);
    });
  });
}
