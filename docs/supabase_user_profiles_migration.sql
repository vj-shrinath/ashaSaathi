-- ============================================================
--  MIGRATION: user_profiles table
--  ASHA Saathi AI
--  Run once in: Supabase Dashboard → SQL Editor
--
--  This table stores the app-level role and status for every
--  registered ASHA / Doctor / Admin user. It is populated by
--  the backend's /api/v1/auth/register-worker endpoint using
--  the service_role key (bypasses RLS).
-- ============================================================

-- ─────────────────────────────────────────────────────────────
-- 1. Create the table
-- ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.user_profiles (
  id          UUID        PRIMARY KEY,          -- matches auth.users.id
  role        TEXT        NOT NULL,             -- 'asha' | 'doctor' | 'admin'
  full_name   TEXT,                             -- display name (optional cache)
  is_active   BOOLEAN     NOT NULL DEFAULT TRUE,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Fast lookup by role (e.g. list all ASHAs)
CREATE INDEX IF NOT EXISTS idx_user_profiles_role
  ON public.user_profiles (role);

-- ─────────────────────────────────────────────────────────────
-- 2. Row-Level Security
--    The backend uses SUPABASE_SERVICE_ROLE_KEY which bypasses
--    RLS for all INSERT / UPDATE operations.
--    Authenticated users can only read their own profile row.
-- ─────────────────────────────────────────────────────────────
ALTER TABLE public.user_profiles ENABLE ROW LEVEL SECURITY;

-- Drop old policies (idempotent re-run safety)
DROP POLICY IF EXISTS "Users can read own profile" ON public.user_profiles;
DROP POLICY IF EXISTS "Deny anon read on user_profiles"  ON public.user_profiles;

-- Authenticated users may read their own row only
CREATE POLICY "Users can read own profile"
  ON public.user_profiles
  FOR SELECT
  TO authenticated
  USING (auth.uid() = id);

-- Anon cannot read anything
CREATE POLICY "Deny anon read on user_profiles"
  ON public.user_profiles
  FOR SELECT
  TO anon
  USING (FALSE);

-- ─────────────────────────────────────────────────────────────
-- 3. Verify
-- ─────────────────────────────────────────────────────────────
-- SELECT * FROM public.user_profiles LIMIT 5;
