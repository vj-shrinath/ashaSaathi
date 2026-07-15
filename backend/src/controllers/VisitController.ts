import { Request, Response } from 'express';
import axios from 'axios';
import { SarvamService } from '../services/SarvamService.js';
import { GeminiService, type TriageResult } from '../services/GeminiService.js';
import { WhatsAppService } from '../services/WhatsAppService.js';
import { supabase, now, TABLES } from '../config/supabase.js';

const SYSTEM_SENDER_ID = '00000000-0000-0000-0000-000000000000';
const UUID_REGEX = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

const isValidUuid = (val: string | undefined): val is string => {
  return typeof val === 'string' && UUID_REGEX.test(val);
};

const getValidUuid = (val: string | undefined, fallback: string = SYSTEM_SENDER_ID): string => {
  return isValidUuid(val) ? val : fallback;
};

const toActivityMetadata = (triage: TriageResult, patientId: string, visitId: string) => ({
  patientId,
  visitId,
  riskCategory: triage.riskCategory,
  riskScore: triage.riskScore,
  severity: triage.severity,
  doctorRequired: triage.doctorRequired,
  emergencyRequired: triage.emergencyRequired,
});

export class VisitController {

  /**
   * Original pipeline: Multipart audio upload -> Sarvam STT -> Claude -> Supabase
   */
  static async processAudioVisit(req: Request, res: Response): Promise<void> {
    try {
      if (!req.file) {
        res.status(400).json({ status: 'error', message: 'No audio file uploaded.' });
        return;
      }

      const { patientId, ashaId } = req.body as { patientId?: string; ashaId?: string };
      if (!patientId || !ashaId) {
        res.status(400).json({ status: 'error', message: 'patientId and ashaId are required.' });
        return;
      }

      const validAshaId = getValidUuid(ashaId);

      const audioBuffer = req.file.buffer;
      const mimeType = req.file.mimetype;
      console.log(`[VISIT] Processing audio for patient=${patientId} asha=${validAshaId}`);

      const transcript = await SarvamService.transcribeAudio(audioBuffer, mimeType);
      console.log(`[VISIT] Transcription: ${transcript}`);

      const triage = await GeminiService.analyzeTranscript(transcript);
      console.log(`[VISIT] Triage result: Risk=${triage.riskCategory}, Score=${triage.riskScore}`);

      const visitId = crypto.randomUUID();
      const riskReportId = crypto.randomUUID();

      // 1. Insert visit
      const { error: visitErr } = await supabase.from(TABLES.VISITS).insert({
        id: visitId,
        patient_id: patientId,
        asha_id: validAshaId,
        timestamp: now(),
        transcribed_text: transcript,
        risk_assessment_id: riskReportId,
      });
      if (visitErr) throw visitErr;

      // 2. Insert risk report
      const { error: riskErr } = await supabase.from(TABLES.TRIAGE_REPORTS).insert({
        id: riskReportId,
        patient_id: patientId,
        visit_id: visitId,
        ...triage,
        created_at: now(),
      });
      if (riskErr) throw riskErr;

      // 3. Update patient risk category
      const { error: patientErr } = await supabase
        .from(TABLES.PATIENTS)
        .update({ current_risk_category: triage.riskCategory, updated_at: now() })
        .eq('id', patientId);
      if (patientErr) throw patientErr;

      // 4. Doctor alerts for urgent cases
      const isUrgent = triage.riskCategory === 'Red' || triage.riskCategory === 'Orange';
      if (isUrgent) {
        const alertId = crypto.randomUUID();
        const { error: alertErr } = await supabase.from(TABLES.DOCTOR_ALERTS).insert({
          id: alertId,
          patient_id: patientId,
          asha_id: validAshaId,
          status: 'Pending',
          timestamp: now(),
          triage_summary: triage.patientSummary,
          category: triage.riskCategory,
        });
        if (alertErr) console.error('[ALERT] Insert failed:', alertErr.message);

        // FCM push notification - use Supabase Edge Function or keep Firebase Admin if needed
        // For now, skip FCM from backend - can be handled via Supabase Edge Functions
      }

      // 5. WhatsApp to family for urgent cases
      if (isUrgent) {
        const { data: patient } = await supabase
          .from(TABLES.PATIENTS)
          .select('name, family_phone_number')
          .eq('id', patientId)
          .single();
        
        if (patient?.family_phone_number && patient?.name) {
          WhatsAppService.sendEmergencyAlert(
            patient.family_phone_number, 
            patient.name, 
            'https://maps.google.com'
          ).catch((e: Error) => console.error('[WhatsApp] Alert failed:', e.message));
        }
      }

      res.status(200).json({ 
        status: 'success', 
        visitId, 
        transcription: transcript, 
        triage 
      });

    } catch (error) {
      const err = error as Error;
      console.error('[VISIT] Pipeline error:', err.message);
      res.status(500).json({ status: 'error', message: err.message });
    }
  }

