-- ============================================================
-- Migration: Repair report RLS after legacy membership schema removal
-- Date: 2026-05-11
-- ============================================================
-- The Flutter app uses ibadat_profiles.current_group_id and ibadat_groups.admin_id
-- as the source of truth for membership/access. Reinstall report-related RLS
-- policies so stale database-side policies from older schemas cannot break
-- report save/read flows.
-- ============================================================

ALTER TABLE ibadat_reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE report_metric_values ENABLE ROW LEVEL SECURITY;

DO $$
DECLARE
  policy_name TEXT;
BEGIN
  FOR policy_name IN
    SELECT policyname
      FROM pg_policies
     WHERE schemaname = 'public'
       AND tablename = 'ibadat_reports'
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.ibadat_reports', policy_name);
  END LOOP;

  FOR policy_name IN
    SELECT policyname
      FROM pg_policies
     WHERE schemaname = 'public'
       AND tablename = 'report_metric_values'
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.report_metric_values', policy_name);
  END LOOP;
END $$;

-- ----------------------------------------------------------------
-- ibadat_reports
-- ----------------------------------------------------------------

CREATE POLICY "Users can read accessible reports"
  ON ibadat_reports FOR SELECT
  USING (
    user_id = auth.uid()
    OR EXISTS (
      SELECT 1
      FROM ibadat_profiles p
      WHERE p.id = auth.uid()
        AND p.role IN ('admin', 'super_admin')
        AND p.current_group_id = group_id
    )
    OR EXISTS (
      SELECT 1
      FROM ibadat_groups g
      WHERE g.id = group_id
        AND g.admin_id = auth.uid()
    )
  );

CREATE POLICY "Users can insert their accessible reports"
  ON ibadat_reports FOR INSERT
  WITH CHECK (
    user_id = auth.uid()
    AND (
      (
        group_id IS NULL
        AND EXISTS (
          SELECT 1
          FROM ibadat_profiles p
          WHERE p.id = auth.uid()
            AND p.role IN ('admin', 'super_admin')
        )
      )
      OR (
        group_id IS NOT NULL
        AND (
          EXISTS (
            SELECT 1
            FROM ibadat_profiles p
            WHERE p.id = auth.uid()
              AND p.current_group_id = group_id
          )
          OR EXISTS (
            SELECT 1
            FROM ibadat_groups g
            WHERE g.id = group_id
              AND g.admin_id = auth.uid()
          )
        )
      )
    )
  );

CREATE POLICY "Users can update accessible reports"
  ON ibadat_reports FOR UPDATE
  USING (
    user_id = auth.uid()
    OR EXISTS (
      SELECT 1
      FROM ibadat_groups g
      WHERE g.id = group_id
        AND g.admin_id = auth.uid()
    )
  )
  WITH CHECK (
    user_id = auth.uid()
    AND (
      group_id IS NULL
      OR EXISTS (
        SELECT 1
        FROM ibadat_profiles p
        WHERE p.id = auth.uid()
          AND p.current_group_id = group_id
      )
      OR EXISTS (
        SELECT 1
        FROM ibadat_groups g
        WHERE g.id = group_id
          AND g.admin_id = auth.uid()
      )
    )
  );

CREATE POLICY "Users can delete accessible reports"
  ON ibadat_reports FOR DELETE
  USING (
    user_id = auth.uid()
    OR EXISTS (
      SELECT 1
      FROM ibadat_groups g
      WHERE g.id = group_id
        AND g.admin_id = auth.uid()
    )
  );

-- ----------------------------------------------------------------
-- report_metric_values
-- ----------------------------------------------------------------

CREATE POLICY "Users can read accessible report metric values"
  ON report_metric_values FOR SELECT
  USING (
    EXISTS (
      SELECT 1
      FROM ibadat_reports r
      LEFT JOIN ibadat_profiles p ON p.id = auth.uid()
      WHERE r.id = report_id
        AND (
          r.user_id = auth.uid()
          OR (
            p.role IN ('admin', 'super_admin')
            AND p.current_group_id = r.group_id
          )
          OR EXISTS (
            SELECT 1
            FROM ibadat_groups g
            WHERE g.id = r.group_id
              AND g.admin_id = auth.uid()
          )
        )
    )
  );

CREATE POLICY "Users can insert accessible report metric values"
  ON report_metric_values FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM ibadat_reports r
      WHERE r.id = report_id
        AND (
          r.user_id = auth.uid()
          OR EXISTS (
            SELECT 1
            FROM ibadat_groups g
            WHERE g.id = r.group_id
              AND g.admin_id = auth.uid()
          )
        )
    )
  );

CREATE POLICY "Users can update accessible report metric values"
  ON report_metric_values FOR UPDATE
  USING (
    EXISTS (
      SELECT 1
      FROM ibadat_reports r
      WHERE r.id = report_id
        AND (
          r.user_id = auth.uid()
          OR EXISTS (
            SELECT 1
            FROM ibadat_groups g
            WHERE g.id = r.group_id
              AND g.admin_id = auth.uid()
          )
        )
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM ibadat_reports r
      WHERE r.id = report_id
        AND (
          r.user_id = auth.uid()
          OR EXISTS (
            SELECT 1
            FROM ibadat_groups g
            WHERE g.id = r.group_id
              AND g.admin_id = auth.uid()
          )
        )
    )
  );

CREATE POLICY "Users can delete accessible report metric values"
  ON report_metric_values FOR DELETE
  USING (
    EXISTS (
      SELECT 1
      FROM ibadat_reports r
      WHERE r.id = report_id
        AND (
          r.user_id = auth.uid()
          OR EXISTS (
            SELECT 1
            FROM ibadat_groups g
            WHERE g.id = r.group_id
              AND g.admin_id = auth.uid()
          )
        )
    )
  );
