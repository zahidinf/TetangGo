import 'dart:async';
import 'package:flutter/foundation.dart';
import '../domain/models/security_models.dart';
import 'security_repository.dart';
import 'security_siren_service.dart';

/// Handler for Security Push Notifications (Firebase Cloud Messaging fallback).
/// Responsible for:
/// - Parsing payload safely
/// - Triggering siren for incoming emergency when in foreground or allowed background
/// - Verifying active security assignment prior to opening emergency incident
class SecurityNotificationService {
  final SecurityRepository repository;
  final SecuritySirenService sirenService;

  final _incidentNavigationController = StreamController<int>.broadcast();
  final Set<String> _processedNotificationIds = {};

  SecurityNotificationService({
    required this.repository,
    required this.sirenService,
  });

  /// Stream emitting incident IDs to navigate to
  Stream<int> get onNavigateToIncident => _incidentNavigationController.stream;

  /// Handles incoming FCM notification payload (foreground, background, or onMessageOpenedApp)
  /// Expected minimal safe data keys:
  /// - type: "EMERGENCY_INCIDENT"
  /// - incident_id: String
  /// - category: String
  /// - notification_id: String (optional, for deduplication)
  Future<SecurityIncidentModel?> handleNotificationPayload(
    Map<String, dynamic> data, {
    bool isAppLaunchOrTap = false,
  }) async {
    final type = data['type']?.toString();
    if (type != 'EMERGENCY_INCIDENT') {
      debugPrint('[SecurityNotification] Ignored non-emergency push: $type');
      return null;
    }

    final rawId = data['incident_id']?.toString();
    if (rawId == null || int.tryParse(rawId) == null) {
      debugPrint('[SecurityNotification] Invalid incident_id in payload: $rawId');
      return null;
    }
    final incidentId = int.parse(rawId);

    // Deduplication check
    final notificationId = data['notification_id']?.toString() ??
        'push_${incidentId}_${data['status']}';
    if (_processedNotificationIds.contains(notificationId) && !isAppLaunchOrTap) {
      debugPrint(
          '[SecurityNotification] Deduplicated duplicate push: $notificationId');
      return null;
    }
    _processedNotificationIds.add(notificationId);

    // Strictly verify caller assignment before opening or sounding
    try {
      final assignments = await repository.getMyAssignments();
      if (assignments.isEmpty) {
        debugPrint(
            '[SecurityNotification] Access denied: Security officer has no active assignment');
        return null;
      }

      // Fetch verified incident detail from authenticated backend API
      final detail = await repository.getIncidentDetail(incidentId);

      // Verify incident belongs to one of officer's assigned neighborhoods
      final hasAssignment = assignments
          .any((a) => a.neighborhoodId == detail.neighborhoodId && a.isActive);
      if (!hasAssignment) {
        debugPrint(
            '[SecurityNotification] Access denied: Officer not assigned to incident neighborhood ${detail.neighborhoodId}');
        return null;
      }

      // Trigger siren if incident is ACTIVE
      if (detail.isActive) {
        sirenService.startSiren();
      }

      if (isAppLaunchOrTap) {
        _incidentNavigationController.add(incidentId);
      }

      return detail;
    } catch (e) {
      debugPrint('[SecurityNotification] Error processing notification: $e');
      return null;
    }
  }

  void dispose() {
    _incidentNavigationController.close();
  }
}
