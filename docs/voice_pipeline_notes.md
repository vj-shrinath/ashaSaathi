# Voice Pipeline Notes

This pipeline depends on a valid signed-in Supabase user and a working AI chain.

## Required identity

- The Flutter app must send the signed-in Supabase user ID as `ashaId`.
- Do not use placeholder values like `asha_worker` or `current_user_id`.
- The backend `/api/v1/visit/voice` route requires `ashaId` to be a valid UUID.
- The backend writes that UUID to both `asha_id` and `owner_id` on `visits`.

## Common failure modes

- Missing or invalid `ashaId`:
  - The backend should return a 400 before calling Sarvam or Gemini.
- Long-running request with no follow-up logs:
  - Check `SarvamService.transcribeAudio(...)`.
  - Check `GeminiService.analyzeTranscript(...)`.
  - Check external API availability and credentials.
- Timeout in the app:
  - `BackendApiService.transcribeAndAnalyze(...)` currently waits up to 3 minutes.
  - If the request still fails earlier, inspect any higher-level UI timeout or cancellation.

## Debug checkpoints

1. Confirm the app user is signed in.
2. Confirm `ashaId` is a UUID.
3. Confirm backend logs show `[VOICE-URL] visitId=...`.
4. Confirm Sarvam returns a transcript.
5. Confirm Gemini returns JSON triage.
6. Confirm Supabase inserts succeed.
