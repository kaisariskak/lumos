import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/ibadat_report.dart';

abstract class IbadatReportDataStore {
  Future<Map<String, dynamic>?> getReport({
    required String userId,
    String? groupId,
    required int month,
    required int year,
  }) {
    throw UnimplementedError();
  }

  Future<Map<String, dynamic>?> getReportByPeriod({
    required String userId,
    String? groupId,
    required String periodId,
  }) {
    throw UnimplementedError();
  }

  Future<List<Map<String, dynamic>>> getGroupReports({
    required String groupId,
    required int month,
    required int year,
  }) {
    throw UnimplementedError();
  }

  Future<List<Map<String, dynamic>>> getGroupReportsByPeriod({
    required String groupId,
    required String periodId,
  }) {
    throw UnimplementedError();
  }

  Future<Map<String, dynamic>> upsertReportHeader(
    Map<String, dynamic> payload, {
    required String onConflict,
  }) {
    throw UnimplementedError();
  }

  Future<Map<String, dynamic>> insertReportHeader(
    Map<String, dynamic> payload,
  ) {
    throw UnimplementedError();
  }

  Future<Map<String, dynamic>> updateReportHeader(
    String reportId,
    Map<String, dynamic> payload,
  ) {
    throw UnimplementedError();
  }

  Future<bool> hasReportsForPeriod({
    String? groupId,
    required String periodId,
  }) {
    throw UnimplementedError();
  }

  Future<List<Map<String, dynamic>>> getUserRecentReports({
    required String userId,
    String? groupId,
    required List<int> months,
    required int year,
  }) {
    throw UnimplementedError();
  }

  Future<void> moveUserReportsByPeriod({
    required String userId,
    required String fromGroupId,
    required String fromPeriodId,
    required String toGroupId,
    required String toPeriodId,
  }) {
    throw UnimplementedError();
  }

  Future<void> moveUserReports({
    required String userId,
    required String fromGroupId,
    required String toGroupId,
  }) {
    throw UnimplementedError();
  }

  Future<Map<String, int>> getMetricValues(String reportId) {
    throw UnimplementedError();
  }

  Future<void> replaceMetricValues(String reportId, Map<String, int> metricValues) {
    throw UnimplementedError();
  }
}

class IbadatReportRepository {
  final IbadatReportDataStore _store;

  IbadatReportRepository(SupabaseClient client)
      : _store = _SupabaseIbadatReportDataStore(client);

  IbadatReportRepository.withStore(IbadatReportDataStore store) : _store = store;

  Future<IbadatReport?> getReport({
    required String userId,
    String? groupId,
    required int month,
    required int year,
  }) async {
    final data = await _store.getReport(
      userId: userId,
      groupId: groupId,
      month: month,
      year: year,
    );
    if (data == null) return null;
    return _hydrateReport(data);
  }

  Future<IbadatReport?> getReportByPeriod({
    required String userId,
    String? groupId,
    required String periodId,
  }) async {
    final data = await _store.getReportByPeriod(
      userId: userId,
      groupId: groupId,
      periodId: periodId,
    );
    if (data == null) return null;
    return _hydrateReport(data);
  }

  Future<List<IbadatReport>> getGroupReports({
    required String groupId,
    required int month,
    required int year,
  }) async {
    final data = await _store.getGroupReports(
      groupId: groupId,
      month: month,
      year: year,
    );
    return _hydrateReports(data);
  }

  Future<List<IbadatReport>> getGroupReportsByPeriod({
    required String groupId,
    required String periodId,
  }) async {
    final data = await _store.getGroupReportsByPeriod(
      groupId: groupId,
      periodId: periodId,
    );
    return _hydrateReports(data);
  }

