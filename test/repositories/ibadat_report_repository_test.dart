import 'package:flutter_test/flutter_test.dart';

import 'package:reportdeepen/models/ibadat_report.dart';
import 'package:reportdeepen/repositories/ibadat_report_repository.dart';

void main() {
  test('getReport hydrates metric values from dynamic rows', () async {
    final store = _FakeIbadatReportDataStore(
      reportResult: {
        'id': 'report-1',
        'user_id': 'user-1',
        'group_id': 'group-1',
        'month': 4,
        'year': 2026,
      },
      metricValuesByReportId: {
        'report-1': {
          'metric-1': 9,
          'metric-2': 15,
        },
      },
    );
    final repository = IbadatReportRepository.withStore(store);

    final report = await repository.getReport(
      userId: 'user-1',
      groupId: 'group-1',
      month: 4,
      year: 2026,
    );

    expect(report, isNotNull);
    expect(report!.metricValues, {
      'metric-1': 9,
      'metric-2': 15,
    });
  });

  test('upsertReport writes header without legacy columns and persists all metric values', () async {
    final store = _FakeIbadatReportDataStore(
      upsertResult: {
        'id': 'report-2',
        'user_id': 'user-1',
        'group_id': 'group-1',
        'period_id': 'period-1',
        'month': 4,
        'year': 2026,
      },
    );
    final repository = IbadatReportRepository.withStore(store);

    final saved = await repository.upsertReport(
      IbadatReport(
        userId: 'user-1',
        groupId: 'group-1',
        periodId: 'period-1',
        month: 4,
        year: 2026,
        metricValues: {
          'metric-a': 11,
          'metric-custom': 7,
        },
      ),
    );

    expect(store.lastUpsertPayload, isNotNull);
    expect(
      store.lastUpsertPayload!.keys,
      unorderedEquals(<String>[
        'user_id',
        'group_id',
        'period_id',
        'month',
        'year',
        'updated_at',
      ]),
    );
    expect(store.metricValuesByReportId['report-2'], {
      'metric-a': 11,
      'metric-custom': 7,
    });
    expect(saved.metricValues, {
      'metric-a': 11,
      'metric-custom': 7,
    });
  });
}

class _FakeIbadatReportDataStore extends IbadatReportDataStore {
  _FakeIbadatReportDataStore({
    this.reportResult,
    this.upsertResult,
    Map<String, Map<String, int>>? metricValuesByReportId,
  }) : metricValuesByReportId = metricValuesByReportId ?? <String, Map<String, int>>{};

  final Map<String, dynamic>? reportResult;
  final Map<String, dynamic>? upsertResult;
  final Map<String, Map<String, int>> metricValuesByReportId;

  Map<String, dynamic>? lastUpsertPayload;
  String? lastOnConflict;

  @override
  Future<Map<String, dynamic>?> getReport({
    required String userId,
    String? groupId,
    required int month,
    required int year,
  }) async {
    return reportResult;
  }

  @override
  Future<Map<String, dynamic>> upsertReportHeader(
    Map<String, dynamic> payload, {
    required String onConflict,
  }) async {
    lastUpsertPayload = Map<String, dynamic>.from(payload);
    lastOnConflict = onConflict;
    return upsertResult ?? payload;
  }

  @override
  Future<Map<String, int>> getMetricValues(String reportId) async {
    return Map<String, int>.from(metricValuesByReportId[reportId] ?? const <String, int>{});
  }

  @override
  Future<void> replaceMetricValues(String reportId, Map<String, int> metricValues) async {
    metricValuesByReportId[reportId] = Map<String, int>.from(metricValues);
  }
}
