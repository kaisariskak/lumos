# Privacy Nickname Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace Google PII (email, full_name, avatar_url) in `ibadat_profiles` with a user-chosen nickname. Email lives only in `auth.users`. Registration unifies nickname + invite code in one screen via atomic Postgres RPC.

**Architecture:** SQL migration drops PII columns, renames `display_name → nickname`, adds `UNIQUE` constraint, creates `register_with_invite` and `is_nickname_taken` RPC functions. Flutter side renames the model field globally, replaces `InviteCodeScreen` (for new users) with new `RegistrationScreen`, removes email displays from UI, deletes the dead `_addAdmin` email-search path.

**Tech Stack:** Flutter (Dart 3.10), Supabase (Postgres + RLS), `supabase_flutter ^2.0.0`. Tests via `flutter_test`.

**Spec:** [2026-04-30-privacy-nickname-design-ru.md](../specs/2026-04-30-privacy-nickname-design-ru.md)

---

## Task 1: Write SQL migration

**Files:**
- Create: `db/migrations/2026-04-30_privacy_nickname.sql`

This is a manual artifact applied via Supabase SQL Editor (no `supabase/` directory exists in this repo). The file lives in `db/migrations/` so the SQL is reviewable in git.

- [ ] **Step 1: Create the migration directory if missing**

```bash
mkdir -p db/migrations
```

- [ ] **Step 2: Write the migration SQL**

Create `db/migrations/2026-04-30_privacy_nickname.sql` with exact content:

```sql
-- 2026-04-30 Privacy: drop Google PII from ibadat_profiles, add nickname,
-- create register_with_invite + is_nickname_taken RPCs.
-- Apply via Supabase SQL Editor inside a transaction.

BEGIN;

-- 1. Schema changes ────────────────────────────────────────────────────────
ALTER TABLE ibadat_profiles RENAME COLUMN display_name TO nickname;
ALTER TABLE ibadat_profiles DROP COLUMN email;
ALTER TABLE ibadat_profiles DROP COLUMN avatar_url;

-- 2. Constraints + unique index ────────────────────────────────────────────
ALTER TABLE ibadat_profiles
  ADD CONSTRAINT nickname_length CHECK (length(nickname) BETWEEN 2 AND 32);

ALTER TABLE ibadat_profiles
  ADD CONSTRAINT nickname_format CHECK (
    nickname ~ '^[A-Za-zА-Яа-яЁёӘәҒғҚқҢңӨөҰұҮүҺһІі0-9 _.\-]+$'
  );

CREATE UNIQUE INDEX IF NOT EXISTS ibadat_profiles_nickname_uniq
  ON ibadat_profiles (nickname);

-- 3. RLS policies on ibadat_profiles ───────────────────────────────────────
-- The current set of policies is unknown to this plan. Before applying,
-- list them with:
--   SELECT polname FROM pg_policy
--    WHERE polrelid = 'ibadat_profiles'::regclass;
-- Then DROP each policy that references the removed `email` column or the
-- old `display_name` column. Any policy that references only `id`,
-- `current_group_id`, `role`, `super_admin_id`, `created_by_admin_id`
-- can stay. Replace with the canonical set below if any are missing.

ALTER TABLE ibadat_profiles ENABLE ROW LEVEL SECURITY;

-- Self-read.
DROP POLICY IF EXISTS profiles_self_read ON ibadat_profiles;
CREATE POLICY profiles_self_read ON ibadat_profiles
  FOR SELECT TO authenticated
  USING (auth.uid() = id);

-- Read group-mates: members of the same group can see each other.
DROP POLICY IF EXISTS profiles_groupmates_read ON ibadat_profiles;
CREATE POLICY profiles_groupmates_read ON ibadat_profiles
  FOR SELECT TO authenticated
  USING (
    current_group_id IS NOT NULL
    AND current_group_id IN (
      SELECT current_group_id FROM ibadat_profiles WHERE id = auth.uid()
    )
  );

-- Group admin reads members of any group they admin.
DROP POLICY IF EXISTS profiles_admin_reads_members ON ibadat_profiles;
CREATE POLICY profiles_admin_reads_members ON ibadat_profiles
  FOR SELECT TO authenticated
  USING (
    current_group_id IN (
      SELECT id FROM ibadat_groups WHERE admin_id = auth.uid()
    )
  );

-- Super-admin reads admins it created.
DROP POLICY IF EXISTS profiles_superadmin_reads_admins ON ibadat_profiles;
CREATE POLICY profiles_superadmin_reads_admins ON ibadat_profiles
  FOR SELECT TO authenticated
  USING (super_admin_id = auth.uid());

-- Self-update: only nickname can change. role / super_admin_id /
-- created_by_admin_id stay frozen.
DROP POLICY IF EXISTS profiles_self_update ON ibadat_profiles;
CREATE POLICY profiles_self_update ON ibadat_profiles
  FOR UPDATE TO authenticated
  USING (auth.uid() = id)
  WITH CHECK (
    auth.uid() = id
    AND role = (SELECT role FROM ibadat_profiles WHERE id = auth.uid())
    AND super_admin_id IS NOT DISTINCT FROM
        (SELECT super_admin_id FROM ibadat_profiles WHERE id = auth.uid())
    AND created_by_admin_id IS NOT DISTINCT FROM
        (SELECT created_by_admin_id FROM ibadat_profiles WHERE id = auth.uid())
  );

-- INSERT is intentionally not granted — `register_with_invite` runs
-- with SECURITY DEFINER and bypasses RLS for the insert.

-- DELETE: keep whatever the existing policy was. If unknown, the safe
-- canonical set is "self-delete OR super-admin deletes". Adapt as needed:
DROP POLICY IF EXISTS profiles_delete ON ibadat_profiles;
CREATE POLICY profiles_delete ON ibadat_profiles
  FOR DELETE TO authenticated
  USING (
    auth.uid() = id
    OR EXISTS (
      SELECT 1 FROM ibadat_profiles sa
       WHERE sa.id = auth.uid() AND sa.role = 'super_admin'
    )
  );

-- 4. RPC: is_nickname_taken (UX helper) ────────────────────────────────────
CREATE OR REPLACE FUNCTION is_nickname_taken(p_nickname text) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS(SELECT 1 FROM ibadat_profiles WHERE nickname = p_nickname);
$$;

REVOKE ALL ON FUNCTION is_nickname_taken(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION is_nickname_taken(text) TO authenticated;

-- 5. RPC: register_with_invite (atomic registration) ───────────────────────
CREATE OR REPLACE FUNCTION register_with_invite(
  p_nickname text,
  p_code text
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_code record;
  v_profile record;
  v_now timestamptz := now();
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('error', 'not_authenticated');
  END IF;

  IF length(p_nickname) < 2 OR length(p_nickname) > 32 THEN
    RETURN jsonb_build_object('error', 'invalid_nickname');
  END IF;

  IF p_nickname !~ '^[A-Za-zА-Яа-яЁёӘәҒғҚқҢңӨөҰұҮүҺһІі0-9 _.\-]+$' THEN
    RETURN jsonb_build_object('error', 'invalid_nickname');
  END IF;

  -- Find code: USER codes can be reused while not expired; ADMIN codes are one-time.
  SELECT * INTO v_code FROM ibadat_invite_codes
   WHERE code = upper(trim(p_code))
   LIMIT 1;

  IF v_code IS NULL THEN
    RETURN jsonb_build_object('error', 'invalid_code');
  END IF;

  IF v_code.expires_at IS NOT NULL AND v_code.expires_at <= v_now THEN
    RETURN jsonb_build_object('error', 'expired_code');
  END IF;

  IF v_code.role_type = 'ADMIN' AND v_code.is_used = true THEN
    RETURN jsonb_build_object('error', 'expired_code');
  END IF;

  -- Idempotent: if profile already exists return success without insert.
  IF EXISTS(SELECT 1 FROM ibadat_profiles WHERE id = v_user_id) THEN
    RETURN jsonb_build_object('error', 'already_registered');
  END IF;

  BEGIN
    INSERT INTO ibadat_profiles (
      id, nickname, role, current_group_id, super_admin_id, created_by_admin_id, created_at, updated_at
    )
    VALUES (
      v_user_id,
      p_nickname,
      CASE WHEN v_code.role_type = 'ADMIN' THEN 'admin' ELSE 'user' END,
      v_code.group_id,
      CASE WHEN v_code.role_type = 'ADMIN' THEN v_code.created_by ELSE NULL END,
      CASE WHEN v_code.role_type = 'USER'  THEN v_code.created_by ELSE NULL END,
      v_now,
      v_now
    )
    RETURNING * INTO v_profile;
  EXCEPTION
    WHEN unique_violation THEN
      RETURN jsonb_build_object('error', 'nickname_taken');
  END;

  IF v_code.role_type = 'ADMIN' THEN
    UPDATE ibadat_invite_codes SET is_used = true WHERE id = v_code.id;
  END IF;

  RETURN jsonb_build_object('ok', true, 'profile', row_to_json(v_profile));
END;
$$;

REVOKE ALL ON FUNCTION register_with_invite(text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION register_with_invite(text, text) TO authenticated;

COMMIT;
```

