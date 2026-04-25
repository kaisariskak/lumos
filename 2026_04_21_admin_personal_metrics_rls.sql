-- ============================================================
-- Migration: RLS-политики для личных показателей администратора
-- Date: 2026-04-21
-- ============================================================
-- Миграция 2026_04_20_admin_personal_metrics.sql добавила колонку
-- admin_id и разрешила group_id = NULL, но RLS-политики остались
-- старыми: все они проверяют current_group_id = group_id. Для
-- личных показателей (group_id IS NULL) это выражение равно NULL,
-- поэтому INSERT/SELECT/UPDATE/DELETE отклоняются.
--
-- Результат: при попытке админа добавить себе личный показатель
-- клиент получает PostgrestException, но SnackBar с ошибкой прячется
-- за открытым bottom sheet, и пользователю кажется, что "ничего не
-- происходит".
--
-- Решение: расширить политики ветвью для admin_id-строк.
-- ============================================================

-- ── SELECT ─────────────────────────────────────────────────────
DROP POLICY IF EXISTS "Users can read group metrics of their current group"
  ON group_metrics;

CREATE POLICY "Users can read group metrics of their current group"
  ON group_metrics FOR SELECT
  USING (
    (
      group_id IS NOT NULL
      AND EXISTS (
        SELECT 1
        FROM ibadat_profiles
        WHERE id = auth.uid()
          AND current_group_id = group_id
      )
    )
    OR (
      admin_id IS NOT NULL
      AND admin_id = auth.uid()
    )
  );

-- ── INSERT ─────────────────────────────────────────────────────
DROP POLICY IF EXISTS "Admins can insert group metrics for their group"
  ON group_metrics;

CREATE POLICY "Admins can insert group metrics for their group"
  ON group_metrics FOR INSERT
  WITH CHECK (
    (
      group_id IS NOT NULL
      AND EXISTS (
        SELECT 1
        FROM ibadat_profiles
        WHERE id = auth.uid()
          AND role IN ('admin', 'super_admin')
          AND current_group_id = group_id
      )
    )
    OR (
      admin_id IS NOT NULL
      AND admin_id = auth.uid()
      AND EXISTS (
        SELECT 1
        FROM ibadat_profiles
        WHERE id = auth.uid()
          AND role IN ('admin', 'super_admin')
      )
    )
  );

-- ── UPDATE ─────────────────────────────────────────────────────
DROP POLICY IF EXISTS "Admins can update group metrics for their group"
  ON group_metrics;

CREATE POLICY "Admins can update group metrics for their group"
  ON group_metrics FOR UPDATE
  USING (
    (
      group_id IS NOT NULL
      AND EXISTS (
        SELECT 1
        FROM ibadat_profiles
        WHERE id = auth.uid()
          AND role IN ('admin', 'super_admin')
          AND current_group_id = group_id
      )
    )
    OR (
      admin_id IS NOT NULL
      AND admin_id = auth.uid()
    )
  )
  WITH CHECK (
    (
      group_id IS NOT NULL
      AND EXISTS (
        SELECT 1
        FROM ibadat_profiles
        WHERE id = auth.uid()
          AND role IN ('admin', 'super_admin')
          AND current_group_id = group_id
      )
    )
    OR (
      admin_id IS NOT NULL
      AND admin_id = auth.uid()
    )
  );

-- ── DELETE ─────────────────────────────────────────────────────
DROP POLICY IF EXISTS "Admins can delete group metrics for their group"
  ON group_metrics;

CREATE POLICY "Admins can delete group metrics for their group"
  ON group_metrics FOR DELETE
  USING (
    (
      group_id IS NOT NULL
      AND EXISTS (
        SELECT 1
        FROM ibadat_profiles
        WHERE id = auth.uid()
          AND role IN ('admin', 'super_admin')
          AND current_group_id = group_id
      )
    )
    OR (
      admin_id IS NOT NULL
      AND admin_id = auth.uid()
    )
  );
