import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tetanggo_frontend/core/widgets/standard_page_header.dart';

void main() {
  group('StandardPageHeader Responsive Layout Tests', () {
    testWidgets('Desktop view (>= 700px): title on left (expanded), actions right aligned',
        (tester) async {
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StandardPageHeader(
              title: 'Test Header Desktop',
              subtitle: 'Test Subtitle Desktop',
              actions: [
                ElevatedButton(
                  key: const Key('btn_1'),
                  onPressed: () {},
                  child: const Text('Action 1'),
                ),
                ElevatedButton(
                  key: const Key('btn_2'),
                  onPressed: () {},
                  child: const Text('Action 2'),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Test Header Desktop'), findsOneWidget);
      expect(find.text('Test Subtitle Desktop'), findsOneWidget);
      expect(find.byKey(const Key('btn_1')), findsOneWidget);
      expect(find.byKey(const Key('btn_2')), findsOneWidget);

      final titleTopLeft = tester.getTopLeft(find.text('Test Header Desktop'));
      final btn1TopLeft = tester.getTopLeft(find.byKey(const Key('btn_1')));

      // Buttons are on the right side of the title on desktop
      expect(btn1TopLeft.dx, greaterThan(titleTopLeft.dx + 200));
    });

    testWidgets('Mobile view 320px: wraps actions below title without overflow',
        (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: StandardPageHeader(
                title: 'Judul Panjang Mobile Yang Harus Rapi',
                subtitle: 'Deskripsi pengaduan fasilitas cluster lengkap',
                actions: [
                  ElevatedButton(
                    key: const Key('btn_mobile_1'),
                    onPressed: () {},
                    child: const Text('Aksi Panjang Satu'),
                  ),
                  ElevatedButton(
                    key: const Key('btn_mobile_2'),
                    onPressed: () {},
                    child: const Text('Aksi Dua'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Judul Panjang Mobile Yang Harus Rapi'), findsOneWidget);
      expect(find.byKey(const Key('btn_mobile_1')), findsOneWidget);
      expect(find.byKey(const Key('btn_mobile_2')), findsOneWidget);

      final titleBottom =
          tester.getBottomLeft(find.text('Judul Panjang Mobile Yang Harus Rapi'));
      final btn1Top = tester.getTopLeft(find.byKey(const Key('btn_mobile_1')));

      // Button sits below the title section on mobile
      expect(btn1Top.dy, greaterThan(titleBottom.dy));
      expect(tester.takeException(), isNull);
    });

    testWidgets('Mobile view 375px & 430px: actions render properly',
        (tester) async {
      for (final width in [375.0, 430.0]) {
        tester.view.physicalSize = Size(width, 800);
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StandardPageHeader(
                title: 'Header Test $width',
                subtitle: 'Subtitle $width',
                actions: [
                  ElevatedButton(
                    onPressed: () {},
                    child: const Text('Tombol Responsif'),
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Header Test $width'), findsOneWidget);
        expect(find.text('Tombol Responsif'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
      tester.view.resetPhysicalSize();
    });
  });
}
