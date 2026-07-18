-- ============================================================
--  MIGRATION: Tarpit — blocked_ips table & helper RPC
--  ASHA Saathi AI | Security Layer
--  Run once in: Supabase Dashboard → SQL Editor
-- ============================================================

-- ─────────────────────────────────────────────────────────────
-- 1. Create the blocked_ips table
--    Stores every IP the tarpit has caught along with metadata
--    to help the security team audit and review bans.
-- ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.blocked_ips (
  id           BIGSERIAL       PRIMARY KEY,
  ip_address   TEXT            NOT NULL UNIQUE,   -- the banned IP (IPv4 or IPv6)
  reason       TEXT            NOT NULL,           -- e.g. "Tarpit hit: /.env"
  hit_count    INTEGER         NOT NULL DEFAULT 1, -- how many times this IP probed us
  banned_at    TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
  last_seen_at TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
  is_active    BOOLEAN         NOT NULL DEFAULT TRUE  -- set FALSE to lift a ban manually
);

-- Index makes the per-request IP lookup sub-millisecond even with millions of rows.
CREATE INDEX IF NOT EXISTS idx_blocked_ips_ip_address
  ON public.blocked_ips (ip_address)
  WHERE is_active = TRUE;

-- ─────────────────────────────────────────────────────────────
-- 2. Row-Level Security
--    The service-role key used by the backend bypasses RLS,
--    so these policies protect against accidental anon exposure.
-- ─────────────────────────────────────────────────────────────
ALTER TABLE public.blocked_ips ENABLE ROW LEVEL SECURITY;

-- No anon / authenticated reads — only the service role can query.
CREATE POLICY "Deny public read on blocked_ips"
  ON public.blocked_ips
  FOR SELECT
  TO anon, authenticated
  USING (FALSE);

CREATE POLICY "Deny public writes on blocked_ips"
  ON public.blocked_ips
  FOR INSERT
  TO anon, authenticated
  WITH CHECK (FALSE);

-- ─────────────────────────────────────────────────────────────
-- 3. RPC: increment_blocked_ip_hits
--    Called by the tarpit when a blacklisted IP is seen again.
--    Updates both hit_count and last_seen_at atomically.
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.increment_blocked_ip_hits(p_ip_address TEXT)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER   -- runs with owner privileges regardless of caller role
AS $$
BEGIN
  UPDATE public.blocked_ips
  SET
    hit_count    = hit_count + 1,
    last_seen_at = NOW()
  WHERE ip_address = p_ip_address
    AND is_active  = TRUE;
END;
$$;

-- ─────────────────────────────────────────────────────────────
-- 4. Helpful admin view — not required for runtime operation.
--    Run in SQL Editor to audit recent threats:
--      SELECT * FROM v_recent_threats ORDER BY last_seen_at DESC;
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE VIEW public.v_recent_threats AS
SELECT
  ip_address,
  reason,
  hit_count,
  banned_at,
  last_seen_at,
  EXTRACT(EPOCH FROM (NOW() - last_seen_at)) / 60 AS minutes_since_last_seen
FROM public.blocked_ips
WHERE is_active = TRUE
ORDER BY last_seen_at DESC;

-- ─────────────────────────────────────────────────────────────
-- DONE. Verify with:
--   SELECT * FROM public.blocked_ips LIMIT 5;
--   SELECT proname FROM pg_proc WHERE proname = 'increment_blocked_ip_hits';
-- ─────────────────────────────────────────────────────────────