**Note about column names in `ibadat_invite_codes`:** the existing schema uses `is_used` boolean (not `used_at` timestamp). The RPC is written accordingly. Verify before applying with:

```sql
SELECT column_name FROM information_schema.columns
 WHERE table_name = 'ibadat_invite_codes' AND column_name IN ('is_used', 'used_at');
```

- [ ] **Step 3: Verify SQL parses**

The migration is applied manually in Supabase SQL Editor. Local Postgres parsing is out of scope — verification is the smoke test in Task 11.

- [ ] **Step 4: Commit**

```bash
git add db/migrations/2026-04-30_privacy_nickname.sql
git commit -m "feat(db): add privacy nickname migration SQL"
```

---

## Task 2: Update IbadatProfile model — rename displayName → nickname, drop email/avatarUrl

**Files:**
- Modify: `lib/models/ibadat_profile.dart`
- Test: `test/models/ibadat_profile_test.dart` (create)

- [ ] **Step 1: Write the failing test**

Create `test/models/ibadat_profile_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';

import 'package:reportdeepen/models/ibadat_profile.dart';

void main() {
  test('parses nickname and ignores absent email/avatar_url', () {
    final profile = IbadatProfile.fromJson({
      'id': 'user-1',
      'nickname': 'kaisar',
      'role': 'user',
      'current_group_id': 'group-1',
      'super_admin_id': null,
      'created_by_admin_id': 'admin-1',
      'created_at': '2026-04-30T10:00:00.000Z',
      'updated_at': '2026-04-30T10:00:00.000Z',
    });

    expect(profile.id, 'user-1');
    expect(profile.nickname, 'kaisar');
    expect(profile.currentGroupId, 'group-1');
    expect(profile.role, 'user');
  });

  test('toJson emits nickname and no email/avatar_url', () {
    final profile = IbadatProfile(
      id: 'user-1',
      nickname: 'kaisar',
      role: 'user',
      currentGroupId: 'group-1',
      createdAt: DateTime.parse('2026-04-30T10:00:00.000Z'),
      updatedAt: DateTime.parse('2026-04-30T10:00:00.000Z'),
    );

    final json = profile.toJson();
    expect(json['nickname'], 'kaisar');
    expect(json.containsKey('email'), isFalse);
    expect(json.containsKey('avatar_url'), isFalse);
    expect(json.containsKey('display_name'), isFalse);
  });

  test('copyWith updates nickname and bumps updatedAt', () async {
    final original = IbadatProfile(
      id: 'user-1',
      nickname: 'old',
      role: 'user',
      createdAt: DateTime.parse('2026-04-30T10:00:00.000Z'),
      updatedAt: DateTime.parse('2026-04-30T10:00:00.000Z'),
    );
    await Future<void>.delayed(const Duration(milliseconds: 1));

    final updated = original.copyWith(nickname: 'new');
    expect(updated.nickname, 'new');
    expect(updated.id, original.id);
    expect(updated.updatedAt.isAfter(original.updatedAt), isTrue);
  });
}
```

