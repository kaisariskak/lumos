import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/ibadat_group_settings.dart';

class IbadatGroupSettingsRepository {
  final SupabaseClient _client;

  IbadatGroupSettingsRepository(this._client);

  Future<IbadatGroupSettings?> getSettings(String groupId) async {
    final data = await _client
        .from('ibadat_group_settings')
        .select()
        .eq('group_id', groupId)
        .maybeSingle();
    if (data == null) return null;
    return IbadatGroupSettings.fromJson(data);
  }

  Future<IbadatGroupSettings> upsertSettings(
      IbadatGroupSettings settings) async {
    final data = await _client
        .from('ibadat_group_settings')
        .upsert(settings.toJson())
        .select()
        .single();
    return IbadatGroupSettings.fromJson(data);
  }
}
