# ASHA Saathi AI

ASHA Saathi AI is a healthcare support platform for ASHA workers and doctors. The current implementation is built around a voice-first workflow, with Supabase for authentication, database, and storage, and Gemini for triage and chat assistance.

The product keeps a WhatsApp-like experience in the UI for familiarity, but it does not rely on WhatsApp integration as a core backend dependency.

## Current Architecture

```text
asha_saathi_prod/
|- app/                     Flutter client
|- backend/                 Node.js + TypeScript API
|- docs/                    Architecture, schema, setup, and deployment notes
|- firestore.rules          Legacy Firebase file, not part of the active Supabase plan
|- firestore.indexes.json   Legacy Firebase file, not part of the active Supabase plan
`- README.md
```

### Flutter App

The Flutter app lives in `app/` and uses Riverpod, GoRouter, Supabase, and reusable presentation widgets.

```text
app/lib/
|- core/
|  |- models/
|  |- routing/
|  |- services/
|  `- theme/
|- presentation/
|  |- screens/
|  `- widgets/
`- main.dart
```

### Backend

The backend lives in `backend/` and is a TypeScript Express service.

```text
backend/src/
|- config/
|- controllers/
|- middleware/
|- routes/
|- services/
`- index.ts
```

## Active Stack

- Flutter 3
- Riverpod
- GoRouter
- Supabase Auth
- Supabase Postgres
- Supabase Storage
- Node.js + Express + TypeScript
- Gemini for triage and chat
- Sarvam for speech features where needed
- Google Maps Platform for location-related flows

## How It Works

1. The Flutter app captures user input, patient data, and voice notes.
2. The backend receives requests and coordinates AI and storage actions.
3. Voice is transcribed and analyzed through the Gemini-based pipeline.
4. Records are written to Supabase tables and files are stored in Supabase Storage.
5. The UI presents the flow in a familiar WhatsApp-like style without requiring actual WhatsApp integration.

## Project Plan

### In Progress

- Finalizing the Supabase-backed data model
- Completing the Gemini triage/chat flows
- Aligning all app screens with the new architecture
- Cleaning up legacy Firestore and Claude references

### Next Steps

- Finish backend validation and error handling
- Tighten role-based access in Supabase
- Connect all UI flows to live Supabase tables
- Add and expand tests for the new stack
- Update deployment docs for Supabase and Gemini

### Longer-Term

- Improve dashboards for ASHA, doctor, and admin roles
- Add observability and audit logging
- Polish offline and sync behavior
- Keep documentation aligned with implementation

## Quick Start

### Backend

```bash
cd backend
npm install
npm run dev
```

### Flutter App

```bash
cd app
flutter pub get
flutter run
```

## Documentation

Start with:

- `docs/api_documentation.md`
- `docs/system_diagrams.md`
- `docs/firestore_schema.md`
- `docs/firebase_setup_guide.md`
- `docs/security_checklist.md`
- `docs/testing_deployment_strategy.md`

## Security Notes

- Supabase auth should be the source of truth for user sessions
- Secrets must stay in environment variables
- AI output is triage support only, not diagnosis
- Patient data must be protected by role-based access and storage policies

## License

Proprietary - ASHA Saathi AI (c) 2026
