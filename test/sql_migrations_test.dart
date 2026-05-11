import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('latest report RLS migration does not depend on ibadat_members', () {
    final migration = File(
      '2026_05_11_repair_report_rls_without_ibadat_members.sql',
    );

    expect(migration.existsSync(), isTrue);
    final sql = migration.readAsStringSync();

    expect(sql, isNot(contains('ibadat_members')));
    expect(sql, contains('ON ibadat_reports'));
    expect(sql, contains('ON report_metric_values'));
    expect(sql, contains('current_group_id'));
    expect(sql, contains('ibadat_groups'));
  });
}