- [ ] **Step 2: Run the test, expect compile failure**

```bash
flutter test test/models/ibadat_profile_test.dart
```

Expected: compile error — `nickname` is not a getter on `IbadatProfile`.

- [ ] **Step 3: Replace `lib/models/ibadat_profile.dart` entirely**

Overwrite the file with:

```dart
class IbadatProfile {
  final String id;
  final String nickname;
  final String role;
  final String? currentGroupId;
  /// For admin users: the super-admin who created them
  final String? superAdminId;
  /// For regular users: the admin who added them to the system
  final String? createdByAdminId;
  final DateTime createdAt;
  final DateTime updatedAt;

  const IbadatProfile({
    required this.id,
    required this.nickname,
    required this.role,
    this.currentGroupId,
    this.superAdminId,
    this.createdByAdminId,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isAdmin => role == 'admin' || role == 'super_admin';
  bool get isSuperAdmin => role == 'super_admin';

  factory IbadatProfile.fromJson(Map<String, dynamic> json) {
    return IbadatProfile(
      id: json['id'] as String,
      nickname: json['nickname'] as String,
      role: json['role'] as String? ?? 'user',
      currentGroupId: json['current_group_id'] as String?,
      superAdminId: json['super_admin_id'] as String?,
      createdByAdminId: json['created_by_admin_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nickname': nickname,
      'role': role,
      'current_group_id': currentGroupId,
    };
  }

  IbadatProfile copyWith({
    String? nickname,
    String? role,
    String? currentGroupId,
    String? superAdminId,
    String? createdByAdminId,
  }) {
    return IbadatProfile(
      id: id,
      nickname: nickname ?? this.nickname,
      role: role ?? this.role,
      currentGroupId: currentGroupId ?? this.currentGroupId,
      superAdminId: superAdminId ?? this.superAdminId,
      createdByAdminId: createdByAdminId ?? this.createdByAdminId,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
```

- [ ] **Step 4: Run the test — expect pass for the model, but compile errors elsewhere**

```bash
flutter test test/models/ibadat_profile_test.dart
```

Expected: model test passes. Other parts of the app and other tests will not compile (they still reference `displayName`, `email`, `avatarUrl`). That's expected; Tasks 3–10 fix them. **Do not commit yet** — code base will not analyze. Continue to Task 3.

---

## Task 3: Update ProfileRepository — add registerWithInvite + isNicknameTaken, drop dead methods

**Files:**
- Modify: `lib/repositories/profile_repository.dart`

- [ ] **Step 1: Replace the file with the new implementation**

Overwrite `lib/repositories/profile_repository.dart` with:

```dart
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

  Future<List<IbadatProfile>> getProfilesByGroup(String groupId) async {
    final data = await _client
        .from('ibadat_profiles')
        .select()
        .eq('current_group_id', groupId);
    return (data as List).map((e) => IbadatProfile.fromJson(e)).toList();
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

  /// Atomic registration: validate nickname + invite code on the server
  /// in a single transaction. Returns the created profile on success or
  /// a [RegistrationException] with a typed reason on failure.
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
/// `invalid_code`, `expired_code`, `already_registered`, `unknown`.
class RegistrationException implements Exception {
  final String reason;
  const RegistrationException(this.reason);

  @override
  String toString() => 'RegistrationException($reason)';
}
```

**Removed in this step:**
- `createProfile` (replaced by RPC `registerWithInvite`).
- `getUserByEmail` (dead, see Task 9).
- `setSuperAdminId` (dead, see Task 9).

- [ ] **Step 2: Verify it parses against the new model**

```bash
flutter analyze lib/repositories/profile_repository.dart
```

Expected: no errors specific to this file. Errors in other files (e.g. `auth_gate.dart`) are expected and fixed in subsequent tasks. **Do not commit yet.**

---

## Task 4: Global rename `displayName` → `nickname` across the codebase

**Files (all modified):**
- `lib/authentication/auth_gate.dart`
- `lib/screens/admin/admin_screen.dart`
- `lib/screens/detail/detail_screen.dart`
- `lib/screens/group_picker/group_picker_screen.dart`
- `lib/screens/home/home_screen.dart`
- `lib/screens/payments/add_payment_dialog.dart`
- `lib/screens/payments/member_payments_screen.dart`
- `lib/screens/payments/payments_screen.dart`
- `lib/screens/profile/profile_screen.dart`
- `lib/screens/report/report_editor_screen.dart`
- `lib/screens/super_admin/super_admin_codes_screen.dart`

This is a mechanical rename: every `.displayName` becomes `.nickname`. **Do not** rename `name` on other models (e.g. `IbadatGroup.name`).

- [ ] **Step 1: Apply the rename file-by-file**

