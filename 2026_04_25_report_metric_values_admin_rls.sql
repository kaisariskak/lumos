-- ============================================================
-- Migration: RLS-политики report_metric_values — доступ админа по
--            admin_id группы, а не по current_group_id профиля
-- Date: 2026-04-25
-- ============================================================
-- Прежние политики (миграция 2026_04_18_dynamic_group_report_metrics.sql)
-- разрешали админу читать/писать чужие значения показателей только если
-- в профиле админа current_group_id совпадал с group_id отчёта:
--
--   OR ( p.role IN ('admin','super_admin')
--        AND p.current_group_id = r.group_id )
--
-- Это ломается в двух сценариях:
--   1. Админ только что создал группу — current_group_id у него ещё null.
--   2. У админа несколько групп и current_group_id указывает на одну,
--      а он просматривает отчёты другой.
--
-- В обоих случаях админ видит заголовок ibadat_reports (там политика
-- мягче), но значения из report_metric_values RLS режет, и в UI
-- показываются нули вместо реальных данных.
--
-- Правильная проверка — владение группой через ibadat_groups.admin_id.
-- Добавляем эту ветку ко всем четырём политикам.
-- ============================================================

-- ── SELECT ─────────────────────────────────────────────────────
DROP POLICY IF EXISTS "Users can read report metric values for accessible reports"
  ON report_metric_values;

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
          OR EXISTS (
            SELECT 1 FROM ibadat_groups g
            WHERE g.id = r.group_id
              AND g.admin_id = auth.uid()
          )
        )
    )
  );

-- ── INSERT ─────────────────────────────────────────────────────
DROP POLICY IF EXISTS "Users can insert report metric values for accessible reports"
  ON report_metric_values;

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
          OR EXISTS (
            SELECT 1 FROM ibadat_groups g
            WHERE g.id = r.group_id
              AND g.admin_id = auth.uid()
          )
        )
    )
  );

-- ── UPDATE ─────────────────────────────────────────────────────
DROP POLICY IF EXISTS "Users can update report metric values for accessible reports"
  ON report_metric_values;

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
          OR EXISTS (
            SELECT 1 FROM ibadat_groups g
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
      LEFT JOIN ibadat_profiles p ON p.id = auth.uid()
      WHERE r.id = report_id
        AND (
          r.user_id = auth.uid()
          OR (
            p.role IN ('admin', 'super_admin')
            AND p.current_group_id = r.group_id
          )
          OR EXISTS (
            SELECT 1 FROM ibadat_groups g
            WHERE g.id = r.group_id
              AND g.admin_id = auth.uid()
          )
        )
    )
  );

-- ── DELETE ─────────────────────────────────────────────────────
DROP POLICY IF EXISTS "Users can delete report metric values for accessible reports"
  ON report_metric_values;

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
          OR EXISTS (
            SELECT 1 FROM ibadat_groups g
            WHERE g.id = r.group_id
              AND g.admin_id = auth.uid()
          )
        )
    )
  );
