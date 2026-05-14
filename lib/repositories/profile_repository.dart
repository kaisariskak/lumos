import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/ibadat_profile.dart';
import '../utils/perf_log.dart';

class ProfileRepository {
  final SupabaseClient _client;

  ProfileRepository(this._client);

  Future<IbadatProfile?> getProfile(String userId) async {
    return traceAsync('ProfileRepository.getProfile', () async {
      final data = await _client
          .from('ibadat_profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();
      if (data == null) return null;
      return IbadatProfile.fromJson(data);
    }, describeResult: (profile) => 'found=${profile != null}');
  }

  Future<List<IbadatProfile>> getProfilesByGroup(String groupId) async {
    return traceAsync(
      'ProfileRepository.getProfilesByGroup',
      () async {
        final data = await _client
            .from('ibadat_profiles')
            .select()
            .eq('current_group_id', groupId);
        return (data as List).map((e) => IbadatProfile.fromJson(e)).toList();
      },
      describeResult: (profiles) => 'rows=${profiles.length}',
    );
  }

  Future<void> updateCurrentGroup(String userId, String? groupId) async {
    final data = await _client
        .from('ibadat_profiles')
        .update({'current_group_id': groupId, 'updated_at': DateTime.now().toIso8601String()})
        .eq('id', userId)
        .select();
    if ((data as List).isEmpty) {
      throw StateError(
        'updateCurrentGroup: no row updated for user $userId '
        '(RLS rejected UPDATE or the profile was deleted).',
      );
    }
  }

  Future<void> updateRole(String userId, String role) async {
    await _client
        .from('ibadat_profiles')
        .update({'role': role, 'updated_at': DateTime.now().toIso8601String()})
        .eq('id', userId);
  }

  Future<void> updateNickname(String userId, String nickname) async {
    await _client
        .from('ibadat_profiles')
        .update({'nickname': nickname, 'updated_at': DateTime.now().toIso8601String()})
        .eq('id', userId);
  }

  /// Physically delete a profile (only when member has no payments)
  Future<void> deleteProfile(String userId) async {
    await _client.from('ibadat_profiles').delete().eq('id', userId);
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
    return traceAsync(
      'ProfileRepository.getAdminsBySuperAdmin',
      () async {
        final data = await _client
            .from('ibadat_profiles')
            .select()
            .eq('super_admin_id', superAdminId)
            .eq('role', 'admin');
        return (data as List).map((e) => IbadatProfile.fromJson(e)).toList();
      },
      describeResult: (profiles) => 'rows=${profiles.length}',
    );
  }

  /// Get users who were removed from groups (current_group_id is null)
  /// and were originally added by one of the given admins
  Future<List<IbadatProfile>> getUngroupedUsersByAdminIds(List<String> adminIds) async {
    if (adminIds.isEmpty) return [];
    return traceAsync(
      'ProfileRepository.getUngroupedUsersByAdminIds',
      () async {
        final data = await _client
            .from('ibadat_profiles')
            .select()
            .inFilter('created_by_admin_id', adminIds)
            .isFilter('current_group_id', null);
        return (data as List).map((e) => IbadatProfile.fromJson(e)).toList();
      },
      describeResult: (profiles) => 'rows=${profiles.length}',
    );
  }

  /// Atomic registration: validate nickname + invite code on the server
  /// in a single transaction. Returns the created profile on success or
  /// throws [RegistrationException] with a typed reason on failure.
  Future<void> preflightRegistration({
    required String nickname,
    required String code,
  }) async {
    final result = await _client.rpc('preflight_register_with_invite', params: {
      'p_nickname': nickname,
      'p_code': code,
    });
    final map = (result as Map).cast<String, dynamic>();
    if (map['ok'] == true) return;
    throw RegistrationException(map['error']?.toString() ?? 'unknown');
  }

  Future<IbadatProfile> registerWithInvite({
    required String nickname,
    required String code,
  }) async {
    final result = await _client.rpc('register_with_invite', params: {
      'p_nickname': nickname,
      'p_code': code,
    });
    final map = (result as Map).cast<String, dynamic>();
    if (map['ok'] == true) {
      final profileJson = (map['profile'] as Map).cast<String, dynamic>();
      return IbadatProfile.fromJson(profileJson);
    }
    throw RegistrationException(map['error']?.toString() ?? 'unknown');
  }

  /// UX helper — true when [nickname] already taken. Used for live validation
  /// Deletes the current auth user only if no ibadat_profile exists for it.
  /// Used to roll back email/Google auth when invite validation fails.
  Future<void> discardUnregisteredAuthUser() async {
    await _client.rpc('discard_unregistered_auth_user');
  }

  /// UX helper - true when [nickname] already taken. Used for live validation
  /// on the registration screen.
  Future<bool> isNicknameTaken(String nickname) async {
    final result = await _client.rpc('is_nickname_taken', params: {
      'p_nickname': nickname,
    });
    return result as bool;
  }
}

/// Reason returned by [register_with_invite] RPC. One of:
/// `not_authenticated`, `invalid_nickname`, `nickname_taken`,
/// `invalid_code`, `expired_code`, `code_already_used`,
/// `already_registered`, `unknown`.
class RegistrationException implements Exception {
  final String reason;
  const RegistrationException(this.reason);

  @override
  String toString() => 'RegistrationException($reason)';
}
