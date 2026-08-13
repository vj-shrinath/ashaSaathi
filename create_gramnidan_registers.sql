-- Create the gramnidan_registers table
CREATE TABLE IF NOT EXISTS public.gramnidan_registers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  asha_id uuid NOT NULL,
  patient_id uuid,
  patient_name text NOT NULL,
  register_type text NOT NULL,
  transcript text,
  module_data jsonb NOT NULL DEFAULT '{}'::jsonb,
  is_warning boolean DEFAULT false,
  submitted_to_tho boolean DEFAULT false,
  pdf_url text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Enable Row Level Security (RLS)
ALTER TABLE public.gramnidan_registers ENABLE ROW LEVEL SECURITY;

-- Allow ASHA workers to insert their own registers
CREATE POLICY "ASHA can insert their own registers" ON public.gramnidan_registers
  FOR INSERT WITH CHECK (auth.uid() = asha_id);

-- Allow ASHA workers to view and update their own registers
CREATE POLICY "ASHA can view and update their own registers" ON public.gramnidan_registers
  FOR ALL USING (auth.uid() = asha_id);

-- Allow THO (Taluka Health Officer) to view all block registers
CREATE POLICY "THO can view all registers" ON public.gramnidan_registers
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.user_profiles 
      WHERE user_profiles.id = auth.uid() 
      AND user_profiles.role = 'tho'
    )
  );

-- Function and trigger to auto-update the 'updated_at' timestamp
CREATE OR REPLACE FUNCTION update_gramnidan_updated_at()
RETURNS TRIGGER AS $$
BEGIN
   NEW.updated_at = now();
   RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_gramnidan_updated_at
BEFORE UPDATE ON public.gramnidan_registers
FOR EACH ROW
EXECUTE PROCEDURE update_gramnidan_updated_at();

-- Add storage bucket for PDFs if they don't already exist
INSERT INTO storage.buckets (id, name, public) VALUES ('register-pdfs', 'register-pdfs', true) ON CONFLICT DO NOTHING;

-- Policy to allow anonymous/public reads for PDFs (or restrict as needed)
CREATE POLICY "Public Access for PDFs" ON storage.objects
  FOR SELECT USING (bucket_id = 'register-pdfs');
  
-- Policy to allow authenticated uploads to PDFs bucket
CREATE POLICY "Authenticated users can upload PDFs" ON storage.objects
  FOR INSERT WITH CHECK (bucket_id = 'register-pdfs' AND auth.role() = 'authenticated');

-- IMPORTANT: Enable Supabase Realtime for this table so the THO dashboard updates live
-- This adds the table to the supabase_realtime publication
BEGIN;
  DROP PUBLICATION IF EXISTS supabase_realtime;
  CREATE PUBLICATION supabase_realtime;
COMMIT;
ALTER PUBLICATION supabase_realtime ADD TABLE public.gramnidan_registers;

