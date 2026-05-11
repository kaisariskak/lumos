-- ============================================================
-- Migration: Preflight invite validation before auth sign-up
-- Date: 2026-05-12
-- ============================================================
-- Username/password registration must not create auth.users rows when the
-- invite code or nickname is invalid. This RPC is callable by anon before
-- Supabase Auth signUp and mirrors the validation part of register_with_invite.
-- ============================================================

CREATE OR REPLACE FUNCTION preflight_register_with_invite(
  p_nickname text,
  p_code text
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_code record;
  v_now timestamptz := now();
BEGIN
  p_nickname := trim(p_nickname);

  IF length(p_nickname) < 2 OR length(p_nickname) > 32 THEN
    RETURN jsonb_build_object('error', 'invalid_nickname');
  END IF;

  IF p_nickname !~ '^[A-Za-zА-Яа-яЁёӘәҒғҚқҢңӨөҰұҮүҺһІі0-9 _.-]+$' THEN
    RETURN jsonb_build_object('error', 'invalid_nickname');
  END IF;

  IF EXISTS(SELECT 1 FROM ibadat_profiles WHERE nickname = p_nickname) THEN
    RETURN jsonb_build_object('error', 'nickname_taken');
  END IF;

  SELECT * INTO v_code
    FROM ibadat_invite_codes
   WHERE code = upper(trim(p_code))
   LIMIT 1;

  IF v_code IS NULL THEN
    RETURN jsonb_build_object('error', 'invalid_code');
  END IF;

  IF v_code.expires_at IS NOT NULL AND v_code.expires_at <= v_now THEN
    RETURN jsonb_build_object('error', 'expired_code');
  END IF;

  IF v_code.role_type = 'ADMIN' AND v_code.is_used = true THEN
    RETURN jsonb_build_object('error', 'code_already_used');
  END IF;

  RETURN jsonb_build_object('ok', true);
END;
$$;

REVOKE ALL ON FUNCTION preflight_register_with_invite(text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION preflight_register_with_invite(text, text) TO anon;
GRANT EXECUTE ON FUNCTION preflight_register_with_invite(text, text) TO authenticated;
