import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('HomeScreen keeps existing reports visible during background reloads', () {
    final source = File('lib/screens/home/home_screen.dart').readAsStringSync();

    expect(source, isNot(contains('_adminReport = null;')));
    expect(source, isNot(contains('          _userMonthlyReports = {};')));
    expect(source, isNot(contains('          _userTrendReports = {};')));
  });
}
