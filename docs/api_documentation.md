# Backend API Documentation

The Node.js + Express backend serves as the orchestration layer between the Flutter client, Gemini, Sarvam voice services where needed, and Supabase.

## Base URL

- Production: `https://api.ashasaathi.com/v1`
- Development: `http://localhost:3000/api/v1`

## Authentication

Most endpoints require a valid Supabase session or a backend-issued auth context. In practice, the Flutter app uses the active Supabase user session and passes the authenticated user context to the backend.

---

## Endpoints

### 1. Process Voice Visit

Used by the Flutter app to submit a voice visit for transcription and triage.

**Endpoint:** `POST /visit/process-audio`

**Payload:**
- `audioFile` or signed audio reference
- `patientId`
- `ashaId`

**Workflow:**
1. Audio is received from the app or fetched from storage.
2. Speech is transcribed using the voice pipeline.
3. Transcript is sent to Gemini for structured triage.
4. Visit, triage, and activity data are saved in Supabase.
5. If needed, the backend creates a doctor alert or emergency event.

**Response:**
```json
{
  "status": "success",
  "visitId": "v_123456",
  "transcription": "Patient Ram Singh...",
  "riskLevel": "Red",
  "isEmergency": true
}
```

### 2. Chat Response

Used when the app needs a Gemini-generated chat-style health response.

**Endpoint:** `POST /chat/respond`

**Payload:**
```json
{
  "message": "Meri maa ko bukhar hai",
  "patientId": "p_123",
  "context": "Recent visit summary..."
}
```

**Workflow:**
1. Backend resolves the patient context from Supabase.
2. Gemini generates a safe, non-diagnostic response.
3. The UI shows the result in a chat-style thread.

### 3. Trigger Emergency Protocol

Fallback endpoint for urgent manual escalation.

**Endpoint:** `POST /emergency/trigger`

**Payload:**
```json
{
  "patientId": "p_123",
  "ashaId": "a_456",
  "lat": 28.7041,
  "lng": 77.1025
}
```

**Workflow:**
1. Backend writes an emergency event to Supabase.
2. A doctor alert is created if the role flow requires it.
3. The doctor dashboard reflects the urgent state.

---

## Active Service Integrations

### Gemini

- Used for triage and safe health chat responses
- Returns structured JSON for visit analysis

### Supabase

- Authentication
- Database
- Storage
- Role-based access control

### Sarvam

- Used where speech-to-text or voice output is part of the workflow

## Notes

- The current product does not use WhatsApp as a live integration path.
- The app UI is designed to feel familiar to users who know WhatsApp.
- The backend should continue to return structured responses that are easy for the Flutter app to render.
