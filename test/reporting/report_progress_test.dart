import 'package:flutter_test/flutter_test.dart';

import 'package:reportdeepen/models/group_metric.dart';
import 'package:reportdeepen/models/ibadat_report.dart';
import 'package:reportdeepen/reporting/report_progress.dart';

void main() {
  test('calculates metric progress as a bounded ratio', () {
    expect(metricProgress(10, 20), 0.5);
    expect(metricProgress(25, 20), 1.0);
    expect(metricProgress(5, 0), 0.0);
  });

  test('calculates report progress from all configured metrics', () {
    final report = IbadatReport(
      userId: 'user-1',
      groupId: 'group-1',
      month: 4,
      year: 2026,
      metricValues: {
        'quran_pages': 10,
        'book_pages': 5,
      },
    );
    final metrics = [
      GroupMetric.test(id: 'quran_pages', maxValue: 20),
      GroupMetric.test(id: 'book_pages', maxValue: 10),
    ];

    expect(reportProgress(report, metrics), 0.5);
  });

  test('ignores metrics without an id when averaging report progress', () {
    final report = IbadatReport(
      userId: 'user-1',
      groupId: 'group-1',
      month: 4,
      year: 2026,
      metricValues: {
        'quran_pages': 10,
      },
    );
    final metrics = [
      GroupMetric.test(id: null, maxValue: 10),
      GroupMetric.test(id: 'quran_pages', maxValue: 20),
    ];

    expect(reportProgress(report, metrics), 0.5);
  });

  test('returns quick values from a metric max value', () {
    final metric = GroupMetric.test(maxValue: 40);

    expect(quickValuesFor(metric), [10, 20, 30, 40]);
  });
}