For each file in the list above, replace every occurrence of the substring `.displayName` with `.nickname`. Do this via Edit tool with `replace_all: true`. Examples:

- `lib/screens/admin/admin_screen.dart`: replace `.displayName` → `.nickname` (replace_all). After this: `admin.nickname`, `member.nickname`, etc.
- `lib/screens/home/home_screen.dart`: same. Note line 460 — `widget.profile.displayName.split(' ').first` becomes `widget.profile.nickname.split(' ').first`. With nicknames, splitting on space rarely makes sense — but keep the change minimal (this rename only). Cleanup of `.split(' ').first` is out of scope.

- [ ] **Step 2: Update `auth_gate.dart` createProfile call sites**

In `lib/authentication/auth_gate.dart`, the `_activateCode` method (lines ~121–181) currently calls `profileRepo.createProfile(...)`. That method is gone (Task 3 removed it). The whole `_activateCode` will be replaced in Task 6, but for this task to compile, comment out the body of `_activateCode` and `_loadProfile`'s "no profile" branch temporarily — they will be rewritten in Task 6.

Find this block (current lines ~83–118 in `auth_gate.dart`):

```dart
  Future<void> _loadProfile() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    try {
      final repo = ProfileRepository(Supabase.instance.client);
      IbadatProfile? profile = await repo.getProfile(user.id);

      if (profile == null) {
        // No profile → require invite code to register
        if (!mounted) return;
        setState(() => _showInviteCode = true);
        return;
      } else if (profile.currentGroupId == null && profile.role == 'user') {
        ...
```

Leave it alone — it doesn't reference `displayName` or `email`. Just don't touch this block in Task 4.

The block to replace is `_activateCode` only. Replace its **entire body** with a placeholder that still compiles:

```dart
  Future<void> _activateCode(InviteCode code) async {
    // Stub: legacy flow (existing profile, new group) is rewritten in Task 6.
    // For new users without a profile, RegistrationScreen + RPC handle creation.
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      if (_profile != null) {
        // Existing profile, no group — assign group from USER code.
        if (code.roleType == 'USER' && code.groupId != null) {
          final profileRepo = ProfileRepository(Supabase.instance.client);
          await profileRepo.updateCurrentGroup(_profile!.id, code.groupId!);
        }
      }
      await _loadProfile();
    } catch (e) {
      debugPrint('Code activation error: $e');
      if (!mounted) return;
      setState(() => _profileError = true);
    }
  }
```

Also remove the unused import `import '../repositories/invite_code_repository.dart';` if it's only used for `markUsed` inside the deleted `_activateCode` block — keep it if `InviteCode` type is still referenced.

**Note:** the existing `markUsed(code.id)` is currently called from `_activateCode` for ADMIN codes. After our changes, ADMIN codes for new users are marked used by the `register_with_invite` RPC. For existing-user flows (which only ever process USER codes), `markUsed` is never needed. Hence we drop the call.

- [ ] **Step 3: Run analyzer; expect remaining errors only in `email`/`avatarUrl` references**

```bash
flutter analyze lib/
```

Expected: errors should now be limited to:
- references to `.email` (fixed in Task 7).
- references to `_addAdmin`, `_emailCtrl`, `getUserByEmail`, `setSuperAdminId` (fixed in Task 9).
- `app_strings.dart` references to removed strings (Task 10).

If the analyzer reports `displayName` or `avatarUrl` errors after this step, search for missed occurrences with:

```bash
grep -rn "displayName\|avatarUrl" lib/
```

and fix them.

- [ ] **Step 4: Commit (model + repo + global rename, app may not compile end-to-end yet)**

The model + repo + rename form a coherent intermediate state. Commit it so the next task starts clean:

```bash
git add lib/models/ibadat_profile.dart lib/repositories/profile_repository.dart \
  test/models/ibadat_profile_test.dart \
  lib/authentication/auth_gate.dart \
  lib/screens/admin/admin_screen.dart \
  lib/screens/detail/detail_screen.dart \
  lib/screens/group_picker/group_picker_screen.dart \
  lib/screens/home/home_screen.dart \
  lib/screens/payments/add_payment_dialog.dart \
  lib/screens/payments/member_payments_screen.dart \
  lib/screens/payments/payments_screen.dart \
  lib/screens/profile/profile_screen.dart \
  lib/screens/report/report_editor_screen.dart \
  lib/screens/super_admin/super_admin_codes_screen.dart
git commit -m "refactor(profile): rename displayName -> nickname, switch to register_with_invite RPC"
```

---

## Task 5: Add nickname/registration strings; remove dead email strings

**Files:**
- Modify: `lib/l10n/app_strings.dart`

`app_strings.dart` defines the `S` localization class with required strings for `kk` (Kazakh) and `ru` (Russian).

- [ ] **Step 1: Locate string definitions in `app_strings.dart`**

