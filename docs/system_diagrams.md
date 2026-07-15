# System Diagrams

## 1. Core Data Model

```mermaid
erDiagram
    USERS ||--o{ PATIENTS : manages
    USERS ||--o{ VISITS : records
    USERS ||--o{ DOCTOR_ALERTS : receives
    PATIENTS ||--o{ VISITS : has
    PATIENTS ||--o{ EMERGENCY_EVENTS : triggers
    VISITS ||--|| TRIAGE_REPORTS : generates
    TRIAGE_REPORTS ||--o{ DOCTOR_ALERTS : may_create
```

## 2. Voice Workflow

```mermaid
sequenceDiagram
    participant ASHA as ASHA Worker (Flutter App)
    participant Backend as Node.js Backend
    participant Storage as Supabase Storage
    participant AI as Gemini
    participant DB as Supabase Postgres
    participant Doctor as Doctor UI

    ASHA->>Backend: Submit voice note or visit details
    Backend->>Storage: Save or fetch audio file if needed
    Backend->>AI: Send transcript for triage analysis
    AI-->>Backend: Structured triage JSON
    Backend->>DB: Save visit, triage, and activity records

    alt High risk
        Backend->>DB: Create doctor alert or emergency event
        DB-->>Doctor: Doctor dashboard reflects urgent case
    else Routine case
        Backend->>DB: Update patient timeline and summary
    end

    Backend-->>ASHA: Return processed result
```

## 3. Familiar Chat-Style UI

```mermaid
flowchart LR
    A[ASHA or Doctor opens app] --> B[WhatsApp-like conversation UI]
    B --> C[Voice input, chat bubbles, quick actions]
    C --> D[Backend writes to Supabase]
    D --> E[Role-based dashboards]
```

## Notes

- The current product does not depend on WhatsApp integration.
- The UI borrows familiar chat patterns so users feel comfortable.
- Gemini is the active AI layer for triage and chat behavior.
- Supabase is the active source of truth for auth, data, and storage.
