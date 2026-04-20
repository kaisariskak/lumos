import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/group_metric.dart';

class GroupMetricRepository {
  final SupabaseClient _client;

  GroupMetricRepository(this._client);

  Future<List<GroupMetric>> getForGroup(String groupId) async {
    final data = await _client
        .from('group_metrics')
        .select()
        .eq('group_id', groupId)
        .order('order_index', ascending: true)
        .order('created_at', ascending: true);

    return (data as List)
        .map((row) => GroupMetric.fromJson(Map<String, dynamic>.from(row as Map)))
        .toList();
  }

  /// Returns personal metrics belonging to [adminId] (admin_id IS NOT NULL).
  Future<List<GroupMetric>> getForAdmin(String adminId) async {
    final data = await _client
        .from('group_metrics')
        .select()
        .eq('admin_id', adminId)
        .order('order_index', ascending: true)
        .order('created_at', ascending: true);

    return (data as List)
        .map((row) => GroupMetric.fromJson(Map<String, dynamic>.from(row as Map)))
        .toList();
  }

  /// Creates a metric. Exactly one of [groupId] or [adminId] must be provided.
  Future<GroupMetric> create({
    String? groupId,
    String? adminId,
    required String nameRu,
    required String nameKk,
    required String icon,
    required int colorValue,
    required String unit,
    required int maxValue,
    required int orderIndex,
  }) async {
    assert(
      (groupId != null) != (adminId != null),
      'Exactly one of groupId or adminId must be provided',
    );
    final data = await _client
        .from('group_metrics')
        .insert({
          'group_id': groupId,
          'admin_id': adminId,
          'name': nameRu,
          'name_ru': nameRu,
          'name_kk': nameKk,
          'icon': icon,
          'color_value': colorValue.toSigned(32),
          'unit': unit,
          'max_value': maxValue,
          'order_index': orderIndex,
        })
        .select()
        .single();

    return GroupMetric.fromJson(Map<String, dynamic>.from(data));
  }

  Future<void> delete(String id) async {
    await _client.from('group_metrics').delete().eq('id', id);
  }

  Future<bool> hasRecordedValues(String metricId) async {
    final data = await _client
        .from('report_metric_values')
        .select('metric_id')
        .eq('metric_id', metricId)
        .limit(1);

    return (data as List).isNotEmpty;
  }
}
