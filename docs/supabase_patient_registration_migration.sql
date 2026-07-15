-- Add ASHA patient register classification support.
-- Run this in the Supabase SQL editor.

alter table public.patients
add column if not exists register_type text;

create index if not exists patients_register_type_idx
on public.patients (register_type);

