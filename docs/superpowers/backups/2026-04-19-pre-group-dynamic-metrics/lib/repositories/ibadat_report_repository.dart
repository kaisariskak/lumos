import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/ibadat_report.dart';
import 'custom_category_repository.dart';

class IbadatReportRepository {
  final SupabaseClient _client;
  late final CustomCategoryRepository _customRepo;

  IbadatReportRepository(this._client) {
    _customRepo = CustomCategoryRepository(_client);
  }

  Future<void> _loadCustomValues(IbadatReport report) async {
    if (report.id == null) return;
    report.customValues = await _customRepo.getCustomValues(report.id!);
  }

  Future<IbadatReport?> getReport({
    required String userId,
    required String groupId,
    required int month,
    required int year,
  }) async {
    final data = await _client
        .from('ibadat_reports')
        .select()
        .eq('user_id', userId)
        .eq('group_id', groupId)
        .eq('month', month)
        .eq('year', year)
        .maybeSingle();
    if (data == null) return null;
    final report = IbadatReport.fromJson(data);
    await _loadCustomValues(report);
    return report;
  }

  /// Get report by period_id for a specific user
  Future<IbadatReport?> getReportByPeriod({
    required String userId,
    required String groupId,
    required String periodId,
  }) async {
    final data = await _client
        .from('ibadat_reports')
        .select()
        .eq('user_id', userId)
        .eq('group_id', groupId)
        .eq('period_id', periodId)
        .maybeSingle();
    if (data == null) return null;
    final report = IbadatReport.fromJson(data);
    await _loadCustomValues(report);
    return report;
  }

  Future<List<IbadatReport>> getGroupReports({
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
    return (data as List).map((e) => IbadatReport.fromJson(e)).toList();
  }

  /// Get all reports for a group by period_id
  Future<List<IbadatReport>> getGroupReportsByPeriod({
    required String groupId,
    required String periodId,
  }) async {
    final data = await _client
        .from('ibadat_reports')
        .select()
        .eq('group_id', groupId)
        .eq('period_id', periodId);
    return (data as List).map((e) => IbadatReport.fromJson(e)).toList();
  }

  /// UPSERT report — creates or updates
  Future<IbadatReport> upsertReport(IbadatReport report) async {
    final payload = {
      ...report.toJson(),
      'updated_at': DateTime.now().toIso8601String(),
    };
    // If period_id is set — conflict on period, otherwise on month/year
    final onConflict = report.periodId != null
        ? 'user_id,group_id,period_id'
        : 'user_id,group_id,month,year';
    final data = await _client
        .from('ibadat_reports')
        .upsert(payload, onConflict: onConflict)
        .select()
        .single();
    final saved = IbadatReport.fromJson(data);
    saved.customValues = report.customValues;
    if (saved.customValues.isNotEmpty) {
      await _customRepo.upsertCustomValues(saved.id!, saved.customValues);
    }
    return saved;
  }

  /// Returns true if any reports exist for the given period_id
  Future<bool> hasReportsForPeriod({
    required String groupId,
    required String periodId,
  }) async {
    final data = await _client
        .from('ibadat_reports')
        .select('id')
        .eq('group_id', groupId)
        .eq('period_id', periodId)
        .limit(1);
    return (data as List).isNotEmpty;
  }

  /// Returns last N months of reports for a user (for trend chart)
  Future<List<IbadatReport>> getUserRecentReports({
    required String userId,
    required String groupId,
    required List<int> months,
    required int year,
  }) async {
    final data = await _client
        .from('ibadat_reports')
        .select()
        .eq('user_id', userId)
        .eq('group_id', groupId)
        .eq('year', year)
        .inFilter('month', months);
    return (data as List).map((e) => IbadatReport.fromJson(e)).toList();
  }

  /// Move a user's report for a specific period to a new group+period
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

  /// Move all reports of a user from one group to another (no period filter)
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
}
