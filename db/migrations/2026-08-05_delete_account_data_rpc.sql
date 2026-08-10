-- 2026-08-05 Account deletion cleanup RPC.
-- Apply before deploying the delete-account Edge Function.

BEGIN;

CREATE OR REPLACE FUNCTION delete_account_data(p_user_id uuid) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_role text;
BEGIN
  IF p_user_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'code', 'no_session');
  END IF;

  SELECT role INTO v_role
  FROM ibadat_profiles
  WHERE id = p_user_id;

  IF v_role = 'super_admin' THEN
    RETURN jsonb_build_object('ok', false, 'code', 'super_admin_forbidden');
  END IF;

  IF EXISTS (
    SELECT 1
    FROM ibadat_groups
    WHERE admin_id = p_user_id
  ) THEN
    RETURN jsonb_build_object('ok', false, 'code', 'group_ownership_blocked');
  END IF;

  DELETE FROM report_metric_values
  WHERE report_id IN (
    SELECT id
    FROM ibadat_reports
    WHERE user_id = p_user_id
  );

  DELETE FROM ibadat_reports
  WHERE user_id = p_user_id;

  DELETE FROM ibadat_member_settings
  WHERE profile_id = p_user_id;

  DELETE FROM ibadat_payments
  WHERE profile_id = p_user_id;

  DELETE FROM ibadat_periods
  WHERE created_by = p_user_id
    AND is_personal = true;

  DELETE FROM group_metrics
  WHERE admin_id = p_user_id;

  UPDATE ibadat_invite_codes
  SET created_by = NULL
  WHERE created_by = p_user_id;

  UPDATE ibadat_groups
  SET financier_id = NULL
  WHERE financier_id = p_user_id;

  DELETE FROM ibadat_profiles
  WHERE id = p_user_id;

  RETURN jsonb_build_object('ok', true);
END;
$$;

REVOKE ALL ON FUNCTION delete_account_data(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION delete_account_data(uuid) TO service_role;

COMMIT;
