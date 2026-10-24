import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tetanggo_frontend/core/network/dio_client.dart';
import 'package:tetanggo_frontend/core/storage/secure_storage_service.dart';
import 'package:tetanggo_frontend/features/cashbook/data/cashbook_repository.dart';
import 'package:tetanggo_frontend/features/cashbook/domain/models/cashbook_models.dart';
import 'package:tetanggo_frontend/features/cashbook/presentation/cashbook_screen.dart';

class FakeCashbookRepo extends CashbookRepository {
  List<CashTransactionModel> allTransactions;
  CashbookSummaryModel summary;

  FakeCashbookRepo({
    this.allTransactions = const [],
    CashbookSummaryModel? summary,
  })  : summary = summary ??
            CashbookSummaryModel(
              currentBalance: 5000000,
              totalIncome: 7000000,
              totalExpense: 2000000,
              monthlySummary: [],
            ),
        super(DioClient(storageService: SecureStorageService()));

  @override
  Future<CashbookSummaryModel> getCashbookSummary() async {
    return summary;
  }

  @override
  Future<CashTransactionsResultModel> getCashbookTransactionsResult({
    String? type,
    String? category,
    String? startDate,
    String? endDate,
    String? period,
    int? month,
    int? year,
    int page = 1,
    int limit = 20,
  }) async {
    // 1. Filter by period (month & year)
    final filtered = allTransactions.where((tx) {
      if (year != null && month != null) {
        final prefix = '$year-${month.toString().padLeft(2, '0')}';
        if (!tx.transactionDate.startsWith(prefix)) return false;
      }
      if (type != null && type != 'all' && tx.type != type) return false;
      return true;
    }).toList();

    // 2. Stable sorting: date DESC, id DESC
    filtered.sort((a, b) {
      final dateComp = b.transactionDate.compareTo(a.transactionDate);
      if (dateComp != 0) return dateComp;
      return b.id.compareTo(a.id);
    });

    final total = filtered.length;
    final totalPages = limit > 0 && total > 0 ? (total / limit).ceil() : 0;

    final startIdx = (page - 1) * limit;
    final endIdx = (startIdx + limit) > total ? total : (startIdx + limit);

    final paged = (startIdx < total) ? filtered.sublist(startIdx, endIdx) : <CashTransactionModel>[];

    return CashTransactionsResultModel(
      transactions: paged,
      total: total,
      page: page,
      limit: limit,
      totalPages: totalPages,
      period: (year != null && month != null) ? '$year-${month.toString().padLeft(2, '0')}' : '2026-10',
      startDate: '2026-10-01',
      endDate: '2026-10-31',
      previousBalance: 1000000,
      periodIncome: 2000000,
      periodExpense: 500000,
      endingBalance: 2500000,
    );
  }
}

Widget createWidget(CashbookRepository repo, {bool isAdmin = true}) {
  return MaterialApp(
    home: RepositoryProvider<CashbookRepository>.value(
      value: repo,
      child: Scaffold(
        body: CashbookScreen(isAdmin: isAdmin),
      ),
    ),
  );
}

