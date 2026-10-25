import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tetanggo_frontend/features/resident_management/presentation/widgets/table_pagination_control.dart';

void main() {
  group('TablePaginationControl Tests', () {
    testWidgets('Data 0 item tidak menampilkan widget pagination',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TablePaginationControl(
              currentPage: 1,
              totalItems: 0,
              pageSize: 15,
              keyPrefix: 'test_pagination',
              onPageChanged: (_) {},
            ),
          ),
        ),
      );

      expect(find.byType(TablePaginationControl), findsOneWidget);
      expect(find.byKey(const Key('test_pagination_prev')), findsNothing);
      expect(find.byKey(const Key('test_pagination_next')), findsNothing);
    });

    testWidgets(
        'Pagination desktop menampilkan info range dan navigasi halaman',
        (tester) async {
      int activePage = 1;

      // Berikan ukuran layar simulasi desktop yang cukup
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return TablePaginationControl(
                  currentPage: activePage,
                  totalItems: 42,
                  pageSize: 15,
                  keyPrefix: 'houses_pagination',
                  isDesktop: true,
                  onPageChanged: (p) => setState(() => activePage = p),
                );
              },
            ),
          ),
        ),
      );

      // Verifikasi teks info range
      expect(find.text('Menampilkan 1–15 dari 42 data (Hal 1 dari 3)'),
          findsOneWidget);

      // Verifikasi tombol nomor halaman (1, 2, 3)
      expect(find.byKey(const Key('houses_pagination_page_1')), findsOneWidget);
      expect(find.byKey(const Key('houses_pagination_page_2')), findsOneWidget);
      expect(find.byKey(const Key('houses_pagination_page_3')), findsOneWidget);

      // Klik halaman 2
      await tester.tap(find.byKey(const Key('houses_pagination_page_2')));
      await tester.pumpAndSettle();

      expect(activePage, 2);
      expect(find.text('Menampilkan 16–30 dari 42 data (Hal 2 dari 3)'),
          findsOneWidget);

      // Klik tombol Berikutnya (ke hal 3)
      await tester.tap(find.byKey(const Key('houses_pagination_next')));
      await tester.pumpAndSettle();

      expect(activePage, 3);
      expect(find.text('Menampilkan 31–42 dari 42 data (Hal 3 dari 3)'),
          findsOneWidget);

      // Tombol berikutnya nonaktif di halaman terakhir
      final nextBtn = tester.widget<OutlinedButton>(
          find.byKey(const Key('houses_pagination_next')));
      expect(nextBtn.onPressed, isNull);

      // Klik tombol Sebelumnya (kembali ke hal 2)
      await tester.tap(find.byKey(const Key('houses_pagination_prev')));
      await tester.pumpAndSettle();

      expect(activePage, 2);
      expect(find.text('Menampilkan 16–30 dari 42 data (Hal 2 dari 3)'),
          findsOneWidget);
    });

    testWidgets('Tampilan non-desktop merender format ringkas kolom',
        (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TablePaginationControl(
              currentPage: 2,
              totalItems: 35,
              pageSize: 15,
              keyPrefix: 'mobile_pagination',
              isDesktop: false,
              onPageChanged: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('Menampilkan 16–30 dari 35 data (Hal 2 dari 3)'),
          findsOneWidget);
      expect(find.byKey(const Key('mobile_pagination_prev')), findsOneWidget);
      expect(find.byKey(const Key('mobile_pagination_next')), findsOneWidget);
    });
  });
}
