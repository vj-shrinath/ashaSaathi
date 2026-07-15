# Supabase Data Model & Access Notes

This document replaces the older Firestore-first schema description. The active implementation uses Supabase Postgres tables and Supabase Auth.

## Core Tables

### `users`
Stored user profile and role metadata linked to Supabase Auth.

- `id` UUID, primary key
- `role` text, values such as `asha`, `doctor`, `admin`
- `phone` text
- `name` text
- `created_at` timestamp

### `patients`
Patient master record.

- `id` UUID, primary key
- `asha_id` UUID, references the assigned user
- `name` text
- `age` integer
- `gender` text
- `village` text
- `family_phone_number` text
- `medical_history` jsonb or text array
- `current_risk_category` text
- `created_at` timestamp
- `updated_at` timestamp

### `visits`
Visit records created from ASHA check-ins.

- `id` UUID, primary key
- `patient_id` UUID
- `asha_id` UUID
- `timestamp` timestamp
- `audio_url` text
- `transcribed_text` text
- `vitals` jsonb
- `symptoms` text array
- `triage_report_id` UUID

### `triage_reports`
Structured Gemini output for each analyzed visit.

- `id` UUID, primary key
- `visit_id` UUID
- `patient_id` UUID
- `risk_score` integer
- `risk_category` text
- `suggested_action` text
- `is_emergency` boolean
- `ambulance_recommended` boolean
- `confidence_score` numeric
- `created_at` timestamp

### `doctor_alerts`
Alerts shown on the doctor dashboard.

- `id` UUID, primary key
- `patient_id` UUID
- `asha_id` UUID
- `assigned_doctor_id` UUID
- `status` text
- `timestamp` timestamp

### `emergency_events`
Records for urgent escalation.

- `id` UUID, primary key
- `patient_id` UUID
- `asha_id` UUID
- `status` text
- `timestamp` timestamp

### `activity_logs`
Audit trail for key system events.

- `id` UUID, primary key
- `actor_id` UUID
- `entity_type` text
- `entity_id` UUID
- `action` text
- `metadata` jsonb
- `created_at` timestamp

## Access Model

- Users authenticate through Supabase Auth.
- Role-based access should be enforced with Row Level Security.
- ASHA users should only access their assigned patients and visits.
- Doctors should access patients and alerts assigned to them or visible in their scope.
- Admin users should have broader read access and controlled write access.
- Backend service roles can write triage, activity, and escalation records.

## Indexing Guidance

Recommended indexes for performance:

- `patients(asha_id, current_risk_category)`
- `visits(patient_id, timestamp desc)`
- `doctor_alerts(assigned_doctor_id, status, timestamp desc)`
- `triage_reports(patient_id, created_at desc)`

## Notes

- The old Firestore schema is no longer the active architecture.
- If a Firebase file remains in the repo, treat it as legacy until removed or replaced.
- Keep this document aligned with the actual Supabase migration as tables mature.
