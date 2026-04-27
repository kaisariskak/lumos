-- ============================================================
-- Migration: RPC function to mark invite code as used
-- Date: 2026-04-27
-- Зачем: прямой UPDATE через клиент иногда не срабатывает из-за
-- тонкостей RLS (нет результата → StateError → тихий лог).
-- SECURITY DEFINER обходит RLS полностью и гарантирует обновление.
-- ============================================================

DROP FUNCTION IF EXISTS mark_invite_code_used(BIGINT);

CREATE OR REPLACE FUNCTION mark_invite_code_used(code_id BIGINT)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE ibadat_invite_codes
     SET is_used = TRUE
   WHERE id = code_id
     AND is_used = FALSE;
END;
$$;

-- Только аутентифицированные пользователи могут вызывать функцию
REVOKE ALL ON FUNCTION mark_invite_code_used(BIGINT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION mark_invite_code_used(BIGINT) TO authenticated;
