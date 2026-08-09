import { GoogleGenerativeAI } from '@google/generative-ai';
import dotenv from 'dotenv';
dotenv.config();

const GEMINI_API_KEY = process.env.GEMINI_API_KEY || '';
const GEMINI_MODEL = process.env.GEMINI_MODEL || 'gemini-3.1-flash-lite';
const genAI = new GoogleGenerativeAI(GEMINI_API_KEY);
const model = genAI.getGenerativeModel({ model: GEMINI_MODEL });

// ─── All 12 GramNidan module field specs ─────────────────────────────────────
// Ported from Demo-9 gramnidanModules array. These are sent to Claude so it
// knows which field IDs to fill — it only fills fields actually mentioned.
export const GRAMNIDAN_MODULES = [
  {
    id: 'village',
    title: 'Village Survey / Master Household Register',
    fieldIds: ['houseno','mukhia','members','mobile','toilet','category','pmjay','palliative',
      'abha','rationcard','watersource','housetype','ancflag','pncflag','childrencount',
      'eligiblecouple','disability','migration','tbcase','leprosycase','othercase','diseasename','diseasestatus'],
  },
  {
    id: 'ec',
    title: 'Eligible Couple Register',
    fieldIds: ['couple','age','children','youngestchildage','method','sterilization','lmpdate','uptdate','upt'],
  },
  {
    id: 'anc',
    title: 'ANC Register — Prenatal Care',
    fieldIds: ['name','rchid','abhaid','mobile','gravida','ancvisits','lmp','edd',
      'bpsys','bpdia','weightkg','motherheight','calcium','hb','urineprotein','urinesugar',
      'bloodgroup','rhflag','ogtt','sicklecell','infectionscreen','usgstatus','labremarks',
      'abdomexam','tt1','tt2','ttbooster','ifagiven','ifadose','tabletcount','albendazole',
      'hrphighbp','hrpanemia','hrphb','hrprh','hrpdiabetes','hrptwins','hrp'],
  },
  {
    id: 'delivery',
    title: 'Delivery & PNC Register',
    fieldIds: ['mothername','datetime','place','deliverytype','conductedby','outcome',
      'newborngender','babyweight','pncday1','pncday3','pncday7','pncday14','pncday21',
      'pncday28','pncday42','motherhealth','pph','eclampsia','referralinst','jsy'],
  },
  {
    id: 'hbnc',
    title: 'HBNC Register — Home-Based Newborn Care (0-28 days)',
    fieldIds: ['namewt','sex','mothername','bcgbirth','opv0','hepbbirth',
      'hbncday1','hbncday3','hbncday7','hbncday14','hbncday21','hbncday28','hbncday42',
      'temp','cord','jaundice','bf','danger','urine','stool','congenital','sncu'],
  },
  {
    id: 'hbyc',
    title: 'HBYC Register — Home-Based Young Child Care (3-15 months)',
    fieldIds: ['nameage','visitmonth','feeding','ifa','muac','milestones',
      'wt3','wt6','wt9','wt12','wt15','deworming','ors','zinc','referral'],
  },
  {
    id: 'child',
    title: 'Child Health + Vaccination Register (HBYC + UIP)',
    fieldIds: ['nameinfo','dob','village','ashaname','weight','weightstatus','height',
      'muac','nutritionstatus','diet','breastfeeding','bcg','opv1','opv2','opv3',
      'dpt1','dpt2','dpt3','mr','dptbooster','opvbooster','vita','deworming','sam','remarks'],
  },
  {
    id: 'cbac',
    title: 'CBAC Register — NCD Screening (30+)',
    fieldIds: ['nameage','gender','abhaid','mobile','tobacco','alcohol','waist',
      'familyhistory','activity','ncdrisk','chroniccough','oralulcer','breastlump',
      'footnumb','cookingfuel','occupation','portaloutput','remarks'],
  },
  {
    id: 'ncd',
    title: 'NCD Tracking Register — BP / Sugar (MH Protocol)',
    fieldIds: ['nameage','gender','village','ashaname','mobile','condition',
      'bpreading','mhprotocol','medicine','mhstep','compliance','headache',
      'chestpain','vision','breathlessness','bsl','diabetes','lastphc','nextvisit','refer','remarks'],
  },
  {
    id: 'idsp',
    title: 'IDSP / Communicable Disease Surveillance',
    fieldIds: ['hascase','diseases','nikshayid','sputumdate','dotsstatus','nikshaypmy',
      'nlepid','skinpatchdate','testdate','testoutcome','onsetdate','contacttracing','outbreakflag'],
  },
  {
    id: 'birthdeath',
    title: 'Birth & Death Register',
    fieldIds: ['type','personname','dateofbirth','dateofregistration','placeofbirth',
      'parentnames','dateofdeath','causeofdeath','reportedby','remarks'],
  },
  {
    id: 'claim',
    title: 'JSY / JSSK Claim Register',
    fieldIds: ['beneficiaryname','abhaid','mobile','deliverydate','deliveryplace',
      'jsystatus','amount','paymentdate','remarks'],
  },
];

