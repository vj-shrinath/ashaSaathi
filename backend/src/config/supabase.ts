import { createClient, SupabaseClient } from '@supabase/supabase-js';
import dotenv from 'dotenv';
dotenv.config();

// Polyfill WebSocket for Node.js 20 (needed by @supabase/realtime-js)
if (typeof globalThis.WebSocket === 'undefined') {
  // eslint-disable-next-line @typescript-eslint/no-var-requires
  globalThis.WebSocket = require('ws');
}

const SUPABASE_URL = process.env.SUPABASE_URL!;
const SUPABASE_SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY!;

if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
  throw new Error('Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY');
}

export const supabase: SupabaseClient = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
  auth: { autoRefreshToken: false, persistSession: false },
});

// Helper to get current timestamp for Supabase
export const now = () => new Date().toISOString();

// Table names matching Flutter app schema
export const TABLES = {
  PATIENTS: 'patients',
  VISITS: 'visits',
  MESSAGES: 'messages',
  TRIAGE_REPORTS: 'triage_reports',
  ACTIVITY_LOGS: 'activity_logs',
  DOCTOR_ALERTS: 'doctor_alerts',
  EMERGENCY_EVENTS: 'emergency_events',
} as const;
