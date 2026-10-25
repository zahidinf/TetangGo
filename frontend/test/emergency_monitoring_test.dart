import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tetanggo_frontend/core/theme/app_theme.dart';
import 'package:tetanggo_frontend/features/auth/domain/models/user_model.dart';
import 'package:tetanggo_frontend/features/home/presentation/widgets/dashboard_sidebar.dart';
import 'package:tetanggo_frontend/features/security/domain/models/security_models.dart';

void main() {
  group('Emergency Monitoring & Navigation Item Tests', () {
    final residentUser = UserModel(
      id: 1,
      name: 'Warga Budi',
      phone: '08123456789',
      email: 'warga@tetanggo.com',
      roleId: 2,
      role: 'RESIDENT',
      status: 'active',
      houseId: 10,
    );

    final adminUser = UserModel(
      id: 2,
      name: 'Admin Cluster',
      phone: '08123456780',
      email: 'admin@tetanggo.com',
      roleId: 1,
      role: 'ADMIN',
      status: 'active',
    );

    test('1. NavigationItemBuilder produces Kejadian Darurat item with dynamic badge', () {
      // 0 active incidents -> 'Aman' green badge
      final itemsZero = NavigationItemBuilder.buildNavigationItems(
        residentUser,
        activeIncidentsCount: 0,
      );
      final panicItemZero = itemsZero.firstWhere((it) => it.keyId == 'panic');
      expect(panicItemZero.title, 'Kejadian Darurat');
      expect(panicItemZero.badge, 'Aman');
      expect(panicItemZero.badgeColor, AppTheme.success);

      // > 0 active incidents -> 'Siaga N' red badge
      final itemsActive = NavigationItemBuilder.buildNavigationItems(
        residentUser,
        activeIncidentsCount: 3,
      );
      final panicItemActive = itemsActive.firstWhere((it) => it.keyId == 'panic');
      expect(panicItemActive.title, 'Kejadian Darurat');
      expect(panicItemActive.badge, 'Siaga 3');
      expect(panicItemActive.badgeColor, AppTheme.danger);
    });

    test('2. Role Permission check for full emergency history access', () {
      expect(residentUser.canAccessFullEmergencyHistory, isFalse);
      expect(adminUser.canAccessFullEmergencyHistory, isTrue);

      final securityUser = UserModel(
        id: 3,
        name: 'Satpam Pos',
        phone: '08123456781',
        email: 'satpam@tetanggo.com',
        roleId: 7,
        role: 'SECURITY',
        status: 'active',
      );
      expect(securityUser.canAccessFullEmergencyHistory, isTrue);

      final treasurerUser = UserModel(
        id: 4,
        name: 'Bendahara',
        phone: '08123456782',
        email: 'treasurer@tetanggo.com',
        roleId: 5,
        role: 'TREASURER',
        status: 'active',
      );
      expect(treasurerUser.canAccessFullEmergencyHistory, isTrue);
    });

    test('3. IncidentListResponse & IncidentLogModel serialization', () {
      final jsonPayload = {
        'data': [
          {
            'id': 101,
            'category': 'MEDIS',
            'title': 'Warga Pingsan',
            'description': 'Butuh ambulan',
            'status': 'ACTIVE',
            'neighborhood_id': 1,
            'reporter_id': 1,
            'reporter_name': 'Warga Budi',
            'reported_at': '2026-10-25T10:00:00Z',
          }
        ],
        'meta': {
          'total': 1,
          'page': 1,
          'limit': 10,
          'total_pages': 1,
        }
      };

      final response = IncidentListResponse.fromJson(jsonPayload);
      expect(response.total, 1);
      expect(response.incidents.length, 1);
      expect(response.incidents.first.categoryDisplay, 'Darurat Medis / Kesehatan');
      expect(response.incidents.first.isActive, isTrue);

      final logJson = {
        'id': 50,
        'incident_id': 101,
        'user_id': 2,
        'user_name': 'Admin Cluster',
        'user_role': 'ADMIN',
        'action': 'CORRECTED',
        'previous_status': 'ACTIVE',
        'new_status': 'RESOLVED',
        'notes': 'Koreksi verifikasi pos satpam',
        'created_at': '2026-10-25T10:30:00Z',
      };

      final log = IncidentLogModel.fromJson(logJson);
      expect(log.action, 'CORRECTED');
      expect(log.previousStatus, 'ACTIVE');
      expect(log.newStatus, 'RESOLVED');
      expect(log.userRole, 'ADMIN');
    });

    testWidgets('4. DashboardSidebar displays "Kejadian Darurat" and badge', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DashboardSidebar(
              selectedIndex: 0,
              onItemSelected: (_) {},
              user: residentUser,
              onLogout: () {},
              activeIncidentsCount: 2,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Kejadian Darurat'), findsOneWidget);
      expect(find.text('Siaga 2'), findsOneWidget);
      expect(find.text('Panic Button'), findsNothing);
    });
  });
}
