import Anthropic from '@anthropic-ai/sdk';
import dotenv from 'dotenv';
dotenv.config();

const anthropic = new Anthropic({
  apiKey: process.env.ANTHROPIC_API_KEY || '',
});

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

export class ClaudeService {
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
      if (!process.env.ANTHROPIC_API_KEY) {
        throw new Error("Missing Anthropic API Key");
      }

      const msg = await anthropic.messages.create({
        model: 'claude-3-5-sonnet-20240620',
        max_tokens: 1000,
        temperature: 0.1, // Low temperature for consistent JSON output
        system: "You are a rigid JSON API. Never output natural language before or after the JSON.",
        messages: [
          { role: 'user', content: prompt }
        ]
      });

      // Anthropic API message content returning as text block
      const contentBlock = msg.content.find(c => c.type === 'text');
      if (!contentBlock || contentBlock.type !== 'text') {
          throw new Error("Invalid response format from Claude");
      }

      const jsonString = contentBlock.text.trim();
      const parsedJson = JSON.parse(jsonString) as TriageResult;
      
      return parsedJson;

    } catch (error) {
      console.error("Claude Triage Error:", error);
      throw new Error(`Failed to process transcript with Claude: ${error}`);
    }
  }

  /**
   * For the WhatsApp bot chatting with the family. Keep it extremely safe.
   */
  static async generateChatResponse(inboundMessage: string, patientHistoryContext: string): Promise<string> {
      try {
          const msg = await anthropic.messages.create({
              model: 'claude-3-haiku-20240307',
              max_tokens: 500,
              temperature: 0.4,
              system: "You are ASHA Saathi, a friendly health assistant answering family queries on WhatsApp. Speak naturally in Hindi. You MUST NOT diagnose. Give general hydration, rest, and doctor suggestions based on the context. If it sounds like an emergency (chest pain, breathing), urge them to act immediately.",
              messages: [
                { role: 'user', content: `Context: ${patientHistoryContext}\n\nFamily Message: ${inboundMessage}` }
              ]
          });
          const contentBlock = msg.content.find(c => c.type === 'text');
          return contentBlock?.type === 'text' ? contentBlock.text : 'Sorry, I cannot process this right now.';
      } catch(e) {
          console.error(e);
          return 'Maaf karein, abhi network problem hai. Please PHC Doctor ko contact karein.';
      }
  }
}
