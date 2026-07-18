-- ============================================================
--  RESET: Delete all app data for a fresh start
--  ASHA Saathi AI
--  Run in: Supabase Dashboard → SQL Editor
--
--  ⚠️ WARNING: This is IRREVERSIBLE. Run only on dev/staging
--     or when you are absolutely sure you want a fresh start.
-- ============================================================

-- Disable triggers temporarily for fast bulk delete
SET session_replication_role = replica;

-- ─────────────────────────────────────────────────────────────
-- 1. Delete all messages
-- ─────────────────────────────────────────────────────────────
DELETE FROM public.messages;

-- Also delete error/stuck processing messages specifically
-- (in case partial rows remain after the bulk clear)
DELETE FROM public.messages
WHERE is_processing = TRUE;

-- ─────────────────────────────────────────────────────────────
-- 2. Delete all triage reports
-- ─────────────────────────────────────────────────────────────
DELETE FROM public.triage_reports;

-- ─────────────────────────────────────────────────────────────
-- 3. Delete all prescriptions
-- ─────────────────────────────────────────────────────────────
DELETE FROM public.prescriptions;

-- ─────────────────────────────────────────────────────────────
-- 4. Delete all visits
-- ─────────────────────────────────────────────────────────────
DELETE FROM public.visits;

-- ─────────────────────────────────────────────────────────────
-- 5. Delete all activity logs
-- ─────────────────────────────────────────────────────────────
DELETE FROM public.activity_logs;

-- ─────────────────────────────────────────────────────────────
-- 6. Delete all patients
-- ─────────────────────────────────────────────────────────────
DELETE FROM public.patients;

-- Re-enable triggers
SET session_replication_role = DEFAULT;

-- ─────────────────────────────────────────────────────────────
-- VERIFY — should all return 0 rows:
-- ─────────────────────────────────────────────────────────────
SELECT 'messages'      AS tbl, COUNT(*) FROM public.messages
UNION ALL
SELECT 'triage_reports',       COUNT(*) FROM public.triage_reports
UNION ALL
SELECT 'prescriptions',        COUNT(*) FROM public.prescriptions
UNION ALL
SELECT 'visits',               COUNT(*) FROM public.visits
UNION ALL
SELECT 'activity_logs',        COUNT(*) FROM public.activity_logs
UNION ALL
SELECT 'patients',             COUNT(*) FROM public.patients;
