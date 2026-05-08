import 'package:flutter_test/flutter_test.dart';
import 'package:reportdeepen/payments/payment_amount_format.dart';

void main() {
  test('formats amount with thousand separators', () {
    expect(formatPaymentAmount(50000), '50 000');
    expect(formatPaymentAmount(150000), '150 000');
    expect(formatPaymentAmount(200000), '200 000');
  });
}
