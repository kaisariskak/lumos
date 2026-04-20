-- ============================================================
-- Migration: Drop unused legacy tables and columns
-- Date: 2026-04-20
-- ============================================================
-- 1. Таблицы, больше не используемые Flutter-кодом:
--      * group_custom_categories + custom_report_values
--          Старая система пользовательских категорий, заменена на
--          group_metrics + report_metric_values (см. миграцию
--          2026_04_18_dynamic_group_report_metrics.sql).
--      * ibadat_group_settings
--          Репозиторий IbadatGroupSettingsRepository удалён,
--          функциональность не используется.
--
-- 2. Legacy-колонки в ibadat_reports:
--      quran_pages, book_pages, jawshan_count, fasting_days,
--      risale_pages, audio_minutes, salawat_count, istighfar_count,
--      tahajjud_count, zikir_count
--      Это старый набор фиксированных показателей. Теперь все
--      значения хранятся в report_metric_values и ссылаются на
--      group_metrics. Клиент больше не читает и не пишет в эти
--      колонки.
--
-- ВНИМАНИЕ: перед выполнением СДЕЛАЙТЕ БЭКАП БД. Операции
-- необратимы: CASCADE удалит зависимые FK и индексы, DROP COLUMN
-- сотрёт исторические значения показателей из ibadat_reports.
-- Если нужно сохранить их — перенесите в report_metric_values
-- до выполнения этой миграции.
-- ============================================================

-- 1. Удаление неиспользуемых таблиц
DROP TABLE IF EXISTS custom_report_values CASCADE;
DROP TABLE IF EXISTS group_custom_categories CASCADE;
DROP TABLE IF EXISTS ibadat_group_settings CASCADE;

-- 2. Удаление legacy-колонок из ibadat_reports
ALTER TABLE ibadat_reports
  DROP COLUMN IF EXISTS quran_pages,
  DROP COLUMN IF EXISTS book_pages,
  DROP COLUMN IF EXISTS jawshan_count,
  DROP COLUMN IF EXISTS fasting_days,
  DROP COLUMN IF EXISTS risale_pages,
  DROP COLUMN IF EXISTS audio_minutes,
  DROP COLUMN IF EXISTS salawat_count,
  DROP COLUMN IF EXISTS istighfar_count,
  DROP COLUMN IF EXISTS tahajjud_count,
  DROP COLUMN IF EXISTS zikir_count;
