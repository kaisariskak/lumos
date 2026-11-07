import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:reportdeepen/models/group_metric.dart';
import 'package:reportdeepen/models/ibadat_group.dart';
import 'package:reportdeepen/models/ibadat_period.dart';
import 'package:reportdeepen/models/ibadat_profile.dart';
import 'package:reportdeepen/models/ibadat_report.dart';
import 'package:reportdeepen/reporting/monthly_group_report.dart';
import 'package:reportdeepen/reporting/monthly_report_pdf.dart';

MonthlyGroupReport _sampleReport({int memberCount = 40, int metricCount = 7}) {
  final group = IbadatGroup(
    id: 'g',
    name: 'Нұр тобы',
    code: 'C',
    adminId: 'admin',
    createdAt: DateTime(2026),
  );
  final metrics = [
    for (var i = 0; i < metricCount; i++)
      GroupMetric.test(
        id: 'm$i',
        nameRu: 'Показатель $i',
        nameKk: 'Құран оқу $i',
        unit: 'бет',
        maxValue: 20 + i,
        pointsPerUnit: i.isEven ? 1 : null,
        pointsValue: i.isEven ? 2 : null,
        orderIndex: i,
      ),
  ];
  final periods = [
    IbadatPeriod(
      id: 'p1',
      groupId: 'g',
      label: 'p1',
      startDate: DateTime(2026, 10, 1),
      endDate: DateTime(2026, 10, 14),
      createdBy: 'admin',
      createdAt: DateTime(2026),
    ),
    IbadatPeriod(
      id: 'p2',
      groupId: 'g',
      label: 'p2',
      startDate: DateTime(2026, 10, 28),
      endDate: DateTime(2026, 11, 3),
      createdBy: 'admin',
      createdAt: DateTime(2026),
    ),
  ];
  final members = [
    for (var i = 0; i < memberCount; i++)
      IbadatProfile(
        id: 'u$i',
        nickname: 'Әлібек Қуанышұлы $i',
        role: 'user',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
  ];
  final reports = [
    for (var i = 0; i < memberCount; i += 1)
      if (i % 5 != 0)
        for (final p in periods)
          IbadatReport(
            userId: 'u$i',
            groupId: 'g',
            periodId: p.id,
            month: 10,
            year: 2026,
            metricValues: {
              for (var j = 0; j < metrics.length; j++)
                metrics[j].id!: (i * 3 + j * 7) % 32,
            },
          ),
  ];
  return buildMonthlyGroupReport(
    group: group,
    month: 10,
    year: 2026,
    members: members,
    metrics: metrics,
    periods: periods,
    reports: reports,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('PDF language matches the UI language', () {
    expect(pdfLanguageFor('ru'), 'ru');
    expect(pdfLanguageFor('kk'), 'kk');
  });

  for (final lang in ['kk', 'ru']) {
    test('builds a multi-page $lang PDF', () async {
      final bytes = await buildMonthlyReportPdf(
        _sampleReport(),
        lang: lang,
        generatedAt: DateTime(2026, 11, 6),
      );
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');

      final out = Platform.environment['PDF_SAMPLE_DIR'];
      if (out != null) {
        File('$out/sample_$lang.pdf').writeAsBytesSync(bytes);
      }
    });
  }
}
