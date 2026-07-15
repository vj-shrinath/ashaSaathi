import { Router, Request, Response } from 'express';
import { supabase, TABLES } from '../config/supabase';
import { GeminiService } from '../services/GeminiService';
import { WhatsAppService } from '../services/WhatsAppService';

const router = Router();

// ── Webhook Verification (GET) ────────────────────────────────────────────────
router.get('/whatsapp', (req: Request, res: Response): void => {
  const verifyToken = process.env.META_VERIFY_TOKEN;
  const mode       = req.query['hub.mode'];
  const token      = req.query['hub.verify_token'];
  const challenge  = req.query['hub.challenge'];

  if (mode === 'subscribe' && token === verifyToken) {
    console.log('[WhatsApp] Webhook verified successfully.');
    res.status(200).send(challenge);
  } else {
    console.warn('[WhatsApp] Webhook verification failed.');
    res.sendStatus(403);
  }
});

// ── Incoming Message Handler (POST) ──────────────────────────────────────────
router.post('/whatsapp', (req: Request, res: Response): void => {
  // MUST return 200 immediately — Meta will retry otherwise
  res.sendStatus(200);

  // Process async, without blocking the webhook response
  handleIncoming(req.body).catch((e: Error) =>
    console.error('[WhatsApp] Async handler error:', e.message)
  );
});

async function handleIncoming(payload: Record<string, unknown>): Promise<void> {
  try {
    const entry   = (payload.entry as Record<string, unknown>[])?.[0];
    const changes = (entry?.changes as Record<string, unknown>[])?.[0];
    const value   = changes?.value as Record<string, unknown> | undefined;
    const messages = value?.messages as Record<string, unknown>[] | undefined;
    const message = messages?.[0];

    if (!message || message['type'] !== 'text') return;

    const fromPhone = message['from'] as string;
    const textBody  = (message['text'] as Record<string, string>)['body'];

    console.log(`[WhatsApp] Incoming from ${fromPhone}: ${textBody}`);

    // Look up patient by family phone in Supabase
    const { data: patients, error } = await supabase
      .from(TABLES.PATIENTS)
      .select('name, age, current_risk_category, medical_history')
      .eq('family_phone_number', `+${fromPhone}`)
      .limit(1);

    if (error) {
      console.error('[WhatsApp] Patient lookup error:', error.message);
    }

    let context = 'Unknown patient — general health guidance mode.';
    if (patients && patients.length > 0) {
      const pt = patients[0];
      context =
        `Patient: ${pt.name}, Age: ${pt.age}. ` +
        `Current Risk: ${pt.current_risk_category}. ` +
        `History: ${(pt.medical_history || []).join(', ')}.`;
    }

    // Generate AI response (Gemini)
    const replyText = await GeminiService.generateChatResponse(textBody, context);

    // Send WhatsApp reply
    await WhatsAppService.sendTextMessage(fromPhone, replyText);

    console.log(`[WhatsApp] Replied to ${fromPhone}`);
  } catch (error) {
    console.error('[WhatsApp] Handler error:', (error as Error).message);
  }
}

export default router;
