import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/ibadat_profile.dart';

class ProfileRepository {
  final SupabaseClient _client;

  ProfileRepository(this._client);

  Future<IbadatProfile?> getProfile(String userId) async {
    final data = await _client
        .from('ibadat_profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();
    if (data == null) return null;
    return IbadatProfile.fromJson(data);
  }

  Future<IbadatProfile?> getUserByEmail(String email) async {
    final data = await _client
        .from('ibadat_profiles')
        .select()
        .eq('email', email.trim().toLowerCase())
        .maybeSingle();
    if (data == null) return null;
    return IbadatProfile.fromJson(data);
  }

  Future<IbadatProfile> createProfile({
    required String id,
    required String displayName,
    required String email,
    String? avatarUrl,
    String? createdByAdminId,
    String? superAdminId,
    String role = 'user',
  }) async {
    final now = DateTime.now().toIso8601String();
    final data = await _client
        .from('ibadat_profiles')
        .insert({
          'id': id,
          'display_name': displayName,
          'email': email,
          'avatar_url': avatarUrl,
          'role': role,
          'created_by_admin_id': createdByAdminId,
          'super_admin_id': superAdminId,
          'created_at': now,
          'updated_at': now,
        })
        .select()
        .single();
    return IbadatProfile.fromJson(data);
  }

  Future<List<IbadatProfile>> getProfilesByGroup(String groupId) async {
    final data = await _client
        .from('ibadat_profiles')
        .select()
        .eq('current_group_id', groupId);
    return (data as List).map((e) => IbadatProfile.fromJson(e)).toList();
  }

  Future<void> updateCurrentGroup(String userId, String? groupId) async {
    await _client
        .from('ibadat_profiles')
        .update({'current_group_id': groupId, 'updated_at': DateTime.now().toIso8601String()})
        .eq('id', userId);
  }

  Future<void> updateRole(String userId, String role) async {
    await _client
        .from('ibadat_profiles')
        .update({'role': role, 'updated_at': DateTime.now().toIso8601String()})
        .eq('id', userId);
  }

  /// Set the super_admin_id on an admin user (called when super-admin creates an admin)
  Future<void> setSuperAdminId(String adminId, String superAdminId) async {
    await _client
        .from('ibadat_profiles')
        .update({'super_admin_id': superAdminId, 'updated_at': DateTime.now().toIso8601String()})
        .eq('id', adminId);
  }

  /// Set created_by_admin_id on a regular user (called when admin adds a user)
  Future<void> setCreatedByAdmin(String userId, String adminId) async {
    await _client
        .from('ibadat_profiles')
        .update({'created_by_admin_id': adminId, 'updated_at': DateTime.now().toIso8601String()})
        .eq('id', userId);
  }

  /// Get all admins created by a given super-admin
  Future<List<IbadatProfile>> getAdminsBySuperAdmin(String superAdminId) async {
    final data = await _client
        .from('ibadat_profiles')
        .select()
        .eq('super_admin_id', superAdminId)
        .eq('role', 'admin');
    return (data as List).map((e) => IbadatProfile.fromJson(e)).toList();
  }

  /// Get users who were removed from groups (current_group_id is null)
  /// and were originally added by one of the given admins
  Future<List<IbadatProfile>> getUngroupedUsersByAdminIds(List<String> adminIds) async {
    if (adminIds.isEmpty) return [];
    final data = await _client
        .from('ibadat_profiles')
        .select()
        .inFilter('created_by_admin_id', adminIds)
        .isFilter('current_group_id', null);
    return (data as List).map((e) => IbadatProfile.fromJson(e)).toList();
  }

  // ── Allowlist ───────────────────────────────────────────────────────────────

  Future<bool> isEmailAllowed(String email) async {
    final data = await _client
        .from('ibadat_allowlist')
        .select('email')
        .eq('email', email.trim().toLowerCase())
        .maybeSingle();
    return data != null;
  }

  Future<void> addToAllowlist(
    String email,
    String createdBy, {
    String? groupId,
    String targetRole = 'user',
  }) async {
    await _client.from('ibadat_allowlist').upsert({
      'email': email.trim().toLowerCase(),
      'created_by': createdBy,
      'group_id': groupId,
      'target_role': targetRole,
    });
  }

  Future<void> removeFromAllowlist(String email) async {
    await _client
        .from('ibadat_allowlist')
        .delete()
        .eq('email', email.trim().toLowerCase());
  }

  Future<List<String>> getAllowlist() async {
    final data = await _client
        .from('ibadat_allowlist')
        .select('email')
        .order('created_at', ascending: false);
    return (data as List).map((e) => e['email'] as String).toList();
  }

  /// Returns emails pre-registered for a specific group (not yet logged in)
  Future<List<String>> getAllowlistByGroup(String groupId) async {
    final data = await _client
        .from('ibadat_allowlist')
        .select('email')
        .eq('group_id', groupId)
        .order('created_at', ascending: false);
    return (data as List).map((e) => e['email'] as String).toList();
  }

  /// Returns the group_id stored in the allowlist for a given email
  Future<String?> getAllowlistGroupId(String email) async {
    final data = await _client
        .from('ibadat_allowlist')
        .select('group_id')
        .eq('email', email.trim().toLowerCase())
        .maybeSingle();
    return data?['group_id'] as String?;
  }

  /// Returns full allowlist entry data for a given email
  Future<Map<String, dynamic>?> getAllowlistEntry(String email) async {
    final data = await _client
        .from('ibadat_allowlist')
        .select('created_by, group_id, target_role')
        .eq('email', email.trim().toLowerCase())
        .maybeSingle();
    return data;
  }
}
