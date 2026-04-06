import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/invite_code.dart';

class InviteCodeRepository {
  final SupabaseClient _client;

  InviteCodeRepository(this._client);

  static const _chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // no 0/O, 1/I

  String _generateCode(String prefix) {
    final random = Random.secure();
    final part = List.generate(
      6,
      (_) => _chars[random.nextInt(_chars.length)],
    ).join();
    return '$prefix-$part';
  }

  /// Super-admin generates an ADMIN invite code (valid for 30 days).
  Future<InviteCode> generateAdminCode({required String createdBy}) async {
    final code = _generateCode('ADM');
    final expiresAt = DateTime.now().add(const Duration(days: 30));
    final data = await _client
        .from('ibadat_invite_codes')
        .insert({
          'code': code,
          'role_type': 'ADMIN',
          'group_id': null,
          'is_used': false,
          'expires_at': expiresAt.toUtc().toIso8601String(),
          'created_by': createdBy,
        })
        .select()
        .single();
    return InviteCode.fromJson(data);
  }

  /// Admin generates a USER invite code for their group (valid for 30 days).
  Future<InviteCode> generateUserCode({
    required String groupId,
    required String createdBy,
  }) async {
    final code = _generateCode('USR');
    final expiresAt = DateTime.now().add(const Duration(days: 30));
    final data = await _client
        .from('ibadat_invite_codes')
        .insert({
          'code': code,
          'role_type': 'USER',
          'group_id': groupId,
          'is_used': false,
          'expires_at': expiresAt.toUtc().toIso8601String(),
          'created_by': createdBy,
        })
        .select()
        .single();
    return InviteCode.fromJson(data);
  }

  /// Validates a code string. Returns the InviteCode if found and valid,
  /// null if the code does not exist.
  /// Throws [InviteCodeExpiredException] or [InviteCodeUsedException] on errors.
  Future<InviteCode> validateCode(String code) async {
    final data = await _client
        .from('ibadat_invite_codes')
        .select()
        .eq('code', code.trim().toUpperCase())
        .maybeSingle();

    if (data == null) throw InviteCodeNotFoundException();

    final invite = InviteCode.fromJson(data);
    if (invite.isExpired) throw InviteCodeExpiredException();

    return invite;
  }

  /// Marks a code as used after successful activation.
  Future<void> markUsed(int id) async {
    await _client
        .from('ibadat_invite_codes')
        .update({'is_used': true})
        .eq('id', id);
  }

  /// Returns the latest active (not used, not expired) USER code for a group,
  /// or null if none exists.
  Future<InviteCode?> getActiveUserCode(String groupId) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final data = await _client
        .from('ibadat_invite_codes')
        .select()
        .eq('group_id', groupId)
        .eq('role_type', 'USER')
        .eq('is_used', false)
        .gt('expires_at', now)
        .order('expires_at', ascending: false)
        .limit(1)
        .maybeSingle();
    if (data == null) return null;
    return InviteCode.fromJson(data);
  }

  /// Returns ALL admin codes created by [createdBy], newest first.
  Future<List<InviteCode>> getAdminCodes(String createdBy) async {
    final data = await _client
        .from('ibadat_invite_codes')
        .select()
        .eq('created_by', createdBy)
        .eq('role_type', 'ADMIN')
        .order('expires_at', ascending: false);
    return (data as List).map((e) => InviteCode.fromJson(e)).toList();
  }

  /// Returns the latest active ADMIN code created by [createdBy],
  /// or null if none exists.
  Future<InviteCode?> getActiveAdminCode(String createdBy) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final data = await _client
        .from('ibadat_invite_codes')
        .select()
        .eq('created_by', createdBy)
        .eq('role_type', 'ADMIN')
        .eq('is_used', false)
        .gt('expires_at', now)
        .order('expires_at', ascending: false)
        .limit(1)
        .maybeSingle();
    if (data == null) return null;
    return InviteCode.fromJson(data);
  }

  /// Returns active USER code for group, auto-generating a new one if expired.
  Future<InviteCode> getOrCreateActiveUserCode({
    required String groupId,
    required String createdBy,
  }) async {
    final existing = await getActiveUserCode(groupId);
    if (existing != null) return existing;
    return generateUserCode(groupId: groupId, createdBy: createdBy);
  }

  /// Returns active ADMIN code, auto-generating a new one if expired.
  Future<InviteCode> getOrCreateActiveAdminCode({
    required String createdBy,
  }) async {
    final existing = await getActiveAdminCode(createdBy);
    if (existing != null) return existing;
    return generateAdminCode(createdBy: createdBy);
  }
}

// ── Exceptions ─────────────────────────────────────────────────────────────

class InviteCodeNotFoundException implements Exception {}

class InviteCodeExpiredException implements Exception {}

class InviteCodeUsedException implements Exception {}
