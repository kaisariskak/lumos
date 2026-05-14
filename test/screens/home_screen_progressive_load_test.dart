import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('HomeScreen loads reports after the base list data', () {
    final source = File('lib/screens/home/home_screen.dart').readAsStringSync();
    final loadSectionStart = source.indexOf(
      'Future<_GroupSection> _loadSection',
    );
    final adminReportsStart = source.indexOf('Future<void> _loadAdminReports');
    final loadSectionSource = source.substring(
      loadSectionStart,
      adminReportsStart,
    );

    expect(source, contains('Future<void> _loadAdminReports'));
    expect(source, contains('Future<void> _loadUserReports'));
    expect(
      loadSectionSource,
      isNot(contains('await _loadSectionReports(section);')),
    );
  });
}
