-- Add patient-level chat history support to the messages table
-- Run this in the Supabase SQL editor.

alter table public.messages
add column if not exists patient_id uuid;

alter table public.messages
add column if not exists visit_id uuid;

alter table public.messages
add column if not exists owner_id uuid;

create index if not exists messages_patient_id_timestamp_idx
on public.messages (patient_id, timestamp desc);

create index if not exists messages_visit_id_timestamp_idx
on public.messages (visit_id, timestamp desc);

