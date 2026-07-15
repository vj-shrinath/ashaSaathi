# Deployment & Testing Strategy

## 1. Directory & Monorepo Structure

```bash
/asha_saathi_prod
  /app           # Flutter application
  /backend       # Node.js Express API server
  /docs          # Architecture and setup docs
```

## 2. Testing Strategy

The current stack should be tested in layers:

### Backend

- Unit tests for Gemini prompt handling, response parsing, and Supabase writes
- Integration tests for API routes against a test Supabase project
- End-to-end tests for the voice visit flow and emergency flow

### Frontend

- Unit tests for service classes and state logic
- Widget tests for chat-style UI, dashboards, and form validation
- Integration tests for the major flows: login, patient creation, voice visit, and doctor review

## 3. Deployment Strategy

### Backend

Deploy the Node.js backend as a containerized service.

- Run tests on every change
- Build the backend image
- Inject secrets through the host platform
- Point the backend to the production Supabase project

### Frontend

- Build and ship the Flutter app through the target platform
- Keep the app pointed at the correct backend URL and Supabase environment

### Database and Storage

- Manage schema changes through Supabase migrations
- Keep row-level security policies under version control
- Review indexes and storage policies alongside feature changes

## 4. Release Checklist

- Verify auth flows work in staging
- Verify voice visit submission works end to end
- Verify Gemini output is structured and safe
- Verify Supabase writes happen in the expected tables
- Verify dashboards render the correct role-based data

## Notes

- Replace any old Firebase, Firestore, or WhatsApp deployment steps with the active Supabase-based flow.
- Keep tests aligned with the actual runtime architecture.
