import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tetanggo_frontend/core/constants/app_constants.dart';
import 'package:tetanggo_frontend/features/home/presentation/widgets/about_tetanggo_dialog.dart';

void main() {
  group('Legal & Copyright Tests', () {
    test('AppConstants copyright notice format and year consistency', () {
      final currentYear = DateTime.now().year;
      final expectedYearStr =
          currentYear <= 2026 ? '2026' : '2026-$currentYear';
      expect(AppConstants.copyrightNotice,
          '© $expectedYearStr TetangGo. All rights reserved.');
      expect(AppConstants.appName, 'TetangGo');
      expect(AppConstants.appVersion, '0.1.0');
      expect(AppConstants.licenseType, 'PolyForm Noncommercial License 1.0.0');
      expect(
          AppConstants.repositoryUrl, 'https://github.com/zahidinf/TetangGo');
    });

    testWidgets(
        'AboutTetangGoDialog displays legal, copyright, and license info',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => AboutTetangGoDialog.show(context),
                child: const Text('Open About'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open About'));
      await tester.pumpAndSettle();

      expect(find.text('TetangGo'), findsOneWidget);
      expect(find.text('Versi 0.1.0'), findsOneWidget);
      expect(find.text('"${AppConstants.appTagline}"'), findsOneWidget);
      expect(find.text('Informasi Lisensi & Legal'), findsOneWidget);
      expect(find.text('PolyForm Noncommercial License 1.0.0'), findsOneWidget);
      expect(find.text(AppConstants.repositoryUrl), findsOneWidget);
      expect(find.text(AppConstants.copyrightNotice), findsOneWidget);

      // Verify close button dismisses dialog
      await tester.tap(find.text('Tutup'));
      await tester.pumpAndSettle();
      expect(find.text('Informasi Lisensi & Legal'), findsNothing);
    });
  });
}
