import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tetanggo_frontend/features/auth/domain/models/user_model.dart';
import 'package:tetanggo_frontend/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:tetanggo_frontend/features/auth/presentation/bloc/auth_state.dart';
import 'package:tetanggo_frontend/features/panic/data/panic_repository.dart';
import 'package:tetanggo_frontend/features/panic/domain/models/panic_models.dart';
import 'package:tetanggo_frontend/features/panic/presentation/widgets/panic_confirmation_dialog.dart';
import 'package:tetanggo_frontend/features/resident_management/presentation/widgets/table_pagination_control.dart';
import 'package:tetanggo_frontend/features/security/data/security_repository.dart';
import 'package:tetanggo_frontend/features/security/data/security_siren_service.dart';
import 'package:tetanggo_frontend/features/security/data/security_websocket_service.dart';
import 'package:tetanggo_frontend/features/security/domain/models/security_models.dart';
import 'package:tetanggo_frontend/features/security/presentation/security_standby_screen.dart';

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
  List<SecurityIncidentModel> historyIncidentsToReturn = [];
  int historyTotalToReturn = 0;
  SecurityIncidentModel? incidentDetailToReturn;
  String? lastStatusQuery;
  int? lastPageQuery;

  @override
  Future<List<SecurityAssignmentModel>> getMyAssignments() async {
    return assignmentsToReturn;
  }

  @override
  Future<List<SecurityIncidentModel>> getActiveIncidents() async {
    return activeIncidentsToReturn;
  }

  @override
  Future<IncidentListResponse> getIncidents({
    int page = 1,
    int limit = 20,
    String? status,
    String? category,
    int? neighborhoodId,
  }) async {
    lastPageQuery = page;
    lastStatusQuery = status;
    return IncidentListResponse(
      incidents: historyIncidentsToReturn,
      total: historyTotalToReturn > 0
          ? historyTotalToReturn
          : historyIncidentsToReturn.length,
      page: page,
      limit: limit,
      totalPages: 2,
    );
  }

  @override
  Future<SecurityIncidentModel> getIncidentDetail(int id) async {
    if (incidentDetailToReturn != null) {
      return incidentDetailToReturn!;
    }
    throw Exception('Detail not found');
  }

  @override
  Future<int> getActiveIncidentCount() async {
    return activeIncidentsToReturn.length;
  }
}

class FakeSecurityWebSocketService extends Fake
    implements SecurityWebSocketService {
  final _controller = StreamController<Map<String, dynamic>>.broadcast();
  final _status =
      ValueNotifier<WsConnectionStatus>(WsConnectionStatus.connected);

  @override
  Stream<Map<String, dynamic>> get eventStream => _controller.stream;

  @override
  ValueNotifier<WsConnectionStatus> get statusNotifier => _status;

  @override
  WsConnectionStatus get status => _status.value;

  @override
  Future<void> connect() async {}

  @override
  void disconnect() {}
}

class FakeSecuritySirenService extends Fake implements SecuritySirenService {
  final _playing = ValueNotifier<bool>(false);
  final _muted = ValueNotifier<bool>(false);

  @override
  ValueNotifier<bool> get isPlayingNotifier => _playing;

  @override
  ValueNotifier<bool> get isMutedNotifier => _muted;

  @override
  void startSiren() => _playing.value = true;

  @override
  void stopSiren() => _playing.value = false;
}

class FakePanicRepository extends Fake implements PanicRepository {
  bool sendAlarmCalled = false;

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
    sendAlarmCalled = true;
    return IncidentReportModel(
      id: 99,
      category: category,
      title: title ?? 'Darurat',
      description: description ?? '',
      status: 'ACTIVE',
      neighborhoodId: 101,
      reportedAt: DateTime.now(),
    );
  }
}

