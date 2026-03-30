import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/ibadat_period.dart';

class IbadatPeriodRepository {
  final SupabaseClient _client;

  IbadatPeriodRepository(this._client);

  Future<List<IbadatPeriod>> getPeriodsForGroup(String groupId) async {
    final data = await _client
        .from('ibadat_periods')
        .select()
        .eq('group_id', groupId)
        .order('start_date', ascending: false);
    return (data as List).map((j) => IbadatPeriod.fromJson(j)).toList();
  }

  Future<IbadatPeriod> createPeriod({
    required String groupId,
    required String label,
    required DateTime startDate,
    required DateTime endDate,
    required String createdBy,
  }) async {
    final data = await _client
        .from('ibadat_periods')
        .insert({
          'group_id': groupId,
          'label': label,
          'start_date': startDate.toIso8601String().split('T').first,
          'end_date': endDate.toIso8601String().split('T').first,
          'created_by': createdBy,
        })
        .select()
        .single();
    return IbadatPeriod.fromJson(data);
  }

  Future<void> deletePeriod(String periodId) async {
    await _client.from('ibadat_periods').delete().eq('id', periodId);
  }
}