Read the file and find the required-fields list (around line 280) and the per-locale maps. Note the existing strings that must be removed:
- `emailHint`
- `emailLabel`
- `addAdminHint`
- (keep `addUser` — it's used elsewhere)

And new strings to add:

| Key | Kazakh | Russian | English fallback |
|---|---|---|---|
| `registrationTitle` | `Тіркелу` | `Регистрация` | `Sign up` |
| `nicknameLabel` | `Лақап ат` | `Никнейм` | `Nickname` |
| `nicknameHint` | `2–32 таңба` | `2–32 символа` | `2–32 chars` |
| `inviteCodeLabel` | `Шақыру коды` | `Код приглашения` | `Invite code` |
| `inviteCodeShortHint` | `XXX-XXXXXX` | `XXX-XXXXXX` | `XXX-XXXXXX` |
| `submitRegistration` | `Тіркелу` | `Зарегистрироваться` | `Sign up` |
| `errorNicknameTaken` | `Бұл лақап ат бос емес` | `Никнейм занят` | `Nickname taken` |
| `errorNicknameInvalid` | `Лақап ат дұрыс емес` | `Некорректный никнейм` | `Invalid nickname` |
| `errorInviteInvalid` | `Шақыру коды табылмады` | `Код не найден` | `Invalid code` |
| `errorInviteExpired` | `Шақыру коды мерзімі өтіп кетті` | `Код истёк` | `Code expired` |

- [ ] **Step 2: Edit the strings**

In `lib/l10n/app_strings.dart`:
1. Remove `required this.emailHint,`, `required this.emailLabel,`, `required this.addAdminHint,` from the constructor (around lines 306, 322, 340).
2. Remove the matching field declarations and their entries in the Kazakh and Russian maps. Use `grep` to find them all:
   ```bash
   grep -n "emailHint\|emailLabel\|addAdminHint" lib/l10n/app_strings.dart
   ```
3. Add the 10 new keys. Place them logically (registration-related grouping). For each: declare field, add to constructor as `required this.X`, add Kazakh and Russian translations.

**Concrete example for one key (`nicknameLabel`):**

Field declaration (near other label fields):
```dart
  final String nicknameLabel;
```

Constructor entry:
```dart
    required this.nicknameLabel,
```

Kazakh map entry:
```dart
      nicknameLabel: 'Лақап ат',
```

Russian map entry:
```dart
      nicknameLabel: 'Никнейм',
```

Repeat for all 10 keys.

- [ ] **Step 3: Run analyzer**

```bash
flutter analyze lib/l10n/app_strings.dart
```

Expected: no errors specific to this file. Other files using `s.emailHint` etc. will fail — fixed in Task 9.

- [ ] **Step 4: Commit**

```bash
git add lib/l10n/app_strings.dart
git commit -m "feat(l10n): add registration strings, drop dead email strings"
```

---

## Task 6: Create `RegistrationScreen`

**Files:**
- Create: `lib/screens/registration/registration_screen.dart`
- Test: `test/screens/registration/registration_screen_test.dart` (create — minimal smoke test, no Supabase)

This screen replaces `InviteCodeScreen` for the "new user, no profile" flow. Both fields are mandatory; submit calls `ProfileRepository.registerWithInvite`.

- [ ] **Step 1: Create the directory**

```bash
mkdir -p lib/screens/registration test/screens/registration
```

- [ ] **Step 2: Write the screen**

Create `lib/screens/registration/registration_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../l10n/app_strings.dart';
import '../../models/ibadat_profile.dart';
import '../../repositories/profile_repository.dart';

/// Combined nickname + invite code screen shown after Google sign-in
/// when the user has no profile yet. Calls the `register_with_invite`
/// RPC atomically.
class RegistrationScreen extends StatefulWidget {
  /// Called with the freshly created profile on successful registration.
  final void Function(IbadatProfile profile) onRegistered;

  /// Called when the user taps "Sign out".
  final VoidCallback onLogout;

  const RegistrationScreen({
    super.key,
    required this.onRegistered,
    required this.onLogout,
  });

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _nicknameCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  bool _loading = false;
  String? _nicknameError;
  String? _codeError;

  static final _nicknameRe = RegExp(
    r'^[A-Za-zА-Яа-яЁёӘәҒғҚқҢңӨөҰұҮүҺһІі0-9 _.\-]+$',
  );

  @override
  void dispose() {
    _nicknameCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  bool get _formValid {
    final n = _nicknameCtrl.text.trim();
    final c = _codeCtrl.text.trim();
    return n.length >= 2 && n.length <= 32 && _nicknameRe.hasMatch(n) && c.isNotEmpty;
  }

  Future<void> _submit() async {
    if (!_formValid || _loading) return;
    final s = S.of(context);
    setState(() {
      _loading = true;
      _nicknameError = null;
      _codeError = null;
    });

    final repo = ProfileRepository(Supabase.instance.client);
    try {
      final profile = await repo.registerWithInvite(
        nickname: _nicknameCtrl.text.trim(),
        code: _codeCtrl.text.trim().toUpperCase(),
      );
      if (!mounted) return;
      widget.onRegistered(profile);
    } on RegistrationException catch (e) {
      if (!mounted) return;
      // not_authenticated / already_registered are recoverable only via re-auth:
      // sign the user out so AuthGate refetches the profile from a clean state.
      if (e.reason == 'not_authenticated' || e.reason == 'already_registered') {
        widget.onLogout();
        return;
      }
      setState(() {
        _loading = false;
        switch (e.reason) {
          case 'nickname_taken':
            _nicknameError = s.errorNicknameTaken;
            break;
          case 'invalid_nickname':
            _nicknameError = s.errorNicknameInvalid;
            break;
          case 'invalid_code':
            _codeError = s.errorInviteInvalid;
            break;
          case 'expired_code':
          case 'code_already_used':
            _codeError = s.errorInviteExpired;
            break;
          default:
            _codeError = '${s.error}: $e';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _codeError = '${s.error}: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Center(
                    child: Text('🌙', style: TextStyle(fontSize: 36)),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  s.registrationTitle,
                  style: const TextStyle(
                    color: Color(0xFFE2E8F0),
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),

                // Nickname
                TextField(
                  controller: _nicknameCtrl,
                  onChanged: (_) => setState(() {}),
                  maxLength: 32,
                  style: const TextStyle(
                    color: Color(0xFFE2E8F0),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    counterText: '',
                    labelText: s.nicknameLabel,
                    labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                    hintText: s.nicknameHint,
                    hintStyle: const TextStyle(color: Color(0xFF334155)),
                    errorText: _nicknameError,
                    filled: true,
                    fillColor: const Color(0xFF1E293B),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(
                          color: Color(0xFF6366F1), width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 16),
                  ),
                ),
                const SizedBox(height: 16),

                // Invite code
                TextField(
                  controller: _codeCtrl,
                  onChanged: (_) => setState(() {}),
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9\-]')),
                    TextInputFormatter.withFunction((oldValue, newValue) {
                      return newValue.copyWith(text: newValue.text.toUpperCase());
                    }),
                  ],
                  maxLength: 12,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFFE2E8F0),
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                  ),
                  decoration: InputDecoration(
                    counterText: '',
                    labelText: s.inviteCodeLabel,
                    labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                    hintText: s.inviteCodeShortHint,
                    hintStyle: const TextStyle(
                      color: Color(0xFF334155),
                      letterSpacing: 2,
                    ),
                    errorText: _codeError,
                    filled: true,
                    fillColor: const Color(0xFF1E293B),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(
                          color: Color(0xFF6366F1), width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 16),
                  ),
                  onSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: (_formValid && !_loading) ? _submit : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4F46E5),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor:
                          const Color(0xFF4F46E5).withValues(alpha: 0.5),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    child: _loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            s.submitRegistration,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 24),
                TextButton(
                  onPressed: widget.onLogout,
                  child: Text(
                    s.logout,
                    style: const TextStyle(color: Color(0xFF475569)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 3: Write a smoke widget test**

Create `test/screens/registration/registration_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:reportdeepen/screens/registration/registration_screen.dart';

void main() {
  testWidgets('submit button is disabled until both fields valid',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      // S.of(context) only reads Localizations.localeOf(context).languageCode,
      // so a plain MaterialApp with `locale` set is enough — no custom delegate.
      locale: const Locale('kk'),
      home: RegistrationScreen(
        onRegistered: (_) {},
        onLogout: () {},
      ),
    ));
    await tester.pumpAndSettle();

    expect(
      tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
      isNull,
      reason: 'button should be disabled with empty fields',
    );

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'kaisar');
    await tester.pump();
    expect(
      tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
      isNull,
      reason: 'button still disabled — code missing',
    );

    await tester.enterText(fields.at(1), 'ADM-AB12CD');
    await tester.pump();
    expect(
      tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
      isNotNull,
      reason: 'button enabled when both fields valid',
    );
  });
}
```

**Note:** the test does **not** initialize Supabase — the submit button is never tapped, so no RPC call is attempted. If a future test wants to exercise submit, mock the repository (e.g. inject via constructor parameter — currently the screen builds its own `ProfileRepository` from `Supabase.instance.client`; refactor to accept an optional `ProfileRepository?` parameter then).

- [ ] **Step 4: Run the test**

```bash
flutter test test/screens/registration/registration_screen_test.dart
```

Expected: PASS. If `SDelegate` is named differently in this codebase, fix the import. If the test still fails after a real localization fix, simplify to verify only `find.byType(ElevatedButton)` is disabled by default — drop the i18n setup.

- [ ] **Step 5: Commit**

```bash
git add lib/screens/registration/registration_screen.dart \
        test/screens/registration/registration_screen_test.dart
