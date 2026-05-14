import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('metric icon picker includes prayer sitting icon', () {
    final source = File('lib/screens/admin/admin_screen.dart').readAsStringSync();

    expect(source, contains("'🧎'"));
  });
}
