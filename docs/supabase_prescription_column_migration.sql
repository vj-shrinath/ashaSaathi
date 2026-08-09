-- Add prescription column to messages table for doctor prescriptions in chat
-- Run this in the Supabase SQL editor.

alter table public.messages
add column if not exists prescription jsonb;

-- Optional: Add a type check constraint to ensure prescription is valid JSON
-- (PostgreSQL will automatically validate jsonb on insert)

comment on column public.messages.prescription is 'Stores prescription data when message type is prescription';