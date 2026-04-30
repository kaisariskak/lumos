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
