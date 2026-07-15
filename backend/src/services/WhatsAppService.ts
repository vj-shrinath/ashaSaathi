import axios from 'axios';
import dotenv from 'dotenv';
dotenv.config();

const META_ACCESS_TOKEN = process.env.META_ACCESS_TOKEN || '';
const PHONE_NUMBER_ID = process.env.META_PHONE_NUMBER_ID || '';
const META_API_URL = `https://graph.facebook.com/v19.0/${PHONE_NUMBER_ID}/messages`;

export class WhatsAppService {

  /**
   * Send a plain text reply to a WhatsApp user.
   */
  static async sendTextMessage(recipientPhone: string, text: string): Promise<void> {
    if (!META_ACCESS_TOKEN || !PHONE_NUMBER_ID) {
      console.warn('WhatsApp credentials not configured — skipping send.');
      return;
    }

    try {
      await axios.post(
        META_API_URL,
        {
          messaging_product: 'whatsapp',
          to: recipientPhone,
          type: 'text',
          text: { body: text }
        },
        {
          headers: {
            'Content-Type': 'application/json',
            'Authorization': `Bearer ${META_ACCESS_TOKEN}`
          }
        }
      );
      console.log(`WhatsApp text sent to ${recipientPhone}`);
    } catch (error: any) {
      console.error('WhatsApp send error:', error.response?.data || error.message);
    }
  }

  /**
   * Send an emergency alert to a family member with hospital link.
   */
  static async sendEmergencyAlert(
    recipientPhone: string,
    patientName: string,
    hospitalMapUrl: string
  ): Promise<void> {
    const alertText = `🚨 *EMERGENCY ALERT* 🚨\n\n` +
      `Patient *${patientName}* has been flagged as CRITICAL by AI analysis.\n\n` +
      `🏥 Nearest hospital route:\n${hospitalMapUrl}\n\n` +
      `📞 Call 108 for ambulance immediately.\n\n` +
      `_ASHA Saathi AI — Automated Alert_`;

    await WhatsAppService.sendTextMessage(recipientPhone, alertText);
  }

  /**
   * Send a routine health update to the family.
   */
  static async sendHealthUpdate(
    recipientPhone: string,
    patientName: string,
    summary: string
  ): Promise<void> {
    const updateText = `🩺 *Health Update — ${patientName}*\n\n` +
      `${summary}\n\n` +
      `Questions? Reply to this message and our AI assistant will help.\n\n` +
      `_ASHA Saathi AI_`;

    await WhatsAppService.sendTextMessage(recipientPhone, updateText);
  }
}
