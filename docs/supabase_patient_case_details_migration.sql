ALTER TABLE public.patients
  ADD COLUMN IF NOT EXISTS case_details jsonb NOT NULL DEFAULT '{}'::jsonb;
