-- ============================================================
-- Migration: Разрешить админам создавать личные периоды и
--            сдавать личные отчёты БЕЗ привязки к группе.
-- Date: 2026-04-20
-- ============================================================
-- Что делает миграция:
--   1. Снимает NOT NULL с ibadat_periods.group_id
--      — чтобы можно было создать личный период без группы
--        (для админа, у которого ещё нет ни одной группы).
--   2. Снимает NOT NULL с ibadat_reports.group_id
--      — чтобы админ мог сдать отчёт по такому периоду.
--   3. Добавляет частичные уникальные индексы для личных отчётов
--      (group_id IS NULL), которых не защищают обычные UNIQUE-
--      constraint'ы из-за семантики NULLS DISTINCT в Postgres.
--
-- Обычные отчёты (с group_id) продолжают защищаться существующими
-- UNIQUE-constraint'ами: ibadat_reports_user_group_month_year_key
-- и UNIQUE(user_id, group_id, period_id).
-- ============================================================

-- 1. Периоды: личный период может не иметь group_id
ALTER TABLE ibadat_periods
  ALTER COLUMN group_id DROP NOT NULL;

-- 2. Отчёты: личный отчёт может не иметь group_id
ALTER TABLE ibadat_reports
  ALTER COLUMN group_id DROP NOT NULL;

-- 3. Защита от дубликатов личных отчётов (group_id IS NULL).
--    Обычные UNIQUE-constraints не срабатывают на NULL:
--    (user_id, NULL, period_id) ≠ (user_id, NULL, period_id)
--    с точки зрения UNIQUE NULLS DISTINCT. Добавляем partial unique
--    index'ы, которые работают только для строк с group_id IS NULL.

CREATE UNIQUE INDEX IF NOT EXISTS ibadat_reports_personal_period_unique
  ON ibadat_reports (user_id, period_id)
  WHERE group_id IS NULL AND period_id IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS ibadat_reports_personal_month_unique
  ON ibadat_reports (user_id, month, year)
  WHERE group_id IS NULL AND period_id IS NULL;
