import { GoogleGenerativeAI } from '@google/generative-ai';
import dotenv from 'dotenv';
dotenv.config();

const GEMINI_API_KEY = process.env.GEMINI_API_KEY || '';
const GEMINI_MODEL = process.env.GEMINI_MODEL || 'gemini-3.1-flash-lite';

export interface TriageResult {
  patientSummary: string;
  symptoms: string[];
  vitals: { [key: string]: string | number };
  severity: string;
  riskScore: number;
  riskCategory: 'Green' | 'Yellow' | 'Orange' | 'Red';
  suggestedAction: string;
  doctorRequired: boolean;
  emergencyRequired: boolean;
  ambulanceRecommendation: boolean;
  followUpTime: string;
  medicalNotes: string;
  confidenceScore: number;
}

export class GeminiService {
  private static genAI = new GoogleGenerativeAI(GEMINI_API_KEY);
  private static model = GeminiService.genAI.getGenerativeModel({ model: GEMINI_MODEL });

  private static async sleep(ms: number): Promise<void> {
    return new Promise((resolve) => setTimeout(resolve, ms));
  }

  private static isTransientGeminiError(error: unknown): boolean {
    const err = error as { status?: number; message?: string; errorDetails?: Array<{ retryDelay?: string }> };
    const message = (err.message || '').toLowerCase();
    return (
      err.status === 503 ||
      err.status === 429 ||
      message.includes('503') ||
      message.includes('429') ||
      message.includes('high demand') ||
      message.includes('temporarily unavailable') ||
      message.includes('quota')
    );
  }

  private static async generateContentWithRetry(
    prompt: string,
    generationConfig: { temperature: number; maxOutputTokens: number; responseMimeType?: string },
    retries = 3,
    delayMs = 1000,
  ): Promise<any> {
    try {
      return await GeminiService.model.generateContent({
        contents: [{ role: 'user', parts: [{ text: prompt }] }],
        generationConfig,
      });
    } catch (error) {
      if (retries > 0 && GeminiService.isTransientGeminiError(error)) {
        console.warn(`Gemini transient error. Retrying in ${delayMs}ms... (${retries} attempts left)`);
        await GeminiService.sleep(delayMs);
        return GeminiService.generateContentWithRetry(prompt, generationConfig, retries - 1, delayMs * 2);
      }
      throw error;
    }
  }

  /**
   * Analyzes a raw transcript from an ASHA worker and returns a structured triage JSON.
   */
  static async analyzeTranscript(transcript: string): Promise<TriageResult> {
    const prompt = `
      You are an AI Medical Triage Assistant operating under India's ASHA and PHC protocols.
      You MUST NOT diagnose diseases. Your sole purpose is to perform medical triage.

      Analyze the following transcript from an ASHA worker:
      ---
      TRANSCRIPT:
      "${transcript}"
      ---

      Based on the transcript, extract the information and provide a structured JSON response EXACTLY matching this format:
      {
        "patientSummary": "Brief 1 sentence summary",
        "symptoms": ["symptom1", "symptom2"],
        "vitals": { "temperature": 103, "bloodPressure": "150/95" },
        "severity": "Low/Medium/High/Critical",
        "riskScore": 1-10,
        "riskCategory": "Green" | "Yellow" | "Orange" | "Red",
        "suggestedAction": "PHC Protocol action to take",
        "doctorRequired": true/false,
        "emergencyRequired": true/false,
        "ambulanceRecommendation": true/false,
        "followUpTime": "e.g., 24 hours",
        "medicalNotes": "Any specific risks noted",
        "confidenceScore": 0.0-1.0
      }

      Risk Category Rules:
      - Green: Minor illness, home care.
      - Yellow: Needs PHC review, fever, mild pain.
      - Orange: Urgent, severe pain, very high fever, pregnancy complications.
      - Red: Emergency, chest pain, breathing difficulty, stroke symptoms, unconscious.

      Output ONLY valid JSON. Nothing else.
    `;

    try {
      if (!GEMINI_API_KEY) {
        throw new Error("Missing GEMINI_API_KEY");
      }

      const result = await GeminiService.generateContentWithRetry(prompt, {
        temperature: 0.1,
        maxOutputTokens: 1000,
        responseMimeType: 'application/json',
      });

      const response = result.response;
      const jsonString = response.text().trim();
      const parsedJson = JSON.parse(jsonString) as TriageResult;
      
      return parsedJson;

    } catch (error) {
      console.error("Gemini Triage Error:", error);
      throw new Error(`Failed to process transcript with Gemini: ${error}`);
    }
  }

  /**
   * For the WhatsApp bot chatting with the family. Keep it extremely safe.
   */
  static async generateChatResponse(inboundMessage: string, patientHistoryContext: string): Promise<string> {
    try {
      const chatPrompt = `
        You are ASHA Saathi, a friendly health assistant answering family queries on WhatsApp. 
        Speak naturally in Hindi. You MUST NOT diagnose. 
        Give general hydration, rest, and doctor suggestions based on the context. 
        If it sounds like an emergency (chest pain, breathing), urge them to act immediately.

        Context: ${patientHistoryContext}
        
        Family Message: ${inboundMessage}
      `;

      const result = await GeminiService.generateContentWithRetry(chatPrompt, {
        temperature: 0.4,
        maxOutputTokens: 500,
      });

      return result.response.text().trim() || 'Maaf karein, abhi network problem hai. Please PHC Doctor ko contact karein.';

    } catch (e) {
      console.error("Gemini Chat Error:", e);
      return 'Maaf karein, abhi network problem hai. Please PHC Doctor ko contact karein.';
    }
  }
}
