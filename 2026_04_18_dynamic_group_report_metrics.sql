-- ============================================================
-- Migration: Dynamic group metrics and report values
-- Run this in Supabase SQL Editor
-- ============================================================

CREATE TABLE IF NOT EXISTS group_metrics (
    id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
    group_id UUID NOT NULL REFERENCES ibadat_groups(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    icon TEXT NOT NULL,
    color_value INTEGER NOT NULL,
    unit TEXT NOT NULL,
    max_value INTEGER NOT NULL,
    order_index INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_group_metrics_group_id
    ON group_metrics (group_id, order_index);

CREATE TABLE IF NOT EXISTS report_metric_values (
    report_id UUID NOT NULL REFERENCES ibadat_reports(id) ON DELETE CASCADE,
    metric_id TEXT NOT NULL REFERENCES group_metrics(id) ON DELETE CASCADE,
    value INTEGER NOT NULL DEFAULT 0,
    PRIMARY KEY (report_id, metric_id)
);

CREATE INDEX IF NOT EXISTS idx_report_metric_values_report_id
    ON report_metric_values (report_id);

CREATE INDEX IF NOT EXISTS idx_report_metric_values_metric_id
    ON report_metric_values (metric_id);

-- ============================================================
-- RLS policies
-- ============================================================

ALTER TABLE group_metrics ENABLE ROW LEVEL SECURITY;
ALTER TABLE report_metric_values ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can read group metrics of their current group" ON group_metrics;
CREATE POLICY "Users can read group metrics of their current group"
    ON group_metrics FOR SELECT
    USING (
        EXISTS (
            SELECT 1
            FROM ibadat_profiles
            WHERE id = auth.uid()
              AND current_group_id = group_id
        )
    );

DROP POLICY IF EXISTS "Admins can insert group metrics for their group" ON group_metrics;
CREATE POLICY "Admins can insert group metrics for their group"
    ON group_metrics FOR INSERT
    WITH CHECK (
        EXISTS (
            SELECT 1
            FROM ibadat_profiles
            WHERE id = auth.uid()
              AND role IN ('admin', 'super_admin')
              AND current_group_id = group_id
        )
    );

DROP POLICY IF EXISTS "Admins can update group metrics for their group" ON group_metrics;
CREATE POLICY "Admins can update group metrics for their group"
    ON group_metrics FOR UPDATE
    USING (
        EXISTS (
            SELECT 1
            FROM ibadat_profiles
            WHERE id = auth.uid()
              AND role IN ('admin', 'super_admin')
              AND current_group_id = group_id
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1
            FROM ibadat_profiles
            WHERE id = auth.uid()
              AND role IN ('admin', 'super_admin')
              AND current_group_id = group_id
        )
    );

DROP POLICY IF EXISTS "Admins can delete group metrics for their group" ON group_metrics;
CREATE POLICY "Admins can delete group metrics for their group"
    ON group_metrics FOR DELETE
    USING (
        EXISTS (
            SELECT 1
            FROM ibadat_profiles
            WHERE id = auth.uid()
              AND role IN ('admin', 'super_admin')
              AND current_group_id = group_id
        )
    );

DROP POLICY IF EXISTS "Users can read report metric values for accessible reports" ON report_metric_values;
CREATE POLICY "Users can read report metric values for accessible reports"
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
              )
        )
    );

DROP POLICY IF EXISTS "Users can insert report metric values for accessible reports" ON report_metric_values;
CREATE POLICY "Users can insert report metric values for accessible reports"
    ON report_metric_values FOR INSERT
    WITH CHECK (
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
              )
        )
    );

DROP POLICY IF EXISTS "Users can update report metric values for accessible reports" ON report_metric_values;
CREATE POLICY "Users can update report metric values for accessible reports"
    ON report_metric_values FOR UPDATE
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
              )
        )
    )
    WITH CHECK (
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
              )
        )
    );

DROP POLICY IF EXISTS "Users can delete report metric values for accessible reports" ON report_metric_values;
CREATE POLICY "Users can delete report metric values for accessible reports"
    ON report_metric_values FOR DELETE
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
              )
        )
    );
