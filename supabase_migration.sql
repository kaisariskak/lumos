-- ============================================================
-- Migration: Role hierarchy + monthly reports
-- Run this in Supabase SQL Editor
-- ============================================================

-- 1. Add super_admin_id to profiles
--    (for admin users — tracks which super-admin created them)
ALTER TABLE ibadat_profiles
  ADD COLUMN IF NOT EXISTS super_admin_id UUID
    REFERENCES ibadat_profiles(id) ON DELETE SET NULL;

-- 2. Add created_by_admin_id to profiles
--    (for regular users — tracks which admin added them)
ALTER TABLE ibadat_profiles
  ADD COLUMN IF NOT EXISTS created_by_admin_id UUID
    REFERENCES ibadat_profiles(id) ON DELETE SET NULL;

-- 3. Add target_role to allowlist
--    ('user' for regular users, 'admin' when super-admin pre-registers an admin)
ALTER TABLE ibadat_allowlist
  ADD COLUMN IF NOT EXISTS target_role TEXT NOT NULL DEFAULT 'user';

-- 4. Change ibadat_reports from weekly to monthly
--    Step 4a: add month column
ALTER TABLE ibadat_reports
  ADD COLUMN IF NOT EXISTS month INT;

--    Step 4b: migrate existing data (approximate: week → month)
UPDATE ibadat_reports
  SET month = LEAST(CEIL(week_number::float / 4.33)::int, 12)
  WHERE month IS NULL;

--    Step 4c: make month NOT NULL
ALTER TABLE ibadat_reports
  ALTER COLUMN month SET NOT NULL;

--    Step 4d: drop old unique constraint
ALTER TABLE ibadat_reports
  DROP CONSTRAINT IF EXISTS ibadat_reports_user_id_group_id_week_number_year_key;

--    Step 4e: add new unique constraint
ALTER TABLE ibadat_reports
  ADD CONSTRAINT ibadat_reports_user_group_month_year_key
    UNIQUE (user_id, group_id, month, year);

--    Step 4f: drop old week_number column
ALTER TABLE ibadat_reports DROP COLUMN IF EXISTS week_number;

-- ============================================================
-- RLS policy hints (adjust as needed for your policies):
-- ============================================================
-- For ibadat_profiles with super_admin_id:
--   Super-admin can SELECT profiles WHERE super_admin_id = auth.uid()
--   Super-admin can SELECT ungrouped profiles WHERE created_by_admin_id IN
--     (SELECT id FROM ibadat_profiles WHERE super_admin_id = auth.uid())
--     AND current_group_id IS NULL
--
-- For ibadat_groups with admin scoping:
--   Super-admin sees groups WHERE admin_id IN
--     (SELECT id FROM ibadat_profiles WHERE super_admin_id = auth.uid())
-- ============================================================
