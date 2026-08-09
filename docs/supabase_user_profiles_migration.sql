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
  phc_id      UUID,                             -- parent PHC/facility
  doctor_id   UUID,                             -- ASHA's supervising doctor
  is_active   BOOLEAN     NOT NULL DEFAULT TRUE,
  must_change_password BOOLEAN NOT NULL DEFAULT FALSE,
  password_changed_at TIMESTAMPTZ,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Keep existing installations compatible with the current app/backend.
ALTER TABLE public.user_profiles
  ADD COLUMN IF NOT EXISTS must_change_password BOOLEAN NOT NULL DEFAULT FALSE;

ALTER TABLE public.user_profiles
  ADD COLUMN IF NOT EXISTS password_changed_at TIMESTAMPTZ;

CREATE TABLE IF NOT EXISTS public.phcs (
  id          UUID        PRIMARY KEY,
  name        TEXT        NOT NULL,
  code        TEXT        NOT NULL UNIQUE,
  district    TEXT,
  taluka      TEXT,
  village     TEXT,
  address     TEXT,
  is_active   BOOLEAN     NOT NULL DEFAULT TRUE,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_phcs_code
  ON public.phcs (code);

CREATE INDEX IF NOT EXISTS idx_user_profiles_phc_id
  ON public.user_profiles (phc_id);

CREATE INDEX IF NOT EXISTS idx_user_profiles_doctor_id
  ON public.user_profiles (doctor_id);

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

ALTER TABLE public.phcs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Authenticated can read active phcs" ON public.phcs;
DROP POLICY IF EXISTS "Admin can manage phcs" ON public.phcs;

CREATE POLICY "Authenticated can read active phcs"
  ON public.phcs
  FOR SELECT
  TO authenticated
  USING (is_active = TRUE);

CREATE POLICY "Admin can manage phcs"
  ON public.phcs
  FOR ALL
  TO authenticated
  USING (auth.jwt() ->> 'role' = 'admin');

-- ─────────────────────────────────────────────────────────────
-- 3. Verify
-- ─────────────────────────────────────────────────────────────
-- SELECT * FROM public.user_profiles LIMIT 5;