  Future<IbadatReport> upsertReport(IbadatReport report) async {
    final payload = {
      ...report.toJson(),
      'updated_at': DateTime.now().toIso8601String(),
    };

    Map<String, dynamic> data;
    if (report.groupId == null) {
      // Personal report — Postgres treats NULL as distinct in UNIQUE,
      // so ON CONFLICT is unreliable. Fetch-then-update-or-insert.
      Map<String, dynamic>? existing;
      if (report.periodId != null) {
        existing = await _store.getReportByPeriod(
          userId: report.userId,
          groupId: null,
          periodId: report.periodId!,
        );
      } else {
        existing = await _store.getReport(
          userId: report.userId,
          groupId: null,
          month: report.month,
          year: report.year,
        );
      }
      if (existing != null) {
        data = await _store.updateReportHeader(existing['id'] as String, payload);
      } else {
        data = await _store.insertReportHeader(payload);
      }
    } else {
      final onConflict = report.periodId != null
          ? 'user_id,group_id,period_id'
          : 'user_id,group_id,month,year';
      data = await _store.upsertReportHeader(payload, onConflict: onConflict);
    }

    final reportId = data['id'] as String?;
    if (reportId != null) {
      await _store.replaceMetricValues(reportId, report.metricValues);
    }
    return _hydrateReport(data);
  }

  Future<bool> hasReportsForPeriod({
    String? groupId,
    required String periodId,
  }) {
    return _store.hasReportsForPeriod(groupId: groupId, periodId: periodId);
  }

  Future<List<IbadatReport>> getUserRecentReports({
    required String userId,
    String? groupId,
    required List<int> months,
    required int year,
  }) async {
    final data = await _store.getUserRecentReports(
      userId: userId,
      groupId: groupId,
      months: months,
      year: year,
    );
    return _hydrateReports(data);
  }

  Future<void> moveUserReportsByPeriod({
    required String userId,
    required String fromGroupId,
    required String fromPeriodId,
    required String toGroupId,
    required String toPeriodId,
  }) {
    return _store.moveUserReportsByPeriod(
      userId: userId,
      fromGroupId: fromGroupId,
      fromPeriodId: fromPeriodId,
      toGroupId: toGroupId,
      toPeriodId: toPeriodId,
    );
  }

  Future<void> moveUserReports({
    required String userId,
    required String fromGroupId,
    required String toGroupId,
  }) {
    return _store.moveUserReports(
      userId: userId,
      fromGroupId: fromGroupId,
      toGroupId: toGroupId,
    );
  }

  Future<IbadatReport> _hydrateReport(Map<String, dynamic> data) async {
    final report = IbadatReport.fromJson(data);
    final reportId = report.id;
    if (reportId == null) {
      return report;
    }

    final dynamicValues = await _store.getMetricValues(reportId);
    if (dynamicValues.isEmpty) {
      return report;
    }

    return report.copyWith(
      metricValues: {
        ...report.metricValues,
        ...dynamicValues,
      },
    );
  }

  Future<List<IbadatReport>> _hydrateReports(List<Map<String, dynamic>> data) async {
    final reports = <IbadatReport>[];
    for (final item in data) {
      reports.add(await _hydrateReport(item));
    }
    return reports;
  }
}

class _SupabaseIbadatReportDataStore extends IbadatReportDataStore {
  _SupabaseIbadatReportDataStore(this._client);

  final SupabaseClient _client;

  @override
  Future<Map<String, dynamic>?> getReport({
    required String userId,
    String? groupId,
    required int month,
    required int year,
  }) async {
    var query = _client
        .from('ibadat_reports')
        .select()
        .eq('user_id', userId)
        .eq('month', month)
        .eq('year', year);
    query = groupId == null
        ? query.isFilter('group_id', null)
        : query.eq('group_id', groupId);
    return await query.maybeSingle();
  }

  @override
  Future<Map<String, dynamic>?> getReportByPeriod({
    required String userId,
    String? groupId,
    required String periodId,
  }) async {
    var query = _client
        .from('ibadat_reports')
        .select()
        .eq('user_id', userId)
        .eq('period_id', periodId);
    query = groupId == null
        ? query.isFilter('group_id', null)
        : query.eq('group_id', groupId);
    return await query.maybeSingle();
  }

  @override
  Future<List<Map<String, dynamic>>> getGroupReports({
    required String groupId,
    required int month,
    required int year,
  }) async {
    final data = await _client
        .from('ibadat_reports')
        .select()
        .eq('group_id', groupId)
        .eq('month', month)
        .eq('year', year);
    return _castRows(data);
  }

