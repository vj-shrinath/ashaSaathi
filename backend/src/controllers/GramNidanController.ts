import { Request, Response } from 'express';
import axios from 'axios';
import { SarvamService } from '../services/SarvamService';
import { GramNidanService } from '../services/GramNidanService';
import { supabase, now } from '../config/supabase';

const UUID_REGEX = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const isValidUuid = (val: string | undefined): val is string =>
  typeof val === 'string' && UUID_REGEX.test(val);

export class GramNidanController {
  /**
   * POST /api/v1/visit/gramnidan
   * Flutter sends: { audioUrl, registerType, visitId?, patientId?, patientName?, ashaId, ashaName? }
   * Returns: { transcript, filledModules: { moduleId: { fieldId: value } }, hasWarnings }
   *
   * Flow:
   *   1. Download audio from Supabase Storage signed URL
   *   2. Sarvam AI → transcript
   *   3. Claude GramNidan → fill all 12 module fields (selective)
   *   4. Save to Supabase `gramnidan_registers` table
   *   5. Return structured JSON to Flutter
   */
  static async fillRegisters(req: Request, res: Response): Promise<void> {
    try {
      const {
        audioUrl,
        registerType = 'general',
        visitId,
        patientId,
        patientName = 'Unknown',
        ashaId,
        ashaName = 'ASHA Worker',
      } = req.body as {
        audioUrl?: string;
        registerType?: string;
        visitId?: string;
        patientId?: string;
        patientName?: string;
        ashaId?: string;
        ashaName?: string;
      };

      if (!audioUrl) {
        res.status(400).json({ status: 'error', message: 'audioUrl is required.' });
        return;
      }
      if (!ashaId || !isValidUuid(ashaId)) {
        res.status(400).json({ status: 'error', message: 'A valid ashaId UUID is required.' });
        return;
      }

      console.log(`[GRAMNIDAN] registerType=${registerType}, patient=${patientId ?? 'none'}, asha=${ashaId}`);

      // ── Step 1: Download audio ───────────────────────────────────────────────
      const audioResponse = await axios.get<ArrayBuffer>(audioUrl, {
        responseType: 'arraybuffer',
        timeout: 30000,
      });
      const audioBuffer = Buffer.from(audioResponse.data);
      const contentType = (audioResponse.headers['content-type'] as string) || 'audio/m4a';
      console.log(`[GRAMNIDAN] Downloaded audio: ${audioBuffer.length} bytes`);

      // ── Step 2: Sarvam STT ────────────────────────────────────────────────────
      const transcript = await SarvamService.transcribeAudio(audioBuffer, contentType);
      if (!transcript || !transcript.trim()) {
        res.status(422).json({ status: 'error', message: 'No speech detected in the audio note.' });
        return;
      }
      console.log(`[GRAMNIDAN] Transcript: "${transcript.slice(0, 100)}..."`);

      // ── Step 3: GramNidan AI Fill ─────────────────────────────────────────────
      const gramNidanResult = await GramNidanService.fillFromTranscript(transcript, registerType);
      console.log(`[GRAMNIDAN] Filled modules: ${Object.keys(gramNidanResult.filledModules).join(', ')}`);

      // ── Step 4: Save to Supabase ──────────────────────────────────────────────
      const registerId = crypto.randomUUID();
      const timestamp = now();

      const { error: dbErr } = await supabase.from('gramnidan_registers').insert({
        id: registerId,
        asha_id: ashaId,
        patient_id: patientId && isValidUuid(patientId) ? patientId : null,
        patient_name: patientName,
        register_type: registerType,
        transcript,
        module_data: gramNidanResult.filledModules,
        is_warning: gramNidanResult.hasWarnings,
        submitted_to_tho: false,
        created_at: timestamp,
        updated_at: timestamp,
      });

      if (dbErr) {
        // Log but don't fail — the fill result is still useful to Flutter
        console.error('[GRAMNIDAN] DB insert error:', dbErr.message);
      } else {
        console.log(`[GRAMNIDAN] Saved to Supabase: registerId=${registerId}`);
      }

      // ── Step 5: Return to Flutter ─────────────────────────────────────────────
      res.status(200).json({
        status: 'success',
        registerId,
        transcript,
        registerType,
        filledModules: gramNidanResult.filledModules,
        hasWarnings: gramNidanResult.hasWarnings,
      });

    } catch (error) {
      const err = error as Error;
      console.error('[GRAMNIDAN] Controller error:', err.stack || err.message);
      res.status(500).json({ status: 'error', message: err.message });
    }
  }

  /**
   * POST /api/v1/visit/gramnidan/submit-tho
   * Marks a register as submitted to THO inbox.
   * Body: { registerId, pdfUrl? }
   */
  static async submitToTho(req: Request, res: Response): Promise<void> {
    try {
      const { registerId, pdfUrl } = req.body as { registerId?: string; pdfUrl?: string };
      if (!registerId) {
        res.status(400).json({ status: 'error', message: 'registerId is required.' });
        return;
      }

      const { error } = await supabase
        .from('gramnidan_registers')
        .update({
          submitted_to_tho: true,
          pdf_url: pdfUrl ?? null,
          updated_at: now(),
        })
        .eq('id', registerId);

      if (error) throw error;

      res.status(200).json({ status: 'success', message: 'Register submitted to THO inbox.' });
    } catch (error) {
      const err = error as Error;
      res.status(500).json({ status: 'error', message: err.message });
    }
  }
}
