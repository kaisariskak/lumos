-- ============================================================
-- Migration: Разрешить несколько отчётов в одном календарном
--            месяце, если они относятся к разным периодам.
-- Date: 2026-04-25
-- ============================================================
-- Проблема
-- --------
-- Пользователь создал 2 недельных периода внутри апреля. Отчёт
-- по первому периоду сохранился, а при сохранении отчёта по
-- второму Supabase возвращает:
--
--   duplicate key value violates unique constraint
--   "ibadat_reports_user_group_month_year_key"  (code 23505)
--
-- Причина — старый constraint с главной миграции:
--
--   UNIQUE (user_id, group_id, month, year)
--
-- Он не учитывает period_id и запрещает два отчёта в одном
-- месяце для одной группы, даже если это разные периоды.
--
-- Репозиторий (ibadat_report_repository.dart) при наличии
-- period_id делает upsert с onConflict='user_id,group_id,period_id',
-- но такого уникального индекса в схеме нет — поэтому INSERT
-- падает на старом month/year constraint.
--
-- Решение
-- -------
-- 1. Снять жёсткий constraint (user_id, group_id, month, year).
-- 2. Восстановить month/year-дедупликацию как partial unique
--    index WHERE period_id IS NULL — для legacy-отчётов без
--    периодов логика остаётся прежней.
-- 3. Добавить partial unique index (user_id, group_id, period_id)
--    WHERE period_id IS NOT NULL AND group_id IS NOT NULL —
--    теперь onConflict, который указывает код, опирается на
--    реально существующий индекс.
--
-- Личные отчёты (group_id IS NULL) уже защищены частичными
-- индексами из миграции 2026_04_20_admin_personal_periods.sql,
-- их трогать не нужно.
-- ============================================================

-- 1. Drop the old full unique constraint on (user_id, group_id, month, year)
ALTER TABLE ibadat_reports
  DROP CONSTRAINT IF EXISTS ibadat_reports_user_group_month_year_key;

-- 2. Legacy / non-period reports: keep month+year uniqueness per (user, group)
CREATE UNIQUE INDEX IF NOT EXISTS ibadat_reports_group_month_year_legacy_unique
  ON ibadat_reports (user_id, group_id, month, year)
  WHERE group_id IS NOT NULL AND period_id IS NULL;

-- 3. Period-based group reports: uniqueness is per period, not per month
CREATE UNIQUE INDEX IF NOT EXISTS ibadat_reports_group_period_unique
  ON ibadat_reports (user_id, group_id, period_id)
  WHERE group_id IS NOT NULL AND period_id IS NOT NULL;
