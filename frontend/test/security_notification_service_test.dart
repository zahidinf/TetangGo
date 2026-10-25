import 'package:flutter_test/flutter_test.dart';
import 'package:tetanggo_frontend/features/security/data/security_notification_service.dart';
import 'package:tetanggo_frontend/features/security/data/security_repository.dart';
import 'package:tetanggo_frontend/features/security/data/security_siren_service.dart';
import 'package:tetanggo_frontend/features/security/domain/models/security_models.dart';

class FakeSecurityRepository extends Fake implements SecurityRepository {
  List<SecurityAssignmentModel> assignmentsToReturn = [];
  SecurityIncidentModel? incidentDetailToReturn;

  @override
  Future<List<SecurityAssignmentModel>> getMyAssignments() async {
    return assignmentsToReturn;
  }

  @override
  Future<SecurityIncidentModel> getIncidentDetail(int id) async {
    if (incidentDetailToReturn != null) {
      return incidentDetailToReturn!;
    }
    throw Exception('Incident $id not found');
  }
}

class FakeSecuritySirenService extends Fake implements SecuritySirenService {
  bool sirenStarted = false;
  bool sirenStopped = false;

  @override
  void startSiren() {
    sirenStarted = true;
    sirenStopped = false;
  }

  @override
  void stopSiren() {
    sirenStopped = true;
  }
}

void main() {
  const testAssignment = SecurityAssignmentModel(
    id: 1,
    userId: 10,
    neighborhoodId: 101,
    neighborhoodName: 'RT 01 Lingkungan A',
    neighborhoodCode: 'RT01A',
    isActive: true,
  );

  final activeIncident = SecurityIncidentModel(
    id: 88,
    category: 'KEBAKARAN',
    title: 'Konsleting Kabel Tiang',
    description: 'Percikan api di tiang listrik blok B',
    status: 'ACTIVE',
    neighborhoodId: 101,
    neighborhoodName: 'RT 01 Lingkungan A',
    reporterId: 2,
    reporterName: 'Warga Pak Joko',
    reportedAt: DateTime.now(),
  );

  group('US-4.7: Security Notification Service (FCM Fallback Push) Tests', () {
    test('1. Valid payload with active assignment triggers siren & navigation',
        () async {
      final repo = FakeSecurityRepository()
        ..assignmentsToReturn = [testAssignment]
        ..incidentDetailToReturn = activeIncident;
      final siren = FakeSecuritySirenService();
      final service = SecurityNotificationService(
        repository: repo,
        sirenService: siren,
      );

      int? navigatedIncidentId;
      final sub = service.onNavigateToIncident.listen((id) {
        navigatedIncidentId = id;
      });

      final detail = await service.handleNotificationPayload({
        'type': 'EMERGENCY_INCIDENT',
        'incident_id': '88',
        'category': 'KEBAKARAN',
        'neighborhood_id': '101',
        'status': 'ACTIVE',
      }, isAppLaunchOrTap: true);

      // Allow microtask queue to process broadcast stream event
      await Future<void>.delayed(Duration.zero);

      expect(detail, isNotNull);
      expect(detail!.id, equals(88));
      expect(siren.sirenStarted, isTrue);
      expect(navigatedIncidentId, equals(88));

      await sub.cancel();
      service.dispose();
    });

    test(
        '2. Security officer WITHOUT active assignment cannot open or view incident',
        () async {
      final repo = FakeSecurityRepository()
        ..assignmentsToReturn = [] // No assignments
        ..incidentDetailToReturn = activeIncident;
      final siren = FakeSecuritySirenService();
      final service = SecurityNotificationService(
        repository: repo,
        sirenService: siren,
      );

      final detail = await service.handleNotificationPayload({
        'type': 'EMERGENCY_INCIDENT',
        'incident_id': '88',
        'category': 'KEBAKARAN',
      }, isAppLaunchOrTap: true);

      expect(detail, isNull);
      expect(siren.sirenStarted, isFalse);

      service.dispose();
    });

    test('3. Incident from another neighborhood is rejected by assignment scope',
        () async {
      // Officer assigned to 101, but incident belongs to neighborhood 202
      final foreignIncident = activeIncident.copyWith(neighborhoodId: 202);

      final repo = FakeSecurityRepository()
        ..assignmentsToReturn = [testAssignment] // assigned to 101
        ..incidentDetailToReturn = foreignIncident;
      final siren = FakeSecuritySirenService();
      final service = SecurityNotificationService(
        repository: repo,
        sirenService: siren,
      );

      final detail = await service.handleNotificationPayload({
        'type': 'EMERGENCY_INCIDENT',
        'incident_id': '88',
      }, isAppLaunchOrTap: true);

      expect(detail, isNull);
      expect(siren.sirenStarted, isFalse);

      service.dispose();
    });

    test('4. Duplicate notification payload is deduplicated safely', () async {
      final repo = FakeSecurityRepository()
        ..assignmentsToReturn = [testAssignment]
        ..incidentDetailToReturn = activeIncident;
      final siren = FakeSecuritySirenService();
      final service = SecurityNotificationService(
        repository: repo,
        sirenService: siren,
      );

      final payload = {
        'type': 'EMERGENCY_INCIDENT',
        'incident_id': '88',
        'notification_id': 'fcm_msg_uniq_1',
        'status': 'ACTIVE',
      };

      // First delivery
      final first = await service.handleNotificationPayload(payload);
      expect(first, isNotNull);

      // Duplicate delivery
      final duplicate = await service.handleNotificationPayload(payload);
      expect(duplicate, isNull);

      service.dispose();
    });

    test('5. Non-emergency push is safely ignored without errors', () async {
      final repo = FakeSecurityRepository();
      final siren = FakeSecuritySirenService();
      final service = SecurityNotificationService(
        repository: repo,
        sirenService: siren,
      );

      final result = await service.handleNotificationPayload({
        'type': 'ANNOUNCEMENT_BROADCAST',
        'title': 'Kerja Bakti Hari Minggu',
      });

      expect(result, isNull);
      expect(siren.sirenStarted, isFalse);

      service.dispose();
    });
  });
}
