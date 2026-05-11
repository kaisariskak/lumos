-- ============================================================
-- Migration: Discard auth user when invite registration fails
-- Date: 2026-05-12
-- ============================================================
-- Email/Google auth creates auth.users before the app can ask for nickname
-- and invite code. If invite validation fails, this function lets the client
-- delete only the current auth user, and only while no ibadat_profile exists.
-- ============================================================

CREATE OR REPLACE FUNCTION discard_unregistered_auth_user()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  v_user_id uuid := auth.uid();
BEGIN
  IF v_user_id IS NULL THEN
    RETURN;
  END IF;

  DELETE FROM auth.users u
   WHERE u.id = v_user_id
     AND NOT EXISTS (
       SELECT 1
         FROM public.ibadat_profiles p
        WHERE p.id = v_user_id
     );
END;
$$;

REVOKE ALL ON FUNCTION discard_unregistered_auth_user() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION discard_unregistered_auth_user() TO authenticated;
