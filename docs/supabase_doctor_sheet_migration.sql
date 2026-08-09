-- Stores the editable PHC doctor/ANM form alongside the AI triage report.
-- Run once in the Supabase SQL editor before enabling cloud save.
ALTER TABLE public.triage_reports
  ADD COLUMN IF NOT EXISTS doctor_sheet jsonb NOT NULL DEFAULT '{}'::jsonb;

ALTER TABLE public.triage_reports
  ADD COLUMN IF NOT EXISTS doctor_sheet_updated_at timestamptz;

CREATE INDEX IF NOT EXISTS triage_reports_doctor_sheet_updated_idx
  ON public.triage_reports (doctor_sheet_updated_at DESC);
