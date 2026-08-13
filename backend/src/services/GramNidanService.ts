import { GoogleGenerativeAI } from '@google/generative-ai';
import dotenv from 'dotenv';
dotenv.config();

const GEMINI_API_KEY = process.env.GEMINI_API_KEY || '';
const GEMINI_MODEL = process.env.GEMINI_MODEL || 'gemini-3.1-flash-lite';
const genAI = new GoogleGenerativeAI(GEMINI_API_KEY);
const model = genAI.getGenerativeModel({ model: GEMINI_MODEL });

// ─── All 12 GramNidan module field specs ─────────────────────────────────────
// Ported from actual ASHA Dev Spec. Cloud LLM will use this schema to selectively 
// extract spoken values into rigorous IDs.
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
    title: 'HBNC Register — Home-Based Newborn Care',
    fieldIds: ['namewt','sex','mothername','bcgbirth','opv0','hepbbirth',
      'hbncday1','hbncday3','hbncday7','hbncday14','hbncday21','hbncday28','hbncday42',
      'temp','cord','jaundice','bf','danger','urine','stool','congenital','sncu'],
  },
  {
    id: 'hbyc',
    title: 'HBYC Register — Home-Based Young Child Care',
    fieldIds: ['nameage','visitmonth','feeding','ifa','muac','milestones',
      'wt3','wt6','wt9','wt12','wt15','deworming','orszinc'],
  },
  {
    id: 'child',
    title: 'Child Vaccination (UIP)',
    fieldIds: ['nameinfo','bcg','hepbzero','opvzero','penta1','fipv1','rvv1','pcv1','opv1',
      'penta2','opv2','rvv2','penta3','opv3','fipv2','rvv3','pcv2',
      'mr1','je1','pcvbooster','ipv3','dptbooster1','mr2','je2','opvbooster1','dptbooster2',
      'td10','td16','weightchart','growthbadge'],
  },
  {
    id: 'cbac',
    title: 'CBAC (NCD Screening)',
    fieldIds: ['nameage','gender','abhaid','mobile','habits','waist',
      'familyhistory','activity','score','cough','oralulcer','breastlump',
      'footnumb','fueltype','dustexposure'],
  },
  {
    id: 'ncd',
    title: 'NCD Tracking Register',
    fieldIds: ['nameage','gender','abhaid','diagnosis','diagnoseddate','medication',
      'compliance','cbacfilled','cbacscore','heightcm','weightkg','bmi',
      'tbcase','randomglucose','oralcancer','cervicalcancer','breastcancer','otherscreening',
      'suspectdate','suspectcondition','npcdcsremarks','hb','bpsys','bpdia','lastreading','followup',
      'ccheart','cckidney','cceye','ccfoot','referral'],
  },
  {
    id: 'birthdeath',
    title: 'Birth & Death Register',
    fieldIds: ['eventtype','eventdate','placeofevent','personname',
      'deceasedagegender','cause','deathaudit','certstatus','crsackid'],
  },
  {
    id: 'idsp',
    title: 'Communicable Disease (IDSP)',
    fieldIds: ['diseasetype','patientname','dateofonset','status','testdate'],
  },
  {
    id: 'inventory',
    title: 'Medicine Inventory & Incentives',
    fieldIds: ['stockors','stockparacetamol','stockifa','stockcondoms','stockpregkit',
      'kitexpiry','taskcount','claimanc','claimimmun','claimncd','claimother',
      'claimamount','paymentstatus','pfmsref'],
  }
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
    registerType: string,
    language: string = 'hi'
  ): Promise<GramNidanResult> {
    const moduleSpecs = GRAMNIDAN_MODULES.map(m => ({
      id: m.id,
      title: m.title,
      fieldIds: m.fieldIds,
    }));

    const langName = language === 'mr' ? 'Marathi (मराठी)' : language === 'en' ? 'English' : 'Hindi (हिंदी)';

    const prompt = `You are GramNidan AI, filling government ASHA health registers for rural Maharashtra, India.

ASHA VOICE NOTE (transcript in ${langName}): "${transcript}"

The ASHA was doing a "${registerType}" visit. Analyze the transcript smartly in ${langName} and extract all mentioned structured health details into the corresponding register fields. People often mention cross-cutting health details (BP, danger signs, feeding) that belong to OTHER registers too.

Below are ALL 12 available register modules with their field IDs. ONLY include a module/field if the voice note actually mentions something relevant to it. Be very selective — most voice notes will touch only 1-3 modules. Do NOT invent data. IMPORTANT: Fill the actual data values primarily in English.

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
      rawText = rawText.replace(/```json|```/g, '').trim();
      const jsonStart = rawText.indexOf('{');
      const jsonEnd = rawText.lastIndexOf('}');
      if (jsonStart === -1 || jsonEnd === -1) {
        return { transcript, registerType, filledModules: {}, hasWarnings: false };
      }
      rawText = rawText.slice(jsonStart, jsonEnd + 1);

      const parsed = JSON.parse(rawText) as Record<string, Record<string, string>>;

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
      return {
        transcript,
        registerType,
        filledModules: {},
        hasWarnings: false,
      };
    }
  }
}
