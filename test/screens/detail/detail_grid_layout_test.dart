import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('detail metric grid gives cards enough vertical space', () {
    final source =
        File('lib/screens/detail/detail_screen.dart').readAsStringSync();

    expect(source, contains('GridView.builder'));
    expect(source, contains('mainAxisExtent: 150'));
    expect(source, isNot(contains('childAspectRatio: 1.55')));
  });
}
