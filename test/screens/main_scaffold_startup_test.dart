import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('MainScaffold does not warm up inactive tabs on startup', () {
    final source = File('lib/screens/main_scaffold.dart').readAsStringSync();

    expect(source, isNot(contains('_scheduleTabWarmUp')));
    expect(source, isNot(contains('warmUpTab')));
  });
}
