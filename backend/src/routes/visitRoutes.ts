import { Router } from 'express';
import multer from 'multer';
import { VisitController } from '../controllers/VisitController';
import { GramNidanController } from '../controllers/GramNidanController';

const router = Router();

// Multipart upload (original flow — file buffer from ASHA device directly)
const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 10 * 1024 * 1024 }, // 10MB limit
});

// ── Original route: audio file uploaded directly as multipart ──────────────────
router.post('/process-audio', upload.single('audioFile'), VisitController.processAudioVisit);

// ── New Flutter app route: audio already uploaded to Supabase Storage ──────────
// Flutter uploads audio → Supabase Storage → sends audioUrl here
// This route: downloads audio → Sarvam STT → Gemini Triage → saves to Supabase
router.post('/voice', VisitController.processVoiceFromUrl);

// ── GramNidan AI Register Fill ─────────────────────────────────────────────────
// Flutter sends audioUrl → Sarvam STT → Claude fills 12 NHM register fields
// Returns { filledModules: { moduleId: { fieldId: value } } }
router.post('/gramnidan', GramNidanController.fillRegisters);

// ── Mark register as submitted to THO inbox ────────────────────────────────────
router.post('/gramnidan/submit-tho', GramNidanController.submitToTho);

export default router;
