# ASHA Saathi AI Security Checklist

## Data Protection

- [ ] Patient data stored in Supabase with strict row-level security
- [ ] Role-based access control enforced for ASHA, doctor, and admin users
- [ ] Backend service role used only for approved server-side writes
- [ ] Client-side writes limited to allowed tables and rows
- [ ] Audit logs captured for key actions

## Authentication

- [ ] Supabase Auth configured for all active user sessions
- [ ] Role metadata stored and validated consistently
- [ ] Frontend routing respects authentication state

## API Security

- [ ] CORS configured appropriately on the backend
- [ ] Environment variables used for all API keys and secrets
- [ ] Secrets excluded from Git
- [ ] Backend served over HTTPS in production

## AI Safety

- [ ] Gemini prompts prohibit diagnosis and keep output triage-focused
- [ ] Structured output validated before saving or rendering
- [ ] Temperature and retries tuned for stable behavior
- [ ] Confidence and risk fields stored for review

## Compliance Alignment

- [ ] Minimal necessary data collection followed
- [ ] Access patterns documented for patient records
- [ ] Data retention rules reviewed for production
- [ ] Regional deployment choices documented

## Infrastructure

- [ ] Tables and indexes documented and maintained
- [ ] Storage policies reviewed for uploaded files
- [ ] Deployment pipeline keeps secrets out of source control
- [ ] Monitoring and audit logging are enabled

## Notes

- Treat the old Firebase and WhatsApp-specific security notes as legacy unless they are still in use.
- Update this checklist whenever the Supabase schema or backend responsibilities change.
