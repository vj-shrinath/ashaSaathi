# Supabase & Deployment Setup Guide

This guide replaces the older Firebase-centric setup. The active stack is Supabase plus the Node.js backend and Flutter app.

## Prerequisites

- Supabase project
- Node.js 18+
- Flutter 3.x
- Supabase CLI if you plan to manage schema locally

---

## Step 1: Create Supabase Project

1. Sign in to the Supabase dashboard.
2. Create a new project for ASHA Saathi AI.
3. Save the project URL and service role key securely.
4. Configure your database region as close to your user base as practical.

---

## Step 2: Configure Auth

- Enable the sign-in methods you plan to support.
- Set up user profiles and role metadata.
- Make sure sessions are passed cleanly from the Flutter app.

---

## Step 3: Create Database Tables

Create the tables described in `docs/firestore_schema.md`:

- `users`
- `patients`
- `visits`
- `triage_reports`
- `doctor_alerts`
- `emergency_events`
- `activity_logs`

Add the recommended indexes and row-level security policies.

---

## Step 4: Configure Flutter

Ensure the app is initialized with Supabase settings.

```bash
cd app
flutter pub get
flutter run
```

If you use environment variables for local dev, keep the Supabase URL and key in the expected config file or build flags used by the app.

---

## Step 5: Configure Backend Environment

Create `backend/.env` from `backend/.env.example` and set values similar to:

```env
PORT=3000
NODE_ENV=development

SUPABASE_URL=your_supabase_project_url
SUPABASE_SERVICE_ROLE_KEY=your_service_role_key
SUPABASE_ANON_KEY=your_anon_key

GEMINI_API_KEY=your_gemini_api_key
GEMINI_MODEL=gemini-3.1-flash-lite
SARVAM_API_KEY=your_sarvam_key
```

Do not commit secret values to Git.

---

## Step 6: Run the Backend

```bash
cd backend
npm install
npm run dev
```

The backend should expose a health check and the API routes described in `docs/api_documentation.md`.

---

## Step 7: Deployment

Recommended deployment shape:

- Flutter app distributed through your chosen platform
- Backend deployed to Cloud Run or another container host
- Supabase managing authentication, tables, policies, and storage
- Secrets injected through the deployment platform, not stored in source control

---

## Notes

- The old Firebase workflow is no longer the primary setup path.
- If Firebase files remain in the repo, treat them as legacy migration artifacts.
- Keep documentation in sync as the schema and deployment flow evolve.