  /**
   * NEW Flutter App Pipeline:
   * Flutter uploads audio -> Supabase Storage -> sends signed URL here
   * This endpoint: downloads audio -> Sarvam STT -> Claude Triage
   * -> saves to Supabase (visits + messages + triage_reports)
   * -> returns triageResult JSON to Flutter
   */
  static async processVoiceFromUrl(req: Request, res: Response): Promise<void> {
    try {
      const { audioUrl, visitId, patientId, ashaId, patientName, ashaName } = req.body as {
        audioUrl?: string;
        visitId?: string;
        patientId?: string;
        ashaId?: string;
        patientName?: string;
        ashaName?: string;
      };

      if (!audioUrl || !visitId || !patientId) {
        res.status(400).json({
          status: 'error',
          message: 'audioUrl, visitId, and patientId are required.',
        });
        return;
      }

      if (!ashaId || !isValidUuid(ashaId)) {
        res.status(400).json({
          status: 'error',
          message: 'A valid ashaId is required to save the visit.',
        });
        return;
      }

      console.log(`[VOICE-URL] visitId=${visitId}, patient=${patientId}`);

      // Step 1: Download audio from Supabase Storage (signed URL)
      const audioResponse = await axios.get<ArrayBuffer>(audioUrl, {
        responseType: 'arraybuffer',
        timeout: 30000,
      });
      const audioBuffer = Buffer.from(audioResponse.data);
      const contentType = (audioResponse.headers['content-type'] as string) || 'audio/m4a';
      console.log(`[VOICE-URL] Downloaded: ${audioBuffer.length} bytes, mime=${contentType}`);

      // Step 2: Sarvam AI STT
      console.log(`[VOICE-URL] Sending to Sarvam: size=${audioBuffer.length} bytes, mime=${contentType}`);
      const transcript = await SarvamService.transcribeAudio(audioBuffer, contentType);
      if (!transcript || !transcript.trim()) {
        throw new Error('No speech detected in the audio note');
      }
      console.log(`[VOICE-URL] Transcript: "${transcript}"`);

      // Step 3: Gemini AI Triage Analysis
      const triage = await GeminiService.analyzeTranscript(transcript);
      console.log(`[VOICE-URL] Triage: ${triage.riskCategory} (${triage.riskScore}/10)`);

      // Step 4: Write to Supabase
      const reportId = crypto.randomUUID();
      const timestamp = now();

      // Validate and sanitize ashaId for UUID columns
      const validAshaId = ashaId;

      // Ensure visit exists (upsert)
      const visitUpsertData: Record<string, unknown> = {
        id: visitId,
        patient_id: patientId,
        asha_id: validAshaId,
        updated_at: timestamp,
      };
      // Only set owner_id if we have a valid ASHA worker UUID (to avoid FK violation)
      if (isValidUuid(ashaId)) {
        visitUpsertData.owner_id = validAshaId;
      }

      const { error: visitUpsertErr } = await supabase.from(TABLES.VISITS).upsert(visitUpsertData);
      if (visitUpsertErr) throw visitUpsertErr;

      // Insert top-level triage report (Doctor Dashboard feed)
      const { error: reportErr } = await supabase.from(TABLES.TRIAGE_REPORTS).insert({
        id: reportId,
        visit_id: visitId,
        patient_id: patientId,
        patient_name: patientName || 'Unknown',
        asha_id: validAshaId,
        asha_name: ashaName || 'ASHA Worker',
        transcript,
        triage_result: triage,
        created_at: timestamp,
        reviewed_by_doctor: false,
        owner_id: validAshaId,
      });
      if (reportErr) throw reportErr;

      const { error: activityErr } = await supabase.from(TABLES.ACTIVITY_LOGS).insert({
        id: crypto.randomUUID(),
        user_id: validAshaId,
        user_name: ashaName || 'ASHA Worker',
        user_role: 'asha',
        type: 'triage_generated',
        description: `Generated ${triage.riskCategory} triage report for ${patientName || 'patient'}`,
        metadata: toActivityMetadata(triage, patientId, visitId),
        timestamp: timestamp,
        patient_id: patientId,
        visit_id: visitId,
      });
      if (activityErr) console.error('[VOICE-URL] Activity log insert failed:', activityErr.message);

      // Update patient record with latest risk
      const { error: patientUpdateErr } = await supabase
        .from(TABLES.PATIENTS)
        .update({
          risk_category: triage.riskCategory,
          last_message: `Voice report -- ${triage.riskCategory} risk`,
          last_message_time: timestamp,
        })
        .eq('id', patientId);
      if (patientUpdateErr) throw patientUpdateErr;

      console.log(`[VOICE-URL] Supabase saved: report=${reportId}`);

      // Step 5: FCM push for urgent cases (handled via Supabase Edge Functions in production)
      const isUrgent = triage.riskCategory === 'Red' || triage.riskCategory === 'Orange';
      if (isUrgent) {
        console.log(`[VOICE-URL] Urgent case detected: ${triage.riskCategory} - would trigger FCM via Edge Function`);
      }

      res.status(200).json({
        status: 'success',
        visitId,
        transcript,
        triageResult: triage,
        reportId,
      });

    } catch (error) {
      const err = error as Error;
      console.error('[VOICE-URL] Error:', err.stack || err.message);
      res.status(500).json({ status: 'error', message: err.message });
    }
  }
}
