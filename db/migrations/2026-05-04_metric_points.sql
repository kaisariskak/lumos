-- 2026-05-04 Add optional points_per_unit to group_metrics.
-- Admin can set how much completed value earns a configured point value.
-- UI computes points as (value / points_per_unit) * points_value.
-- Apply via Supabase SQL Editor.

BEGIN;

ALTER TABLE group_metrics
  ADD COLUMN IF NOT EXISTS points_per_unit int;

ALTER TABLE group_metrics
  ADD COLUMN IF NOT EXISTS points_value int;

-- Optional sanity check: only positive values make sense
-- (NULL = "no points scoring for this metric").
ALTER TABLE group_metrics
  ADD CONSTRAINT group_metrics_points_per_unit_positive
  CHECK (points_per_unit IS NULL OR points_per_unit > 0);

ALTER TABLE group_metrics
  ADD CONSTRAINT group_metrics_points_value_positive
  CHECK (points_value IS NULL OR points_value > 0);

COMMIT;
