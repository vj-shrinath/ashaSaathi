import { Router } from 'express';
import multer from 'multer';
import { VisitController } from '../controllers/VisitController';

const router = Router();

// Multipart upload (original flow — file buffer from ASHA device directly)
const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 10 * 1024 * 1024 }, // 10MB limit
});

// ── Original route: audio file uploaded directly as multipart ──────────────────
router.post('/process-audio', upload.single('audioFile'), VisitController.processAudioVisit);

// ── New Flutter app route: audio already uploaded to Firebase Storage ──────────
// Flutter uploads audio → Firebase Storage → sends audioUrl here
// This route: downloads audio → Sarvam STT → Claude Triage → saves to Firestore
router.post('/voice', VisitController.processVoiceFromUrl);

export default router;
