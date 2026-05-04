import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('admin metric edit dialog supports scoring fields', () {
    final source = File('lib/screens/admin/admin_screen.dart').readAsStringSync();

    expect(source, contains('Future<_MetricEditResult?> _showEditMetricDialog'));
    expect(source, contains('class _EditMetricDialog extends StatefulWidget'));
    expect(source, contains('customCatScoringAmountLabel'));
    expect(source, contains('customCatPointsValueLabel'));
    expect(source, contains('updatePointsRule'));
  });
}