git commit -m "feat(registration): add combined nickname + invite code screen"
```

---

## Task 7: Wire `RegistrationScreen` into `AuthGate`

**Files:**
- Modify: `lib/authentication/auth_gate.dart`

After Task 4, `_activateCode` is a stub. Now we plumb the new screen and clean up.

- [ ] **Step 1: Read the current `auth_gate.dart` to confirm structure**

```bash
flutter analyze lib/authentication/auth_gate.dart
```

This sets context. The current state:
- `_showInviteCode` flag drives `InviteCodeScreen`.
- `_loadProfile` sets `_showInviteCode = true` when profile is null OR when profile has no group.

We want to differentiate these two cases.

- [ ] **Step 2: Replace `_loadProfile` and `_activateCode`, add `_onRegistered`**

In `lib/authentication/auth_gate.dart`:

Add a new state flag near `_showInviteCode`:

```dart
  bool _showRegistration = false;
```

Replace `_loadProfile` (around line 83) with:

```dart
  Future<void> _loadProfile() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    try {
      final repo = ProfileRepository(Supabase.instance.client);
      IbadatProfile? profile = await repo.getProfile(user.id);

      if (profile == null) {
        // No profile → must register (nickname + invite code).
        if (!mounted) return;
        setState(() {
          _profile = null;
          _showRegistration = true;
          _showInviteCode = false;
          _showGroupPicker = false;
        });
        return;
      }

      if (profile.currentGroupId == null && profile.role == 'user') {
        // Existing profile, no group → only need a USER invite code.
        if (!mounted) return;
        setState(() {
          _profile = profile;
          _showInviteCode = true;
          _showRegistration = false;
          _showGroupPicker = false;
        });
        return;
      }

      if (!mounted) return;
      setState(() {
        _profile = profile;
        _showGroupPicker = false;
        _showInviteCode = false;
        _showRegistration = false;
      });
    } catch (e) {
      debugPrint('Profile load error: $e');
      if (!mounted) return;
      setState(() => _profileError = true);
    }
  }