void main() {
  const securityUser = UserModel(
    id: 10,
    name: 'Pak Satpam Budi',
    email: 'satpam@tetanggo.com',
    phone: '081299990001',
    roleId: 7,
    role: 'SECURITY',
    status: 'active',
  );

  const residentUser = UserModel(
    id: 20,
    name: 'Warga Siti',
    email: 'siti@tetanggo.com',
    phone: '081299990020',
    roleId: 1,
    role: 'RESIDENT',
    status: 'active',
    houseId: 1,
  );

  const testAssignment = SecurityAssignmentModel(
    id: 1,
    userId: 10,
    neighborhoodId: 101,
    neighborhoodName: 'RT 01 Lingkungan A',
    neighborhoodCode: 'RT01A',
    isActive: true,
  );

  final testActiveIncident = SecurityIncidentModel(
    id: 101,
    category: 'KEJAHATAN',
    title: 'Pencurian Motor',
    description: 'Ada maling berusaha membobol motor di garasi',
    status: 'REPORTED',
    neighborhoodId: 101,
    neighborhoodName: 'RT 01 Lingkungan A',
    houseBlock: 'A',
    houseNumber: '12',
    reporterId: 20,
    reporterName: 'Warga Siti',
    reporterPhone: '081299990020',
    reportedAt: DateTime(2026, 10, 25, 14, 30),
  );

  final testResolvedIncident = SecurityIncidentModel(
    id: 102,
    category: 'KEBAKARAN',
    title: 'Korsleting Listrik',
    description: 'Korsleting pada panel gardu, sudah dipadamkan',
    status: 'RESOLVED',
    neighborhoodId: 101,
    neighborhoodName: 'RT 01 Lingkungan A',
    houseBlock: 'B',
    houseNumber: '05',
    reporterId: 21,
    reporterName: 'Pak Joko',
    reportedAt: DateTime(2026, 10, 24, 10, 0),
    resolvedAt: DateTime(2026, 10, 24, 10, 45),
    resolutionNotes:
        'Api dipadamkan menggunakan APAR pos satpam. Situasi aman.',
  );

  Widget createSecurityWidget(FakeSecurityRepository repo) {
    final mockBloc = MockAuthBloc(const AuthState(
      status: AuthStatus.authenticated,
      user: securityUser,
    ));

    return MaterialApp(
      home: BlocProvider<AuthBloc>.value(
        value: mockBloc,
        child: SecurityStandbyScreen(
          repository: repo,
          wsService: FakeSecurityWebSocketService(),
          sirenService: FakeSecuritySirenService(),
        ),
      ),
    );
  }

  group('US-1: Portal Satpam Riwayat Kejadian Darurat Tests', () {
    testWidgets('1. Renders TabBar with Insiden Aktif and Riwayat Kejadian',
        (tester) async {
      final repo = FakeSecurityRepository()
        ..assignmentsToReturn = [testAssignment]
        ..activeIncidentsToReturn = [testActiveIncident]
        ..historyIncidentsToReturn = [testActiveIncident, testResolvedIncident]
        ..historyTotalToReturn = 2;

      await tester.pumpWidget(createSecurityWidget(repo));
      await tester.pumpAndSettle();

      expect(find.text('Insiden Aktif'), findsOneWidget);
      expect(find.text('Riwayat Kejadian'), findsOneWidget);
      expect(find.text('Daftar Insiden Aktif'), findsOneWidget);
    });

    testWidgets(
        '2. Switch to Riwayat Kejadian shows full history including RESOLVED with notes and pagination',
        (tester) async {
      final repo = FakeSecurityRepository()
        ..assignmentsToReturn = [testAssignment]
        ..activeIncidentsToReturn = []
        ..historyIncidentsToReturn = [testActiveIncident, testResolvedIncident]
        ..historyTotalToReturn = 2;

      await tester.pumpWidget(createSecurityWidget(repo));
      await tester.pumpAndSettle();

      // Tap on Tab "Riwayat Kejadian"
      await tester.tap(find.text('Riwayat Kejadian'));
      await tester.pumpAndSettle();

      // Verify incident cards in history
      expect(find.text('#101'), findsOneWidget);
      expect(find.text('Warga Siti'), findsOneWidget);

      expect(find.text('#102'), findsOneWidget);
      expect(find.text('Pak Joko'), findsOneWidget);
      expect(find.textContaining('Api dipadamkan menggunakan APAR'),
          findsOneWidget);

      // Verify TablePaginationControl is rendered
      expect(find.byType(TablePaginationControl), findsOneWidget);
    });

    testWidgets('3. Status filter chips trigger query with updated status',
        (tester) async {
      final repo = FakeSecurityRepository()
        ..assignmentsToReturn = [testAssignment]
        ..activeIncidentsToReturn = []
        ..historyIncidentsToReturn = [testResolvedIncident]
        ..historyTotalToReturn = 1;

      await tester.pumpWidget(createSecurityWidget(repo));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Riwayat Kejadian'));
      await tester.pumpAndSettle();

      // Tap filter chip "Terkendali"
      final terkendaliChip = find.widgetWithText(ChoiceChip, 'Terkendali');
      expect(terkendaliChip, findsOneWidget);
      await tester.tap(terkendaliChip);
      await tester.pumpAndSettle();

      expect(repo.lastStatusQuery, 'RESOLVED');
    });

    testWidgets('4. Empty state is shown when no history matches',
        (tester) async {
      final repo = FakeSecurityRepository()
        ..assignmentsToReturn = [testAssignment]
        ..activeIncidentsToReturn = []
        ..historyIncidentsToReturn = []
        ..historyTotalToReturn = 0;

      await tester.pumpWidget(createSecurityWidget(repo));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Riwayat Kejadian'));
      await tester.pumpAndSettle();

      expect(find.text('Tidak Ada Riwayat Kejadian'), findsOneWidget);
    });
  });

  group('US-2: Badge Kejadian Darurat Auto-Refresh Tests', () {
    testWidgets(
        '5. PanicConfirmationDialog executes onAlarmSent callback upon successful report',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final panicRepo = FakePanicRepository();
      bool alarmSentInvoked = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PanicConfirmationDialog(
              user: residentUser,
              repository: panicRepo,
              onAlarmSent: () {
                alarmSentInvoked = true;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap confirm alarm button
      final sendBtn = find.text('KIRIM ALARM SEKARANG');
      expect(sendBtn, findsOneWidget);
      await tester.ensureVisible(sendBtn);
      await tester.tap(sendBtn);
      await tester.pumpAndSettle();

      expect(panicRepo.sendAlarmCalled, isTrue);
      expect(alarmSentInvoked, isTrue);
      expect(find.text('SINYAL DARURAT TERKIRIM!'), findsOneWidget);
    });
  });
}
