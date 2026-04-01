-- ============================================================
-- Migration: Invite Codes system
-- Run this in Supabase SQL Editor
-- ============================================================

CREATE TABLE IF NOT EXISTS ibadat_invite_codes (
    id          BIGSERIAL PRIMARY KEY,
    code        VARCHAR(20) UNIQUE NOT NULL,       -- e.g. ADM-X592AB
    role_type   VARCHAR(20) NOT NULL,              -- 'ADMIN' or 'USER'
    group_id    UUID REFERENCES ibadat_groups(id) ON DELETE CASCADE,
    is_used     BOOLEAN NOT NULL DEFAULT FALSE,
    expires_at  TIMESTAMP WITH TIME ZONE NOT NULL, -- ADMIN: +7d, USER: +24h
    created_by  UUID REFERENCES ibadat_profiles(id) ON DELETE SET NULL
);

-- Index for fast code lookup
CREATE INDEX IF NOT EXISTS idx_invite_codes_code
    ON ibadat_invite_codes (code);

-- ============================================================
-- RLS Policies
-- ============================================================

ALTER TABLE ibadat_invite_codes ENABLE ROW LEVEL SECURITY;

-- Super-admins can insert ADMIN codes (created_by = their own id)
CREATE POLICY "Super-admins insert admin codes"
    ON ibadat_invite_codes FOR INSERT
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM ibadat_profiles
            WHERE id = auth.uid() AND role = 'super_admin'
        )
    );

-- Admins can insert USER codes for their own group
CREATE POLICY "Admins insert user codes"
    ON ibadat_invite_codes FOR INSERT
    WITH CHECK (
        role_type = 'USER'
        AND EXISTS (
            SELECT 1 FROM ibadat_profiles
            WHERE id = auth.uid() AND role IN ('admin', 'super_admin')
                AND current_group_id = group_id
        )
    );

-- Anyone authenticated can read a specific code (needed for validation)
CREATE POLICY "Authenticated users can read codes"
    ON ibadat_invite_codes FOR SELECT
    USING (auth.uid() IS NOT NULL);

-- Admins can mark codes as used (UPDATE is_used)
CREATE POLICY "Admins can mark codes used"
    ON ibadat_invite_codes FOR UPDATE
    USING (auth.uid() IS NOT NULL);
