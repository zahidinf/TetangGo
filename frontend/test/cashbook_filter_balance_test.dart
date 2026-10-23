import 'package:flutter_test/flutter_test.dart';
import 'package:tetanggo_frontend/features/cashbook/domain/models/cashbook_models.dart';

void main() {
  group('Cashbook Filter & Balance Model Tests', () {
    test('CashTransactionsResultModel accurately parses period and balances', () {
      final json = {
        'success': true,
        'data': [
          {
            'id': 1,
            'type': 'income',
            'category': 'iuran',
            'amount': 150000.0,
            'transaction_date': '2026-10-05',
            'description': 'Iuran Blok A No. 1',
            'creator_name': 'Bendahara RT',
            'created_at': '2026-10-05T10:00:00Z',
          },
          {
            'id': 2,
            'type': 'expense',
            'category': 'operasional',
            'amount': 50000.0,
            'transaction_date': '2026-10-10',
            'description': 'Beli ATK',
            'creator_name': 'Sekretaris RT',
            'created_at': '2026-10-10T14:00:00Z',
          }
        ],
        'total': 2,
        'page': 1,
        'limit': 20,
        'period': '2026-10',
        'start_date': '2026-10-01',
        'end_date': '2026-10-31',
        'previous_balance': 500000.0,
        'period_income': 150000.0,
        'period_expense': 50000.0,
        'ending_balance': 600000.0,
      };

      final result = CashTransactionsResultModel.fromJson(json);

      expect(result.transactions.length, 2);
      expect(result.period, '2026-10');
      expect(result.startDate, '2026-10-01');
      expect(result.endDate, '2026-10-31');
      expect(result.previousBalance, 500000.0);
      expect(result.periodIncome, 150000.0);
      expect(result.periodExpense, 50000.0);
      expect(result.endingBalance, 600000.0);
      // Mathematical consistency check
      expect(
        result.endingBalance,
        result.previousBalance + result.periodIncome - result.periodExpense,
      );
    });

    test('CashTransactionsResultModel handles empty period or zero initial balances correctly', () {
      final json = {
        'success': true,
        'data': [],
        'total': 0,
        'page': 1,
        'limit': 20,
        'period': '2026-01',
        'start_date': '2026-01-01',
        'end_date': '2026-01-31',
        'previous_balance': 0.0,
        'period_income': 0.0,
        'period_expense': 0.0,
        'ending_balance': 0.0,
      };

      final result = CashTransactionsResultModel.fromJson(json);

      expect(result.transactions.isEmpty, isTrue);
      expect(result.total, 0);
      expect(result.previousBalance, 0.0);
      expect(result.endingBalance, 0.0);
    });
  });
}
