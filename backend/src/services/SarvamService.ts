import axios from 'axios';
import FormData from 'form-data';
import dotenv from 'dotenv';
dotenv.config();

const SARVAM_API_URL_SAARAS = 'https://api.sarvam.ai/speech-to-text';
const SARVAM_API_URL_BULBUL = 'https://api.sarvam.ai/text-to-speech';
const API_KEY = process.env.SARVAM_API_KEY || '';

// Sarvam accepts specific MIME types; map common ones
function mapMimeForSarvam(mimetype: string): string {
  const m = mimetype.toLowerCase();
  if (m === 'audio/m4a' || m === 'audio/mp4') return 'audio/x-m4a';
  if (m === 'audio/aac') return 'audio/x-aac';
  if (m === 'audio/ogg' || m === 'audio/opus') return 'audio/ogg';
  if (m === 'audio/wav' || m === 'audio/x-wav' || m === 'audio/pcm_s16le' || m === 'audio/l16' || m === 'audio/raw') return 'audio/wav';
  if (m === 'audio/flac') return 'audio/x-flac';
  if (m === 'audio/webm' || m === 'video/webm') return 'audio/webm';
  // fallback - sarvam also accepts application/octet-stream
  return 'application/octet-stream';
}

export class SarvamService {
  /**
   * Converts a WhatsApp or App voice note to Hindi Text using Sarvam Saaras.
   * @param audioBuffer Buffer of the audio file
   * @param mimetype Mimetype (e.g. 'audio/wav', 'audio/ogg', 'audio/m4a')
   */
  static async transcribeAudio(audioBuffer: Buffer, mimetype: string): Promise<string> {
    if (!API_KEY) throw new Error("Missing SARVAM_API_KEY");

    try {
      const form = new FormData();
      // Map mimetype to one Sarvam accepts
      const sarvamMime = mapMimeForSarvam(mimetype);
      const ext = sarvamMime.split('/')[1] || 'wav';
      
      form.append('file', audioBuffer, {
          filename: `voice_note.${ext}`,
          contentType: sarvamMime
      });
      form.append('language_code', 'hi-IN');
      form.append('model', 'saaras:v3');

      const response = await axios.post(SARVAM_API_URL_SAARAS, form, {
        headers: {
          ...form.getHeaders(),
          'API-Subscription-Key': API_KEY
        },
        timeout: 60000,
      });

      return response.data?.transcript || '';
    } catch (error: any) {
      // Log full Sarvam error response for debugging
      console.error("Sarvam STT Error:", {
        status: error.response?.status,
        data: error.response?.data,
        message: error.message,
        mimetype,
        sarvamMime: mapMimeForSarvam(mimetype),
        bufferSize: audioBuffer.length,
      });
      throw new Error(`Speech to Text failed: ${error.response?.data?.error?.message || error.message}`);
    }
  }

  /**
   * Generates a Hindi Audio Buffer from Text using Sarvam Bulbul.
   * Useful for responding to Family via WhatsApp Voice Notes.
   */
  static async generateAudio(text: string): Promise<Buffer> {
    if (!API_KEY) throw new Error("Missing SARVAM_API_KEY");

    try {
      const response = await axios.post(
        SARVAM_API_URL_BULBUL, 
        {
          inputs: [text],
          target_language_code: 'hi-IN',
          speaker: 'meera', // Hindi female voice matching 'ASHA' persona
          pitch: 0,
          pace: 1.0,
          loudness: 1.5,
          speech_sample_rate: 8000
        },
        {
          headers: {
            'Content-Type': 'application/json',
            'API-Subscription-Key': API_KEY
          },
          responseType: 'arraybuffer' // Need the audio binary
        }
      );

      return Buffer.from(response.data, 'binary');
    } catch (error: any) {
      console.error("Sarvam TTS Error:", error.response?.data?.toString() || error.message);
      throw new Error(`Text to Speech failed: ${error.message}`);
    }
  }
}
