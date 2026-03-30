import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/ibadat_member_settings.dart';

class MemberSettingsRepository {
  final SupabaseClient _client;

  MemberSettingsRepository(this._client);

  Future<IbadatMemberSettings?> getSettings(
      String groupId, String profileId) async {
    final data = await _client
        .from('ibadat_member_settings')
        .select()
        .eq('group_id', groupId)
        .eq('profile_id', profileId)
        .maybeSingle();
    if (data == null) return null;
    return IbadatMemberSettings.fromJson(data);
  }

  Future<Map<String, IbadatMemberSettings>> getSettingsForGroup(
      String groupId) async {
    final data = await _client
        .from('ibadat_member_settings')
        .select()
        .eq('group_id', groupId);
    return {
      for (final row in data as List)
        (row['profile_id'] as String):
            IbadatMemberSettings.fromJson(row),
    };
  }

  Future<void> upsertSettings(IbadatMemberSettings settings) async {
    await _client.from('ibadat_member_settings').upsert(
          settings.toJson(),
          onConflict: 'group_id,profile_id',
        );
  }
}
