-- ============================================================
-- Migration: Двуязычные названия динамических показателей
-- Date: 2026-04-20
-- ============================================================
-- Добавляет колонки name_ru и name_kk в group_metrics.
-- Старое поле name сохраняется как legacy (его туда писал
-- админ на одном языке). Backfill: оба новых поля заполняем
-- текущим name, чтобы ничего визуально не пропало до того,
-- как админ переведёт вручную.
--
-- Модель Flutter теперь читает/пишет только name_ru и name_kk.
-- Колонку name можно будет дропнуть в следующей миграции, когда
-- все клиенты обновятся.
-- ============================================================

ALTER TABLE group_metrics
  ADD COLUMN IF NOT EXISTS name_ru TEXT,
  ADD COLUMN IF NOT EXISTS name_kk TEXT;

UPDATE group_metrics
  SET name_ru = COALESCE(name_ru, name),
      name_kk = COALESCE(name_kk, name)
  WHERE name_ru IS NULL OR name_kk IS NULL;