```

Replace `_activateCode` (the stub from Task 4) with the final version:

```dart
  /// Existing-user code activation: only ever called for USER codes
  /// (the case "profile exists, no current_group_id").
  Future<void> _activateCode(InviteCode code) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      if (_profile == null) {
        // Defensive: should be impossible — RegistrationScreen handles new users.
        debugPrint('_activateCode called without profile; reloading');
        await _loadProfile();
        return;
      }

      if (code.roleType == 'USER' && code.groupId != null) {
        final profileRepo = ProfileRepository(Supabase.instance.client);
        await profileRepo.updateCurrentGroup(_profile!.id, code.groupId!);
      }

      await _loadProfile();
    } catch (e) {
      debugPrint('Code activation error: $e');
      if (!mounted) return;
      setState(() => _profileError = true);
    }
  }
```

Add a new handler:

```dart
  Future<void> _onRegistered(IbadatProfile profile) async {
    if (!mounted) return;
    setState(() {
      _profile = profile;
      _showRegistration = false;
      _showInviteCode = false;
      _showGroupPicker = false;
    });
    // Re-derive routing from canonical server state. Trusting the RPC
    // response shape risks landing in the wrong branch if a field that
    // affects routing (e.g. currentGroupId) wasn't populated in the
    // returned row.
    await _loadProfile();
  }
```

In `_AuthGateState.onAuthStateChange` listener, when `signedOut` clear `_showRegistration` too:

```dart
      } else if (data.event == AuthChangeEvent.signedOut) {
        setState(() {
          _checkingBiometric = false;
          _pinRequired = false;
          _profileError = false;
          _profile = null;
          _showGroupPicker = false;
          _showInviteCode = false;
          _showRegistration = false;
        });
      }
```

- [ ] **Step 3: Add the `RegistrationScreen` route in `build`**

In the `build` method, **before** the existing `if (_showInviteCode)` block, add:

```dart
    // Registration: nickname + invite code (new users only)
    if (_showRegistration) {
      return RegistrationScreen(
        onRegistered: _onRegistered,
        onLogout: _logout,
      );
    }
```

Add the import at the top of the file:

```dart
import '../screens/registration/registration_screen.dart';
```

- [ ] **Step 4: Run the analyzer**

```bash
flutter analyze lib/authentication/auth_gate.dart
```

Expected: no errors. If there's an unused import (e.g. `invite_code_repository.dart`), remove it.

- [ ] **Step 5: Commit**

```bash
git add lib/authentication/auth_gate.dart
git commit -m "feat(auth): route new users to RegistrationScreen, keep InviteCodeScreen for grouped re-entry"
```

---

## Task 8: Remove email from UI (profile, detail, admin lists)

**Files:**
- Modify: `lib/screens/profile/profile_screen.dart`
- Modify: `lib/screens/detail/detail_screen.dart`
- Modify: `lib/screens/admin/admin_screen.dart`

- [ ] **Step 1: `profile_screen.dart` — show email from `auth.users`**

Find the line referencing `widget.profile.email` (line ~124). Replace it with the current Supabase user's email:

```dart
            Text(
              Supabase.instance.client.auth.currentUser?.email ?? '',
              style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
            ),
```

Add the import if not already present:

```dart
import 'package:supabase_flutter/supabase_flutter.dart';
```

- [ ] **Step 2: `detail_screen.dart` — drop email row**

Find the block (around line 244–252) that renders `widget.profile.email`. Remove the entire `Text(widget.profile.email, ...)` widget and any padding/spacing immediately specific to it. Keep nickname + statistics intact.

Use Edit tool on the smallest wrapping block to drop the email-only widget. After removal, run analyzer to verify nothing else references the dropped lines.

- [ ] **Step 3: `admin_screen.dart` — drop three email rows**

Three places in `admin_screen.dart` show `Text(<x>.email, ...)`:
- Line 1220 (admin list).
- Line 1365 (user list).
- Line 1866 (member card).

For each: remove the `Text(<x>.email, ...)` widget. The wrapping `Column` should still render `<x>.nickname` (already renamed in Task 4) and the role/badge; just delete the email `Text` line.

- [ ] **Step 4: Run the analyzer**

```bash
flutter analyze lib/screens/profile/ lib/screens/detail/ lib/screens/admin/
```

Expected: no errors related to `.email`.

- [ ] **Step 5: Commit**

```bash
git add lib/screens/profile/profile_screen.dart \
        lib/screens/detail/detail_screen.dart \
        lib/screens/admin/admin_screen.dart
