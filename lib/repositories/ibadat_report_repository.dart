import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/ibadat_report.dart';

class IbadatReportRepository {
  final SupabaseClient _client;

  IbadatReportRepository(this._client);

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
    return IbadatReport.fromJson(data);
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

  /// UPSERT report — creates or updates
  Future<IbadatReport> upsertReport(IbadatReport report) async {
    final payload = {
      ...report.toJson(),
      'updated_at': DateTime.now().toIso8601String(),
    };
    final data = await _client
        .from('ibadat_reports')
        .upsert(
          payload,
          onConflict: 'user_id,group_id,month,year',
        )
        .select()
        .single();
    return IbadatReport.fromJson(data);
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
}
