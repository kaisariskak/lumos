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

  UPDATE ibadat_payments
  SET created_by = NULL
  WHERE created_by = p_user_id;

  DELETE FROM ibadat_periods
  WHERE created_by = p_user_id
    AND is_personal = true;

  -- Group periods are shared data. Keep them and transfer their creator
  -- reference to the group's current administrator.
  UPDATE ibadat_periods AS period
  SET created_by = groups.admin_id
  FROM ibadat_groups AS groups
  WHERE period.created_by = p_user_id
    AND period.is_personal = false
    AND period.group_id = groups.id;

  DELETE FROM group_metrics
  WHERE admin_id = p_user_id;

  UPDATE ibadat_invite_codes
  SET created_by = NULL
  WHERE created_by = p_user_id;

  UPDATE ibadat_groups
  SET financier_id = NULL
  WHERE financier_id = p_user_id;

  -- Preserve admin scoping for members of transferred groups. Ungrouped
  -- profiles have no unambiguous successor and must simply release the FK.
  UPDATE ibadat_profiles AS profile
  SET created_by_admin_id = groups.admin_id
  FROM ibadat_groups AS groups
  WHERE profile.created_by_admin_id = p_user_id
    AND profile.current_group_id = groups.id;

  UPDATE ibadat_profiles
  SET created_by_admin_id = NULL
  WHERE created_by_admin_id = p_user_id;

  DELETE FROM ibadat_profiles
  WHERE id = p_user_id;

  RETURN jsonb_build_object('ok', true);
END;
$$;

REVOKE ALL ON FUNCTION delete_account_data(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION delete_account_data(uuid) TO service_role;

COMMIT;
