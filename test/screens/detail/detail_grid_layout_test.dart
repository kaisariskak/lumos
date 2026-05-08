import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:reportdeepen/screens/detail/detail_screen.dart';

void main() {
  test('detail metric grid gives cards enough vertical space', () {
    final source = File(
      'lib/screens/detail/detail_screen.dart',
    ).readAsStringSync();

    expect(source, contains('GridView.builder'));
    expect(source, contains('mainAxisExtent: 150'));
    expect(source, isNot(contains('childAspectRatio: 1.55')));
  });

  test('admin personal detail loads only admin metrics', () {
    final sources = detailMetricSources(groupId: 'group-1', adminId: 'admin-1');

    expect(sources.loadGroupMetrics, isFalse);
    expect(sources.adminId, 'admin-1');
  });
}
