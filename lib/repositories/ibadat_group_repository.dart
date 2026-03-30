import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/ibadat_group.dart';
import '../models/ibadat_profile.dart';

class IbadatGroupRepository {
  final SupabaseClient _client;

  IbadatGroupRepository(this._client);

  Future<List<IbadatGroup>> getAllGroups() async {
    final data = await _client
        .from('ibadat_groups')
        .select()
        .order('created_at', ascending: false);
    return (data as List).map((e) => IbadatGroup.fromJson(e)).toList();
  }

  /// Returns only groups whose admin is in the given list (for super-admin scoped view)
  Future<List<IbadatGroup>> getGroupsByAdminIds(List<String> adminIds) async {
    if (adminIds.isEmpty) return [];
    final data = await _client
        .from('ibadat_groups')
        .select()
        .inFilter('admin_id', adminIds)
        .order('created_at', ascending: false);
    return (data as List).map((e) => IbadatGroup.fromJson(e)).toList();
  }

  Future<IbadatGroup?> getGroupById(String id) async {
    final data = await _client
        .from('ibadat_groups')
        .select()
        .eq('id', id)
        .maybeSingle();
    if (data == null) return null;
    return IbadatGroup.fromJson(data);
  }

  Future<IbadatGroup> createGroup(String name, String adminId) async {
    final prefix = name.trim().substring(0, name.trim().length.clamp(0, 3)).toUpperCase();
    final code = '$prefix${1000 + (DateTime.now().millisecondsSinceEpoch % 9000)}';
    final data = await _client
        .from('ibadat_groups')
        .insert({'name': name.trim(), 'code': code, 'admin_id': adminId})
        .select()
        .single();
    return IbadatGroup.fromJson(data);
  }

  Future<void> updateFinancier(String groupId, String? financierId) async {
    final result = await _client
        .from('ibadat_groups')
        .update({'financier_id': financierId})
        .eq('id', groupId)
        .select();
    if ((result as List).isEmpty) {
      throw Exception('Жаңарту сәтсіз: RLS рұқсаты жоқ немесе топ табылмады');
    }
  }

  Future<void> deleteGroup(String groupId) async {
    // Delete all FK-dependent records first
    await _client.from('ibadat_reports').delete().eq('group_id', groupId);
    await _client.from('ibadat_periods').delete().eq('group_id', groupId);
    await _client.from('ibadat_groups').delete().eq('id', groupId);
  }

  Future<List<IbadatProfile>> getGroupMembers(String groupId) async {
    final data = await _client
        .from('ibadat_profiles')
        .select()
        .eq('current_group_id', groupId);
    return (data as List).map((e) => IbadatProfile.fromJson(e)).toList();
  }
}
