-- ============================================================
--  ASHA Saathi AI: Biometric Device Sync PIN Migration
--  Run in: Supabase Dashboard → SQL Editor
-- ============================================================

CREATE TABLE IF NOT EXISTS public.device_sync_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    phone TEXT NOT NULL,
    pin TEXT NOT NULL,
    temp_password TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now(),
    expires_at TIMESTAMPTZ DEFAULT (now() + interval '10 minutes'),
    is_used BOOLEAN DEFAULT false
);

-- Reset policies if they exist
DROP POLICY IF EXISTS "Allows anonymous verification of sync PIN" ON public.device_sync_tokens;
DROP POLICY IF EXISTS "Allows service and admin insert/read" ON public.device_sync_tokens;
DROP POLICY IF EXISTS "Allows admin read/write sync PIN logs" ON public.device_sync_tokens;

-- Enable Row Level Security (RLS)
ALTER TABLE public.device_sync_tokens ENABLE ROW LEVEL SECURITY;

-- Policy 1: Allow the app/worker to READ unexpired, unused tokens during device transfer verification.
-- (All write operations are performed by the backend using the service_role key which bypasses RLS.)
CREATE POLICY "Allows anonymous verification of sync PIN" 
ON public.device_sync_tokens 
FOR SELECT 
USING (expires_at > now() AND is_used = false);

-- Note: The backend Express server uses SUPABASE_SERVICE_ROLE_KEY which bypasses RLS entirely,
-- so INSERT and UPDATE operations from the server always succeed without needing extra policies.