export interface GramNidanFillResult {
  moduleId: string;
  fields: Record<string, string>;
}

export interface GramNidanResult {
  transcript: string;
  registerType: string;
  filledModules: Record<string, Record<string, string>>;
  hasWarnings: boolean;
}

export class GramNidanService {
  /**
   * Takes a voice transcript + register type, sends ALL 12 module field specs
   * to Claude, gets back a structured JSON of only the fields mentioned.
   * Claude is instructed to be selective — most notes will touch 1-3 modules.
   */
  static async fillFromTranscript(
    transcript: string,
    registerType: string
  ): Promise<GramNidanResult> {
    const moduleSpecs = GRAMNIDAN_MODULES.map(m => ({
      id: m.id,
      title: m.title,
      fieldIds: m.fieldIds,
    }));

    const prompt = `You are GramNidan AI, filling government ASHA health registers for rural Maharashtra, India.

ASHA VOICE NOTE (transcript): "${transcript}"

The ASHA was doing a "${registerType}" visit. People often mention cross-cutting health details (BP, danger signs, feeding) that belong to OTHER registers too.

Below are ALL 12 available register modules with their field IDs. ONLY include a module/field if the voice note actually mentions something relevant to it. Be very selective — most voice notes will touch only 1-3 modules. Do NOT invent data.

MODULES:
${moduleSpecs.map(m => `- ${m.id} (${m.title}): [${m.fieldIds.join(', ')}]`).join('\n')}

RULES:
1. Values must be VERY SHORT (under 6 words each)
2. Use "⚠️" prefix ONLY for concerning/abnormal values (e.g. "⚠️ 160/110 mmHg")
3. Use "✅" suffix for explicitly normal/good values (e.g. "Regular ✅")
4. Use "— (fill karo)" for clearly missing data — but only include fields you have info for
5. Return ONLY a compact JSON object, no markdown, no backticks, no explanation:
{"moduleId":{"fieldId":"short value","fieldId2":"short value"}}

If nothing in the transcript is relevant to any module, return: {}`;

    try {
      if (!GEMINI_API_KEY) {
        throw new Error('Missing Gemini API Key');
      }

      const result = await model.generateContent({
        contents: [{ role: 'user', parts: [{ text: prompt }] }],
        systemInstruction: "You are a rigid JSON API for Indian rural health records. Never output natural language. Output ONLY the raw JSON object.",
        generationConfig: {
          temperature: 0.1,
          maxOutputTokens: 2000,
        }
      });

      const response = result.response;
      let rawText = response.text().trim();
      // Robustly extract JSON even if model adds fences
      rawText = rawText.replace(/```json|```/g, '').trim();
      const jsonStart = rawText.indexOf('{');
      const jsonEnd = rawText.lastIndexOf('}');
      if (jsonStart === -1 || jsonEnd === -1) {
        // No modules filled — return empty
        return { transcript, registerType, filledModules: {}, hasWarnings: false };
      }
      rawText = rawText.slice(jsonStart, jsonEnd + 1);

      const parsed = JSON.parse(rawText) as Record<string, Record<string, string>>;

      // Detect if any warning values exist
      const hasWarnings = Object.values(parsed).some(fields =>
        Object.values(fields).some(v => typeof v === 'string' && v.includes('⚠️'))
      );

      return {
        transcript,
        registerType,
        filledModules: parsed,
        hasWarnings,
      };
    } catch (error) {
      console.error('[GramNidan] Gemini fill error:', error);
      // Return empty rather than throwing — ASHA can fill manually
      return {
        transcript,
        registerType,
        filledModules: {},
        hasWarnings: false,
      };
    }
  }
}
