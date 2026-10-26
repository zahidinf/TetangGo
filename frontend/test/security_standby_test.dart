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
    if (incidentDetailToReturn != null) {
      return incidentDetailToReturn!;
    }
    throw Exception('Acknowledge failed');
  }

  @override
  Future<SecurityIncidentModel> resolveIncident(
      int id, String resolutionNotes) async {
    throw UnimplementedError();
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

  bool disconnectCalled = false;
  bool disposeCalled = false;
  int connectCallCount = 0;

  @override
  Future<void> connect() async {
    connectCallCount++;
  }

  @override
  void disconnect() {
    disconnectCalled = true;
  }

  @override
  void dispose() {
    disposeCalled = true;
    statusNotifier.dispose();
  }

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
    houseId: null, // No housing linkage
  );

  final testAssignment1 = SecurityAssignmentModel(
    id: 1,
    userId: 10,
    neighborhoodId: 101,
    neighborhoodName: 'RT 01 Lingkungan A',
    neighborhoodCode: 'RT01A',
    isActive: true,
  );

  final testAssignment2 = SecurityAssignmentModel(
    id: 2,
    userId: 10,
    neighborhoodId: 102,
    neighborhoodName: 'RT 02 Lingkungan B',
    neighborhoodCode: 'RT02B',
    isActive: true,
  );

  final testIncident = SecurityIncidentModel(
    id: 99,
    category: 'KEJAHATAN',
    title: 'Pencurian Motor',
    description: 'Ada maling membobol gembok',
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

  Widget createWidgetUnderTest({
    required UserModel user,
    required FakeSecurityRepository repo,
    required FakeSecurityWebSocketService ws,
    required FakeSecuritySirenService siren,
  }) {
    final mockBloc = MockAuthBloc(AuthState(
      status: AuthStatus.authenticated,
      user: user,
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

  group('US-4.5: Security Standby & Emergency Alarms Tests', () {
    testWidgets(
        '1. Security login without housing succeeds & renders Standby Pos Satpam',
        (tester) async {
      final repo = FakeSecurityRepository()
        ..assignmentsToReturn = [testAssignment1]
        ..activeIncidentsToReturn = [];
      final ws = FakeSecurityWebSocketService();
      final siren = FakeSecuritySirenService();

      await tester.pumpWidget(createWidgetUnderTest(
        user: securityUser,
        repo: repo,
        ws: ws,
        siren: siren,
      ));
      await tester.pumpAndSettle();

      expect(find.text('SIAGA POS SATPAM'), findsOneWidget);
      expect(find.text('Petugas: Pak Satpam Budi'), findsOneWidget);
      expect(find.text('Lingkungan Tugas Aktif: RT 01 Lingkungan A'),
          findsOneWidget);
      expect(find.text('Kondisi Lingkungan Aman'), findsOneWidget);
      // US-5.2: Buku Tamu Satpam tab is accessible in standby portal
      expect(find.text('Buku Tamu Satpam'), findsOneWidget);
    });

    testWidgets('2. Denies access if security officer has no active assignment',
        (tester) async {
      final repo = FakeSecurityRepository()
        ..assignmentsToReturn = []; // Empty assignments
      final ws = FakeSecurityWebSocketService();
      final siren = FakeSecuritySirenService();

      await tester.pumpWidget(createWidgetUnderTest(
        user: securityUser,
        repo: repo,
        ws: ws,
        siren: siren,
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('tidak memiliki penugasan aktif'),
          findsOneWidget);
      expect(find.text('SIAGA POS SATPAM'), findsNothing);
    });

    testWidgets(
        '3. Allows neighborhood switching when officer has multiple assignments',
        (tester) async {
      final repo = FakeSecurityRepository()
        ..assignmentsToReturn = [testAssignment1, testAssignment2]
        ..activeIncidentsToReturn = [
          testIncident, // Belongs to 101
          SecurityIncidentModel(
            id: 100,
            category: 'MEDIS',
            title: 'Serangan Jantung',
            description: 'Butuh ambulan segera',
            status: 'ACTIVE',
            neighborhoodId: 102,
            neighborhoodName: 'RT 02 Lingkungan B',
            reporterId: 55,
            reporterName: 'Ibu Siti',
            reportedAt: DateTime.now(),
          ),
        ]
        ..incidentDetailToReturn = testIncident;

      final ws = FakeSecurityWebSocketService();
      final siren = FakeSecuritySirenService();

      await tester.pumpWidget(createWidgetUnderTest(
        user: securityUser,
        repo: repo,
        ws: ws,
        siren: siren,
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Dropdown exists for multiple assignments
      expect(find.text('Pilih Lingkungan Tugas: '), findsOneWidget);
      expect(find.text('RT 01 Lingkungan A'), findsWidgets);
    });

    testWidgets(
        '4. New incident via WS starts siren and shows fullscreen emergency dialog',
        (tester) async {
      final repo = FakeSecurityRepository()
        ..assignmentsToReturn = [testAssignment1]
        ..activeIncidentsToReturn = []
        ..incidentDetailToReturn = testIncident;

      final ws = FakeSecurityWebSocketService();
      final siren = FakeSecuritySirenService();

      await tester.pumpWidget(createWidgetUnderTest(
        user: securityUser,
        repo: repo,
        ws: ws,
        siren: siren,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Kondisi Lingkungan Aman'), findsOneWidget);

      // Emit WS event
      repo.activeIncidentsToReturn = [testIncident];
      ws.emitEvent({
        'event_id': 'evt_123',
        'event_type': 'INCIDENT_CREATED',
        'neighborhood_id': 101,
        'data': {
          'incident_id': 99,
          'category': 'KEJAHATAN',
          'status': 'ACTIVE',
        },
      });

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Verify Siren triggered
      expect(siren.sirenStarted, isTrue);

      // Verify fullscreen emergency dialog displayed with backend details
      expect(find.text('DARURAT POS SATPAM'), findsOneWidget);
      expect(find.byType(EmergencyFullscreenDialog), findsOneWidget);
      expect(find.text('Pak RT Bambang'), findsWidgets);
      expect(find.text('081987654321'), findsOneWidget);
      expect(find.text('Sedang Ditangani'), findsOneWidget);

      // Press "Sedang Ditangani"
      repo.activeIncidentsToReturn = []; // Handled now
      await tester.tap(find.text('Sedang Ditangani'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify Acknowledge called and siren stopped
      expect(repo.acknowledgeCalled, isTrue);
      expect(repo.acknowledgedId, equals(99));
      expect(siren.sirenStopped, isTrue);
    });

    test('5. Deduplication: duplicate WS event does not open multiple dialogs',
        () async {
      final wsService = SecurityWebSocketService();
      final eventsEmitted = <Map<String, dynamic>>[];
      final sub = wsService.eventStream.listen((evt) {
        eventsEmitted.add(evt);
      });

      // Same event ID twice
      const testMsg =
          '{"event_id":"evt_abc","event_type":"INCIDENT_CREATED","data":{"incident_id":1}}';
      // Simulate socket message handling
      wsService.handleTestMessage(testMsg);
      wsService.handleTestMessage(testMsg);

      await Future.delayed(const Duration(milliseconds: 10));
      expect(eventsEmitted.length, equals(1));

      await sub.cancel();
      wsService.dispose();
    });

    testWidgets(
        '6. Lifecycle: Logout then login again without refresh does not dispose statusNotifier',
        (tester) async {
      final repo = FakeSecurityRepository()
        ..assignmentsToReturn = [testAssignment1]
        ..activeIncidentsToReturn = [];
      final ws = FakeSecurityWebSocketService();
      final siren = FakeSecuritySirenService();

      // Step 1: Satpam login first time
      await tester.pumpWidget(MaterialApp(
        home: MultiRepositoryProvider(
          providers: [
            RepositoryProvider<SecurityWebSocketService>.value(value: ws),
            RepositoryProvider<SecuritySirenService>.value(value: siren),
          ],
          child: BlocProvider<AuthBloc>.value(
            value: MockAuthBloc(const AuthState(
              status: AuthStatus.authenticated,
              user: securityUser,
            )),
            child: SecurityStandbyScreen(
              repository: repo,
              // wsService & sirenService null to use context.read
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('SIAGA POS SATPAM'), findsOneWidget);
      expect(ws.connectCallCount, equals(1));
      expect(ws.disposeCalled, isFalse);

      // Step 2: Satpam logs out (screen unmounted and replaced with login screen)
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: Text('HALAMAN LOGIN')),
      ));
      await tester.pumpAndSettle();

      // Verify that screen unmount called disconnect, NOT dispose
      expect(ws.disconnectCalled, isTrue);
      expect(ws.disposeCalled, isFalse);
      expect(ws.statusNotifier.value, equals(WsConnectionStatus.connected));

      // Step 3: Satpam logs in again WITHOUT refresh (screen mounted again with same ws instance)
      await tester.pumpWidget(MaterialApp(
        home: MultiRepositoryProvider(
          providers: [
            RepositoryProvider<SecurityWebSocketService>.value(value: ws),
            RepositoryProvider<SecuritySirenService>.value(value: siren),
          ],
          child: BlocProvider<AuthBloc>.value(
            value: MockAuthBloc(const AuthState(
              status: AuthStatus.authenticated,
              user: securityUser,
            )),
            child: SecurityStandbyScreen(
              repository: repo,
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      // Verify second login succeeds without ValueNotifier disposed exception
      expect(find.text('SIAGA POS SATPAM'), findsOneWidget);
      expect(ws.connectCallCount, equals(2));
      expect(ws.disposeCalled, isFalse);
    });

    testWidgets(
        '7. Lifecycle: Repeated 5x logout and login cycle without browser refresh',
        (tester) async {
      final repo = FakeSecurityRepository()
        ..assignmentsToReturn = [testAssignment1]
        ..activeIncidentsToReturn = [];
      final ws = FakeSecurityWebSocketService();
      final siren = FakeSecuritySirenService();

      for (int i = 1; i <= 5; i++) {
        // Login
        await tester.pumpWidget(MaterialApp(
          home: MultiRepositoryProvider(
            providers: [
              RepositoryProvider<SecurityWebSocketService>.value(value: ws),
              RepositoryProvider<SecuritySirenService>.value(value: siren),
            ],
            child: BlocProvider<AuthBloc>.value(
              value: MockAuthBloc(const AuthState(
                status: AuthStatus.authenticated,
                user: securityUser,
              )),
              child: SecurityStandbyScreen(
                repository: repo,
              ),
            ),
          ),
        ));
        await tester.pumpAndSettle();
        expect(find.text('SIAGA POS SATPAM'), findsOneWidget);
        expect(ws.connectCallCount, equals(i));
        expect(ws.disposeCalled, isFalse);

        // Logout
        await tester.pumpWidget(const MaterialApp(
          home: Scaffold(body: Text('LOGIN')),
        ));
        await tester.pumpAndSettle();
        expect(ws.disposeCalled, isFalse);
        expect(ws.disconnectCalled, isTrue);
      }
    });

    test(
        '8. SecurityWebSocketService: disconnect cancels retry and does not access disposed notifier',
        () async {
      final ws = SecurityWebSocketService();
      expect(ws.status, equals(WsConnectionStatus.disconnected));

      // Disconnect cleanly
      ws.disconnect();
      expect(ws.status, equals(WsConnectionStatus.disconnected));

      // Multiple disconnects are idempotent
      ws.disconnect();

      // Dispose cleans up notifier
      ws.dispose();
      // Further disconnects or callbacks after dispose do not throw
      ws.disconnect();
      await ws.connect();
    });
  });
}