  @override
  Future<List<Map<String, dynamic>>> getGroupReportsByPeriod({
    required String groupId,
    required String periodId,
  }) async {
    final data = await _client
        .from('ibadat_reports')
        .select()
        .eq('group_id', groupId)
        .eq('period_id', periodId);
    return _castRows(data);
  }

  @override
  Future<Map<String, dynamic>> upsertReportHeader(
    Map<String, dynamic> payload, {
    required String onConflict,
  }) async {
    return await _client
        .from('ibadat_reports')
        .upsert(payload, onConflict: onConflict)
        .select()
        .single();
  }

  @override
  Future<Map<String, dynamic>> insertReportHeader(
    Map<String, dynamic> payload,
  ) async {
    return await _client
        .from('ibadat_reports')
        .insert(payload)
        .select()
        .single();
  }

  @override
  Future<Map<String, dynamic>> updateReportHeader(
    String reportId,
    Map<String, dynamic> payload,
  ) async {
    return await _client
        .from('ibadat_reports')
        .update(payload)
        .eq('id', reportId)
        .select()
        .single();
  }

  @override
  Future<bool> hasReportsForPeriod({
    String? groupId,
    required String periodId,
  }) async {
    var query = _client
        .from('ibadat_reports')
        .select('id')
        .eq('period_id', periodId);
    query = groupId == null
        ? query.isFilter('group_id', null)
        : query.eq('group_id', groupId);
    final data = await query.limit(1);
    return (data as List).isNotEmpty;
  }

  @override
  Future<List<Map<String, dynamic>>> getUserRecentReports({
    required String userId,
    String? groupId,
    required List<int> months,
    required int year,
  }) async {
    var query = _client
        .from('ibadat_reports')
        .select()
        .eq('user_id', userId)
        .eq('year', year);
    query = groupId == null
        ? query.isFilter('group_id', null)
        : query.eq('group_id', groupId);
    final data = await query.inFilter('month', months);
    return _castRows(data);
  }

  @override
  Future<void> moveUserReportsByPeriod({
    required String userId,
    required String fromGroupId,
    required String fromPeriodId,
    required String toGroupId,
    required String toPeriodId,
  }) async {
    await _client
        .from('ibadat_reports')
        .update({'group_id': toGroupId, 'period_id': toPeriodId})
        .eq('user_id', userId)
        .eq('group_id', fromGroupId)
        .eq('period_id', fromPeriodId);
  }

  @override
  Future<void> moveUserReports({
    required String userId,
    required String fromGroupId,
    required String toGroupId,
  }) async {
    await _client
        .from('ibadat_reports')
        .update({'group_id': toGroupId})
        .eq('user_id', userId)
        .eq('group_id', fromGroupId);
  }

  @override
  Future<Map<String, int>> getMetricValues(String reportId) async {
    final data = await _client
        .from('report_metric_values')
        .select('metric_id, value')
        .eq('report_id', reportId);

    final values = <String, int>{};
    for (final row in data as List) {
      final map = Map<String, dynamic>.from(row as Map);
      final metricId = map['metric_id']?.toString();
      final value = map['value'];
      if (metricId == null || value == null) {
        continue;
      }
      values[metricId] = value as int;
    }
    return values;
  }

  @override
  Future<void> replaceMetricValues(String reportId, Map<String, int> metricValues) async {
    final rows = metricValues.entries
        .map(
          (entry) => {
            'report_id': reportId,
            'metric_id': entry.key,
            'value': entry.value,
          },
        )
        .toList();

    if (rows.isNotEmpty) {
      await _client
          .from('report_metric_values')
          .upsert(rows, onConflict: 'report_id,metric_id');
    }

    final existing = await getMetricValues(reportId);
    final staleMetricIds = existing.keys
        .where((metricId) => !metricValues.containsKey(metricId))
        .toList();
    if (staleMetricIds.isEmpty) {
      return;
    }

    await _client
        .from('report_metric_values')
        .delete()
        .eq('report_id', reportId)
        .inFilter('metric_id', staleMetricIds);
  }

  List<Map<String, dynamic>> _castRows(dynamic data) {
    return (data as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
  }
}
