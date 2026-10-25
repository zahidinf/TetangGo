import 'package:flutter_test/flutter_test.dart';
import 'package:tetanggo_frontend/features/billing/domain/models/billing_models.dart';

void main() {
  group('Billing Business Rules and Status Checks', () {
    test('1. BillModel status getters are strictly consistent', () {
      final unpaid = BillModel.fromJson({
        'id': 1,
        'house_id': 10,
        'billing_period': '2026-10',
        'amount': 35000,
        'status': 'unpaid',
      });
      expect(unpaid.isUnpaid, isTrue);
      expect(unpaid.isPending, isFalse);
      expect(unpaid.isPaid, isFalse);
      expect(unpaid.isRejected, isFalse);

      final pending = BillModel.fromJson({
        'id': 2,
        'house_id': 10,
        'billing_period': '2026-10',
        'amount': 35000,
        'status': 'pending_verification',
      });
      expect(pending.isPending, isTrue);
      expect(pending.isUnpaid, isFalse);
      expect(pending.isPaid, isFalse);
      expect(pending.isRejected, isFalse);

      final paid = BillModel.fromJson({
        'id': 3,
        'house_id': 10,
        'billing_period': '2026-10',
        'amount': 35000,
        'status': 'paid',
      });
      expect(paid.isPaid, isTrue);
      expect(paid.isPending, isFalse);
      expect(paid.isUnpaid, isFalse);
      expect(paid.isRejected, isFalse);

      final rejected = BillModel.fromJson({
        'id': 4,
        'house_id': 10,
        'billing_period': '2026-10',
        'amount': 35000,
        'status': 'rejected',
        'payment': {
          'id': 99,
          'bill_id': 4,
          'amount_paid': 35000,
          'proof_image_url': '/uploads/test.jpg',
          'rejection_reason': 'Nominal kurang',
        },
      });
      expect(rejected.isRejected, isTrue);
      expect(rejected.isPaid, isFalse);
      expect(rejected.isPending, isFalse);
      expect(rejected.isUnpaid, isFalse);
      expect(rejected.payment?.rejectionReason, equals('Nominal kurang'));
    });

    test(
        '2. Multiple bills on the same period filter only one active payment allowed',
        () {
      final bills = [
        BillModel.fromJson({
          'id': 10,
          'house_id': 10,
          'billing_period': '2026-10',
          'amount': 35000,
          'status': 'pending_verification',
        }),
        BillModel.fromJson({
          'id': 11,
          'house_id': 10,
          'billing_period': '2026-11',
          'amount': 35000,
          'status': 'rejected',
        }),
      ];

      // Checking period 2026-10
      final octBill = bills.firstWhere((b) => b.billingPeriod == '2026-10');
      expect(octBill.isPending, isTrue);
      // New payment should be prevented
      final canCreateNewPaymentForOct = !octBill.isPending && !octBill.isPaid;
      expect(canCreateNewPaymentForOct, isFalse);

      // Checking period 2026-11
      final novBill = bills.firstWhere((b) => b.billingPeriod == '2026-11');
      expect(novBill.isRejected, isTrue);
      // Rejected bill allows re-submitting payment
      final canResubmitPaymentForNov = novBill.isRejected || novBill.isUnpaid;
      expect(canResubmitPaymentForNov, isTrue);
    });
  });
}
