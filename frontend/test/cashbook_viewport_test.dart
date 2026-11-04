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
    return CashTransactionsResultModel(
      transactions: allTransactions,
      total: allTransactions.length,
      page: page,
      limit: limit,
      period: '2026-10',
      startDate: '2026-10-01',
      endDate: '2026-10-31',
      previousBalance: 5000000,
      periodIncome: 7000000,
      periodExpense: 2000000,
      endingBalance: 10000000,
    );
  }
}

void main() {
  testWidgets('CashbookScreen renders at 320x568 (mobile) without overflow', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final now = DateTime.now();
    final ym = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    final repo = FakeCashbookRepo(
      allTransactions: [
        CashTransactionModel(
          id: 1,
          type: 'income',
          category: 'iuran',
          amount: 150000,
          description: 'Iuran Warga Blok A No 1',
          transactionDate: '$ym-05',
          creatorName: 'Bendahara Cluster',
          createdAt: DateTime.now(),
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: RepositoryProvider<CashbookRepository>.value(
          value: repo,
          child: const CashbookScreen(isAdmin: true),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
