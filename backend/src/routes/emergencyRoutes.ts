import { Router, Request, Response } from 'express';
import { supabase, TABLES, now } from '../config/supabase';
import { WhatsAppService } from '../services/WhatsAppService';

const router = Router();

router.post('/trigger', async (req: Request, res: Response): Promise<void> => {
  try {
    const { patientId, ashaId, lat, lng } = req.body as {
      patientId?: string;
      ashaId?: string;
      lat?: number;
      lng?: number;
    };

    if (!patientId) {
      res.status(400).json({ error: 'patientId is required' });
      return;
    }

    console.log(`[EMERGENCY] Triggered for patient=${patientId}`);

    // Fetch patient info from Supabase
    const { data: patient, error: patientError } = await supabase
      .from(TABLES.PATIENTS)
      .select('name, family_phone_number')
      .eq('id', patientId)
      .single();

    if (patientError || !patient) {
      console.error('[EMERGENCY] Patient not found:', patientError?.message);
    }

    const patientName = patient?.name ?? 'Unknown';
    const familyPhone = patient?.family_phone_number;

    // Build Google Maps URL for nearest hospital
    const mapsUrl = lat && lng
      ? `https://www.google.com/maps/search/hospital/@${lat},${lng},14z`
      : 'https://www.google.com/maps/search/hospital+near+me';

    // Log Emergency Event to Supabase
    const { data: event, error: eventError } = await supabase
      .from(TABLES.EMERGENCY_EVENTS)
      .insert({
        patient_id: patientId,
        asha_id: ashaId ?? null,
        timestamp: now(),
        location: lat && lng ? { lat, lng } : null,
        status: 'Dispatching',
        maps_url: mapsUrl,
      })
      .select('id')
      .single();

    if (eventError) {
      console.error('[EMERGENCY] Failed to log event:', eventError.message);
    }

    // TODO: FCM to Doctors - implement with Supabase Realtime or separate service
    // For now, log the alert
    console.log('[FCM] Emergency alert to doctors:', {
      title: '🚨 EMERGENCY — Ambulance Dispatched',
      body: `Patient ${patientName} requires immediate assistance.`,
      data: { patientId, eventId: event?.id, mapsUrl },
    });

    // WhatsApp to Family (non-blocking)
    if (familyPhone) {
      WhatsAppService.sendEmergencyAlert(familyPhone, patientName, mapsUrl)
        .catch((e: Error) => console.error('[WhatsApp] Emergency alert failed:', e.message));
    }

    res.status(200).json({
      status: 'Emergency Protocol Activated',
      eventId: event?.id,
      mapsUrl,
    });

  } catch (error) {
    const err = error as Error;
    console.error('[EMERGENCY] Error:', err.message);
    res.status(500).json({ error: err.message });
  }
});

export default router;
