import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tetanggo_frontend/core/theme/app_theme.dart';
import 'package:tetanggo_frontend/core/widgets/standard_submenu_tab_bar.dart';

void main() {
  group('US: Standardisasi Tampilan Submenu', () {
    late TabController controller;

    testWidgets('StandardSubmenuTabBar renders consistent styling with Iuran Warga reference', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: DefaultTabController(
            length: 3,
            child: Builder(
              builder: (context) {
                controller = DefaultTabController.of(context);
                return Scaffold(
                  body: StandardSubmenuTabBar(
                    controller: controller,
                    isScrollable: true,
                    items: const [
                      StandardSubmenuItem(
                        icon: Icons.how_to_reg_rounded,
                        label: 'Verifikasi Warga',
                        badgeCount: 5,
                      ),
                      StandardSubmenuItem(
                        icon: Icons.home_work_rounded,
                        label: 'Data Hunian & Warga',
                      ),
                      StandardSubmenuItem(
                        icon: Icons.family_restroom_rounded,
                        label: 'Profil Hunian & Keluarga',
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      );

      // Verify labels and icons
      expect(find.text('Verifikasi Warga'), findsOneWidget);
      expect(find.text('Data Hunian & Warga'), findsOneWidget);
      expect(find.text('Profil Hunian & Keluarga'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);

      // Verify TabBar attributes matching reference:
      final tabBarFinder = find.byType(TabBar);
      expect(tabBarFinder, findsOneWidget);
      final tabBar = tester.widget<TabBar>(tabBarFinder);

      expect(tabBar.labelColor, equals(AppTheme.primary));
      expect(tabBar.unselectedLabelColor, equals(AppTheme.textSecondary));
      expect(tabBar.indicatorColor, equals(AppTheme.primary));
      expect(tabBar.indicatorWeight, equals(3));
      expect(tabBar.labelStyle?.fontWeight, equals(FontWeight.bold));
      expect(tabBar.labelStyle?.fontSize, equals(14));
    });

    testWidgets('StandardSubmenuTabBar distributes equal width on desktop when isScrollable is false', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: DefaultTabController(
            length: 3,
            child: Builder(
              builder: (context) {
                controller = DefaultTabController.of(context);
                return Scaffold(
                  body: StandardSubmenuTabBar(
                    controller: controller,
                    isScrollable: false,
                    items: const [
                      StandardSubmenuItem(
                        icon: Icons.how_to_reg_rounded,
                        label: 'Verifikasi Warga',
                      ),
                      StandardSubmenuItem(
                        icon: Icons.home_work_rounded,
                        label: 'Data Hunian & Warga',
                      ),
                      StandardSubmenuItem(
                        icon: Icons.family_restroom_rounded,
                        label: 'Profil Hunian & Keluarga',
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      );

      final tabBarFinder = find.byType(TabBar);
      expect(tabBarFinder, findsOneWidget);
      final tabBar = tester.widget<TabBar>(tabBarFinder);
      expect(tabBar.isScrollable, isFalse);

      // Total width is 1200, non-scrollable TabBar divides total width evenly into 3 equal slots of 400
      final tabBarRender = tester.renderObject(tabBarFinder) as RenderBox;
      expect(tabBarRender.size.width, equals(1200.0));
    });

    testWidgets('StandardSubmenuTabBar distributes 50% width each for 2 items on desktop', (tester) async {
      tester.view.physicalSize = const Size(1000, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: DefaultTabController(
            length: 2,
            child: Builder(
              builder: (context) {
                controller = DefaultTabController.of(context);
                return Scaffold(
                  body: StandardSubmenuTabBar(
                    controller: controller,
                    isScrollable: false,
                    items: const [
                      StandardSubmenuItem(
                        icon: Icons.view_kanban_rounded,
                        label: 'Semua Pengaduan Cluster',
                      ),
                      StandardSubmenuItem(
                        icon: Icons.report_problem_rounded,
                        label: 'Lapor Cluster (Laporan Saya)',
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      );

      final tabBarFinder = find.byType(TabBar);
      expect(tabBarFinder, findsOneWidget);
      final tabBar = tester.widget<TabBar>(tabBarFinder);
      expect(tabBar.isScrollable, isFalse);

      final tabBarRender = tester.renderObject(tabBarFinder) as RenderBox;
      expect(tabBarRender.size.width, equals(1000.0));
    });
  });
}
