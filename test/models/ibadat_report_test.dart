import 'package:flutter_test/flutter_test.dart';

import 'package:reportdeepen/models/ibadat_report.dart';

void main() {
  test('reads metric values from json and copies them', () {
    final report = IbadatReport.fromJson({
      'id': 'report-1',
      'user_id': 'user-1',
      'group_id': 'group-1',
      'period_id': 'period-1',
      'month': 4,
      'year': 2026,
      'metric_values': {
        'quran_pages': 12,
        'book_pages': 3,
      },
      'submitted_at': '2026-04-18T10:00:00.000Z',
      'updated_at': '2026-04-18T11:00:00.000Z',
    });

    expect(report.metricValues, {
      'quran_pages': 12,
      'book_pages': 3,
    });
    expect(report.valueForMetric('quran_pages'), 12);
    expect(report.valueForMetric('missing'), 0);

    final copied = report.copyWith(
      periodId: 'period-2',
      metricValues: {'quran_pages': 20},
    );

    expect(copied.periodId, 'period-2');
    expect(copied.metricValues, {'quran_pages': 20});
    expect(copied.toJson(), {
      'user_id': 'user-1',
      'group_id': 'group-1',
      'period_id': 'period-2',
      'month': 4,
      'year': 2026,
    });
  });

  test('copies metric values defensively in constructor and copyWith', () {
    final sourceValues = {
      'quran_pages': 12,
    };
    final report = IbadatReport(
      userId: 'user-1',
      groupId: 'group-1',
      month: 4,
      year: 2026,
      metricValues: sourceValues,
    );

    sourceValues['quran_pages'] = 99;

    expect(report.metricValues, {
      'quran_pages': 12,
    });

    final copied = report.copyWith();
    copied.setValue('quran_pages', 20);

    expect(copied.metricValues, {
      'quran_pages': 20,
    });
    expect(report.metricValues, {
      'quran_pages': 12,
    });
  });

}