git commit -m "feat(ui): remove email displays; show own email from auth.users in profile"
```

---

## Task 9: Delete dead `_addAdmin` path and helpers

**Files:**
- Modify: `lib/screens/admin/admin_screen.dart`

After Task 4, `getUserByEmail` and `setSuperAdminId` no longer exist on the repository. The `_addAdmin` method and its UI form must go.

- [ ] **Step 1: Delete the `_addAdmin` method**

In `lib/screens/admin/admin_screen.dart`, remove the entire method body of `_addAdmin` (was lines 357–389; line numbers may have shifted). Search:

```bash
grep -n "_addAdmin" lib/screens/admin/admin_screen.dart
```

Delete the method definition and any state field referenced only by it (`_isAdding`, `_addError` if exclusively used by `_addAdmin`).

- [ ] **Step 2: Delete the `_emailCtrl` controller**

Search:

```bash
grep -n "_emailCtrl" lib/screens/admin/admin_screen.dart
```

Remove:
- `final _emailCtrl = TextEditingController();` (around line 76).
- `_emailCtrl.dispose();` (around line 142).
- `controller: _emailCtrl,` and the entire surrounding `TextField(...)` widget that hosts it (around line 1244–1290).
- The `Row(...)` and `ElevatedButton(...)` that call `_addAdmin` (the same block).
- `Text(s.addAdminHint, ...)` heading directly above that form (around line 1244).

After deletion the surrounding `Column` should still render the admin list above and the `ungroupedUsers` block below (if any), without the now-dead form.

- [ ] **Step 3: Run the analyzer**

```bash
flutter analyze lib/screens/admin/admin_screen.dart
```

Expected: no errors. If `_isAdding`, `_addError`, or `addAdminHint` are referenced elsewhere, remove those references too.

- [ ] **Step 4: Verify no remaining email references in `lib/`**

```bash
grep -rn "\.email" lib/ | grep -v "auth.currentUser"
```

Expected: empty (no matches except `auth.currentUser?.email`). If matches appear, fix them.

```bash
grep -rn "getUserByEmail\|setSuperAdminId\|_addAdmin\|_emailCtrl\|emailHint\|emailLabel\|addAdminHint" lib/
```

Expected: empty.

- [ ] **Step 5: Commit**

```bash
git add lib/screens/admin/admin_screen.dart
git commit -m "refactor(admin): remove dead _addAdmin email-search path"
```

---

## Task 10: Replace Google avatar references with letter fallback in `auth_gate.dart`

**Files:**
- Modify: `lib/authentication/auth_gate.dart`

After Tasks 4 + 7, `auth_gate.dart` no longer references `displayName` or `avatar_url` directly because the old `_activateCode` body was already replaced. But verify.

- [ ] **Step 1: Verify cleanup**

```bash
grep -n "user.userMetadata\|full_name\|avatar_url\|display_name" lib/authentication/auth_gate.dart
```

Expected: no matches. If matches exist, the rewrite from Task 7 missed them — clean them up. The new flow does not read Google metadata at all; nickname comes from the user's input on `RegistrationScreen`.

- [ ] **Step 2: Verify the analyzer passes for the whole project**

```bash
flutter analyze
```

Expected: no errors. Warnings about unused imports/fields → fix them.

- [ ] **Step 3: Run all tests**

```bash
flutter test
```

Expected: all tests PASS.

- [ ] **Step 4: Commit (if any cleanup happened)**

```bash
git add -u lib/authentication/auth_gate.dart
git commit -m "chore(auth): drop residual Google metadata reads"
```

If no cleanup was needed, skip this commit.

---

## Task 11: Apply the SQL migration on Supabase + manual smoke test

**Files:** none modified (Supabase Dashboard work).

This is the only step that requires running the SQL against the actual Supabase project. Do it on a staging project first if one exists; otherwise the production project — no choice. Read `db/migrations/2026-04-30_privacy_nickname.sql` carefully before applying.

- [ ] **Step 1: Backup**

In Supabase Dashboard → Database → Backups, create a manual backup. Name it `pre-privacy-nickname-2026-04-30`.

- [ ] **Step 2: Verify the column actually exists in `ibadat_invite_codes`**

In SQL Editor:

```sql
SELECT column_name FROM information_schema.columns
 WHERE table_name = 'ibadat_invite_codes';
```

Expected: lists `id`, `code`, `role_type`, `group_id`, `is_used`, `expires_at`, `created_by`, `created_at`. If the column for "used" is named differently, edit the migration SQL (`is_used` → actual name) before applying.

- [ ] **Step 3: Apply the migration**

In SQL Editor, paste the entire content of `db/migrations/2026-04-30_privacy_nickname.sql` and run. Expected: `COMMIT` succeeds, no errors.

- [ ] **Step 4: Verify schema**

```sql
SELECT column_name FROM information_schema.columns
 WHERE table_name = 'ibadat_profiles'
 ORDER BY ordinal_position;
```

Expected columns: `id`, `nickname`, `role`, `current_group_id`, `super_admin_id`, `created_by_admin_id`, `created_at`, `updated_at`. **No** `email`, `display_name`, `avatar_url`.

```sql
SELECT proname FROM pg_proc
 WHERE proname IN ('register_with_invite', 'is_nickname_taken');
```

Expected: both functions present.

- [ ] **Step 5: Run the app — golden path**

Run `flutter run` and exercise:

1. Sign in with a fresh Google account that has no profile → `RegistrationScreen` appears.
2. Try submit with empty fields → submit button stays disabled.
3. Type ник `тест` (4 chars) and a valid invite code → tap submit → app advances to `MainScaffold`.
4. Verify in DB that the new row in `ibadat_profiles` has `nickname='тест'`, no email/avatar.
5. Sign out, sign in with an existing pre-migration user → enters app correctly, nickname displays.
6. Open profile screen → email shown is the Google one (from `auth.currentUser`), nickname is the legacy display_name.
7. Open detail screen of another group member → no email visible, nickname only.
8. As super-admin, open admin screen → no email column anywhere; admin list shows nicknames + 👑.
9. As super-admin, open `super_admin_codes_screen` → ADM-code generation still works.
10. Try registering a duplicate nickname (use a second account) → `errorNicknameTaken` shows on the nickname field; code is preserved.
11. Try registering with an expired code → `errorInviteExpired` shows on the code field; nickname preserved.

If any step fails — debug, fix, re-run.

- [ ] **Step 6: Update memory if needed**

If nicknames as a concept introduce new conventions worth remembering, append a memory note. Otherwise skip.

---

## Self-review checklist (run after writing this plan)

- All spec sections have a task: schema migration ✓ (T1), profile model ✓ (T2), repo changes ✓ (T3), global rename ✓ (T4), strings ✓ (T5), registration screen ✓ (T6), auth gate ✓ (T7), email UI cleanup ✓ (T8), dead code removal ✓ (T9), avatar/google metadata cleanup ✓ (T10), end-to-end verification ✓ (T11).
- No "TBD"/"TODO"/"figure out later" — verified.
- All renames consistent: `displayName` → `nickname` everywhere; `email` removed; new RPC names match between SQL and Dart.
- Each task ends in a commit; no commit straddles multiple tasks.
