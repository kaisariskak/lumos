-- ============================================================
-- Migration: Личные показатели администратора
-- Date: 2026-04-20
-- ============================================================
-- Расширяет group_metrics так, чтобы показатель принадлежал либо
-- группе (как раньше), либо конкретному администратору — для его
-- личных периодов. Ровно одно из (group_id, admin_id) должно быть
-- задано.
--
-- Модель Flutter читает и пишет:
--   * groupId != null, adminId == null  — показатель группы
--     (виден всем участникам группы в отчёте).
--   * groupId == null, adminId != null  — личный показатель админа
--     (виден только в «Мои периоды» и при сдаче отчёта админом).
-- ============================================================

ALTER TABLE group_metrics
  ADD COLUMN IF NOT EXISTS admin_id UUID
    REFERENCES ibadat_profiles(id) ON DELETE CASCADE;

ALTER TABLE group_metrics
  ALTER COLUMN group_id DROP NOT NULL;

-- Ровно одно из полей должно быть заполнено.
ALTER TABLE group_metrics
  DROP CONSTRAINT IF EXISTS group_metrics_owner_check;

ALTER TABLE group_metrics
  ADD CONSTRAINT group_metrics_owner_check
  CHECK ((group_id IS NOT NULL) <> (admin_id IS NOT NULL));

CREATE INDEX IF NOT EXISTS idx_group_metrics_admin_id
  ON group_metrics (admin_id)
  WHERE admin_id IS NOT NULL;