void main() {
  group('Cashbook Riwayat & Mutasi Pagination Tests', () {
    testWidgets('1. Data 0 record: shows empty state and hides pagination controls', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final repo = FakeCashbookRepo(allTransactions: []);
      await tester.pumpWidget(createWidget(repo));
      await tester.pumpAndSettle();

      expect(find.text('Belum ada transaksi kas yang dicatat'), findsOneWidget);
      expect(find.byKey(const Key('cashbook_pagination_prev')), findsNothing);
      expect(find.byKey(const Key('cashbook_pagination_next')), findsNothing);
    });

    testWidgets('2. Data 1-20 record: shows all records on one page and hides pagination controls', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final now = DateTime.now();
      final monthStr = now.month.toString().padLeft(2, '0');
      final txList = List.generate(
        15,
        (i) => CashTransactionModel(
          id: i + 1,
          type: 'income',
          category: 'iuran',
          amount: 50000,
          transactionDate: '${now.year}-$monthStr-10',
          description: 'Iuran Warga ke-${i + 1}',
          creatorName: 'Bendahara',
          createdAt: DateTime.now(),
        ),
      );

      final repo = FakeCashbookRepo(allTransactions: txList);
      await tester.pumpWidget(createWidget(repo));
      await tester.pumpAndSettle();

      expect(find.text('15 Mutasi'), findsOneWidget);
      expect(find.text('Iuran Warga ke-1'), findsOneWidget);
      expect(find.text('Iuran Warga ke-15'), findsOneWidget);
      // Pagination hidden because total <= 20
      expect(find.byKey(const Key('cashbook_pagination_prev')), findsNothing);
      expect(find.byKey(const Key('cashbook_pagination_next')), findsNothing);
    });

    testWidgets('3. Data 21 record: page 1 shows 20, page 2 shows 1, previous/next buttons disable correctly', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final now = DateTime.now();
      final monthStr = now.month.toString().padLeft(2, '0');
      final txList = List.generate(
        21,
        (i) => CashTransactionModel(
          id: 21 - i, // id 21 down to 1
          type: 'income',
          category: 'iuran',
          amount: 100000,
          transactionDate: '${now.year}-$monthStr-${(21 - i).toString().padLeft(2, '0')}',
          description: 'Tx #${21 - i}',
          creatorName: 'Bendahara',
          createdAt: DateTime.now(),
        ),
      );

      final repo = FakeCashbookRepo(allTransactions: txList);
      await tester.pumpWidget(createWidget(repo));
      await tester.pumpAndSettle();

      // Header badge shows total 21 Mutasi
      expect(find.text('21 Mutasi'), findsOneWidget);

      // Pagination visible
      expect(find.textContaining('Halaman 1 dari 2'), findsOneWidget);
      expect(find.textContaining('Menampilkan 1–20 dari 21 data'), findsOneWidget);

      // Page 1 displays items #21 down to #2
      expect(find.text('Tx #21'), findsOneWidget);
      expect(find.text('Tx #2'), findsOneWidget);
      expect(find.text('Tx #1'), findsNothing); // Item 21 is on page 2!

      // Prev button is disabled on page 1
      final prevBtn = tester.widget<OutlinedButton>(find.byKey(const Key('cashbook_pagination_prev')));
      expect(prevBtn.onPressed, isNull);

      // Next button is enabled on page 1
      final nextBtn = tester.widget<OutlinedButton>(find.byKey(const Key('cashbook_pagination_next')));
      expect(nextBtn.onPressed, isNotNull);

      // Ensure next button is scrolled into view before tapping
      await tester.ensureVisible(find.byKey(const Key('cashbook_pagination_next')));
      await tester.pumpAndSettle();

      // Tap Next to go to page 2
      await tester.tap(find.byKey(const Key('cashbook_pagination_next')));
      await tester.pumpAndSettle();

      // Page 2 displays only Item #1
      expect(find.textContaining('Halaman 2 dari 2'), findsOneWidget);
      expect(find.textContaining('Menampilkan 21–21 dari 21 data'), findsOneWidget);
      expect(find.text('Tx #1'), findsOneWidget);
      expect(find.text('Tx #21'), findsNothing);

      // Prev button is enabled on page 2
      final prevBtnP2 = tester.widget<OutlinedButton>(find.byKey(const Key('cashbook_pagination_prev')));
      expect(prevBtnP2.onPressed, isNotNull);

      // Next button is disabled on page 2
      final nextBtnP2 = tester.widget<OutlinedButton>(find.byKey(const Key('cashbook_pagination_next')));
      expect(nextBtnP2.onPressed, isNull);

      // Tap Prev to go back to page 1
      await tester.ensureVisible(find.byKey(const Key('cashbook_pagination_prev')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('cashbook_pagination_prev')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Halaman 1 dari 2'), findsOneWidget);
      expect(find.text('Tx #21'), findsOneWidget);
    });

    testWidgets('4. Data 45 records: 3 pages with direct page number navigation without missing or duplicated records', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final now = DateTime.now();
      final monthStr = now.month.toString().padLeft(2, '0');
      final txList = List.generate(
        45,
        (i) => CashTransactionModel(
          id: 45 - i,
          type: 'income',
          category: 'iuran',
          amount: 50000,
          transactionDate: '${now.year}-$monthStr-15',
          description: 'Transaksi Nomor ${45 - i}',
          creatorName: 'Bendahara',
          createdAt: DateTime.now(),
        ),
      );

      final repo = FakeCashbookRepo(allTransactions: txList);
      await tester.pumpWidget(createWidget(repo));
      await tester.pumpAndSettle();

      expect(find.text('45 Mutasi'), findsOneWidget);
      expect(find.textContaining('Halaman 1 dari 3'), findsOneWidget);
      expect(find.text('Transaksi Nomor 45'), findsOneWidget);
      expect(find.text('Transaksi Nomor 26'), findsOneWidget);
      expect(find.text('Transaksi Nomor 25'), findsNothing);

      // Navigate to page 2 via page number button '2'
      await tester.ensureVisible(find.byKey(const Key('cashbook_page_2')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('cashbook_page_2')));
      await tester.pumpAndSettle();

      expect(find.textContaining('Halaman 2 dari 3'), findsOneWidget);
      expect(find.text('Transaksi Nomor 25'), findsOneWidget);
      expect(find.text('Transaksi Nomor 6'), findsOneWidget);
      expect(find.text('Transaksi Nomor 45'), findsNothing);
      expect(find.text('Transaksi Nomor 5'), findsNothing);

      // Navigate to page 3 via page number button '3'
      await tester.ensureVisible(find.byKey(const Key('cashbook_page_3')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('cashbook_page_3')));
      await tester.pumpAndSettle();

      expect(find.textContaining('Halaman 3 dari 3'), findsOneWidget);
      expect(find.textContaining('Menampilkan 41–45 dari 45 data'), findsOneWidget);
      expect(find.text('Transaksi Nomor 5'), findsOneWidget);
      expect(find.text('Transaksi Nomor 1'), findsOneWidget);
      expect(find.text('Transaksi Nomor 6'), findsNothing);
    });

    testWidgets('5. Changing filter month or year resets current page back to page 1', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final now = DateTime.now();
      final currentMonthStr = now.month.toString().padLeft(2, '0');
      final targetMonth = now.month == 1 ? 2 : 1;
      final targetMonthStr = targetMonth.toString().padLeft(2, '0');

      // Create 25 items for current month and 25 items for target month
      final txList = <CashTransactionModel>[
        ...List.generate(
          25,
          (i) => CashTransactionModel(
            id: 100 + i,
            type: 'income',
            category: 'iuran',
            amount: 50000,
            transactionDate: '${now.year}-$currentMonthStr-10',
            description: 'Bulan Sekarang $i',
            creatorName: 'Admin',
            createdAt: DateTime.now(),
          ),
        ),
        ...List.generate(
          25,
          (i) => CashTransactionModel(
            id: 200 + i,
            type: 'income',
            category: 'iuran',
            amount: 50000,
            transactionDate: '${now.year}-$targetMonthStr-10',
            description: 'Bulan Target $i',
            creatorName: 'Admin',
            createdAt: DateTime.now(),
          ),
        ),
      ];

      final repo = FakeCashbookRepo(allTransactions: txList);
      await tester.pumpWidget(createWidget(repo));
      await tester.pumpAndSettle();

      // Go to page 2 of current month
      expect(find.textContaining('Halaman 1 dari 2'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('cashbook_pagination_next')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('cashbook_pagination_next')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Halaman 2 dari 2'), findsOneWidget);

      // Now scroll back up to the dropdown
      final dropdownFinder = find.byWidgetPredicate(
        (w) => w is DropdownButton<int> && w.value == now.month,
      );
      expect(dropdownFinder, findsOneWidget);
      await tester.ensureVisible(dropdownFinder);
      await tester.pumpAndSettle();

      await tester.tap(dropdownFinder);
      await tester.pumpAndSettle();

      // Select target month
      final monthName = targetMonth == 1 ? 'Januari' : 'Februari';
      await tester.tap(find.text(monthName).last);
      await tester.pumpAndSettle();

      // Must be reset to page 1 of target month!
      expect(find.textContaining('Halaman 1 dari 2'), findsOneWidget);
      expect(find.textContaining('Menampilkan 1–20 dari 25 data'), findsOneWidget);
      expect(find.text('Bulan Target 24'), findsOneWidget);
      expect(find.text('Bulan Target 0'), findsNothing); // item 0 is on page 2
    });
  });
}
