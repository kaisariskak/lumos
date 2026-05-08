import 'package:flutter_test/flutter_test.dart';
import 'package:reportdeepen/payments/payment_balance.dart';

void main() {
  group('remainingFixedMonthlyDebt', () {
    test('returns the difference when current month total is below fixed amount', () {
      expect(
        remainingFixedMonthlyDebt(
          fixedMonthlyAmount: 200000,
          currentMonthPaid: 150000,
        ),
        50000,
      );
    });

    test('returns zero when current month total reaches fixed amount', () {
      expect(
        remainingFixedMonthlyDebt(
          fixedMonthlyAmount: 200000,
          currentMonthPaid: 200000,
        ),
        0,
      );
    });
  });
}
