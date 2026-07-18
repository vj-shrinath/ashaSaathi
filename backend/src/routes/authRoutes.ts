import { Router, Request, Response, NextFunction } from 'express';
import { supabase } from '../config/supabase';
import crypto from 'crypto';

const router = Router();

// ─────────────────────────────────────────────────────────────
// Middleware: Verify Admin Authorization
// ─────────────────────────────────────────────────────────────
const requireAdmin = async (req: Request, res: Response, next: NextFunction): Promise<void> => {
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    res.status(401).json({ status: 'error', message: 'No authorization token provided' });
    return;
  }

  const token = authHeader.split(' ')[1];

  try {
    // 1. Resolve Auth user from Supabase using original JWT
    const { data: { user }, error } = await supabase.auth.getUser(token);
    if (error || !user) {
      res.status(401).json({ status: 'error', message: 'Invalid or expired session' });
      return;
    }

    // 2. Fetch User Profile to guarantee they are an Admin
    const { data: profile, error: dbError } = await supabase
      .from('user_profiles')
      .select('role')
      .eq('id', user.id)
      .single();

    if (dbError || !profile || profile.role !== 'admin') {
      res.status(403).json({ status: 'error', message: 'Forbidden: Admin access required' });
      return;
    }

    // Pass user ID down
    (req as any).adminUserId = user.id;
    next();
  } catch (error: any) {
    res.status(401).json({ status: 'error', message: error.message || 'Auth failure' });
  }
};

// ─────────────────────────────────────────────────────────────
// 1. Admin Endpoint: Generate Sync Token (Admin Auth Required)
// ─────────────────────────────────────────────────────────────
router.post('/admin/generate-sync-token', requireAdmin, async (req: Request, res: Response): Promise<void> => {
  const { phone } = req.body;

  if (!phone || typeof phone !== 'string') {
    res.status(400).json({ status: 'error', message: 'Valid phone number is required' });
    return;
  }

  const email = `${phone}@gmail.com`;

  try {
    // A. Check if the user exists in Supabase Auth using admin client
    const { data: usersData, error: findError } = await supabase.auth.admin.listUsers();
    if (findError) {
       res.status(500).json({ status: 'error', message: findError.message });
       return;
    }

    const matchedUser = usersData.users.find(u => u.email === email);
    if (!matchedUser) {
      res.status(404).json({ status: 'error', message: 'Employee user account not found for this phone number' });
      return;
    }

    // B. Generate 6-digit PIN and secure temp password
    const pin = crypto.randomInt(100000, 999999).toString();
    const tempPassword = crypto.randomUUID();

    // C. Perform password rewrite on Supabase Auth (admin privileges)
    const { error: updateError } = await supabase.auth.admin.updateUserById(matchedUser.id, {
      password: tempPassword,
    });

    if (updateError) {
      res.status(500).json({ status: 'error', message: `Update failed: ${updateError.message}` });
      return;
    }

    // D. Invalidate any existing active sync tokens for this phone
    await supabase
      .from('device_sync_tokens')
      .update({ is_used: true })
      .eq('phone', phone)
      .eq('is_used', false);

    // E. Save Sync Token to database
    const expiresAt = new Date();
    expiresAt.setMinutes(expiresAt.getMinutes() + 10); // Expires in 10 minutes

    const { error: insertError } = await supabase
      .from('device_sync_tokens')
      .insert({
        phone,
        pin,
        temp_password: tempPassword,
        expires_at: expiresAt.toISOString(),
        is_used: false,
      });

    if (insertError) {
      res.status(500).json({ status: 'error', message: `Database insert failed: ${insertError.message}` });
      return;
    }

    // F. Return generated PIN for visual rendering on Admin screen
    res.status(200).json({
      status: 'success',
      data: {
        pin,
        expires_at: expiresAt.toISOString(),
      },
    });

  } catch (err: any) {
    res.status(500).json({ status: 'error', message: err.message || 'Internal server error' });
  }
});

// ─────────────────────────────────────────────────────────────
// 2. Public Endpoint: Verify Sync Token (No Auth Needed)
// ─────────────────────────────────────────────────────────────
router.post('/verify-sync-token', async (req: Request, res: Response): Promise<void> => {
  const { phone, pin } = req.body;

  if (!phone || !pin) {
    res.status(400).json({ status: 'error', message: 'Phone number and verification PIN are required' });
    return;
  }

  try {
    // A. Query database for unexpired, unused token matching phone and PIN
    const { data: tokenRecord, error: fetchError } = await supabase
      .from('device_sync_tokens')
      .select('*')
      .eq('phone', phone)
      .eq('pin', pin)
      .eq('is_used', false)
      .gt('expires_at', new Date().toISOString())
      .maybeSingle();

    if (fetchError || !tokenRecord) {
      res.status(400).json({ status: 'error', message: 'Synchronization code is invalid or has expired' });
      return;
    }

    // B. Mark token as consumed
    const { error: updateTokenError } = await supabase
      .from('device_sync_tokens')
      .update({ is_used: true })
      .eq('id', tokenRecord.id);

    if (updateTokenError) {
      res.status(500).json({ status: 'error', message: 'Verification error' });
      return;
    }

    // C. Get user metadata (e.g. name) to pass back to the client
    const email = `${phone}@gmail.com`;
    const { data: usersData, error: listError } = await supabase.auth.admin.listUsers();
    
    let fullName = 'ASHA Worker';
    if (!listError && usersData) {
      const user = usersData.users.find(u => u.email === email);
      if (user && user.user_metadata && user.user_metadata.full_name) {
        fullName = user.user_metadata.full_name;
      }
    }

    // D. Return the authorized temp password back to the setup client
    res.status(200).json({
      status: 'success',
      data: {
        temp_password: tokenRecord.temp_password,
        full_name: fullName,
      },
    });

  } catch (err: any) {
    res.status(500).json({ status: 'error', message: err.message || 'Internal server error' });
  }
});

// ─────────────────────────────────────────────────────────────
// 3. Public Endpoint: Register Worker (Bypasses email SMTP/rate limits)
// ─────────────────────────────────────────────────────────────
router.post('/register-worker', async (req: Request, res: Response): Promise<void> => {
  const { phone, password, fullName, role } = req.body;

  if (!phone || !password || !fullName || !role) {
    res.status(400).json({ status: 'error', message: 'All registration parameters are required' });
    return;
  }

  const email = `${phone}@gmail.com`;

  try {
    // A. Use admin API to create the user directly (bypassing confirmation emails)
    const { data: createData, error: createError } = await supabase.auth.admin.createUser({
      email,
      password,
      email_confirm: true, // Creates user as verified immediately. Bypasses email rate limit.
      user_metadata: {
        role,
        full_name: fullName,
      }
    });

    if (createError) {
      // Return 422 with a conflict message if user already exists
      const isConflict = createError.message.toLowerCase().includes('already') || createError.status === 422;
      res.status(isConflict ? 422 : 400).json({
        status: 'error',
        message: createError.message || 'Failed to create user account',
      });
      return;
    }

    if (!createData.user) {
      res.status(500).json({ status: 'error', message: 'User generation failed' });
      return;
    }

    // B. Create row in user_profiles
    const { error: profileError } = await supabase.from('user_profiles').insert({
      id: createData.user.id,
      role,
      created_at: new Date().toISOString(),
      is_active: true,
    });

    if (profileError) {
      // Rollback user creation to maintain consistency
      await supabase.auth.admin.deleteUser(createData.user.id);
      res.status(500).json({ status: 'error', message: `Profile creation failed: ${profileError.message}` });
      return;
    }

    res.status(200).json({
      status: 'success',
      message: 'Worker registered successfully',
    });

  } catch (err: any) {
    res.status(500).json({ status: 'error', message: err.message || 'Internal server error' });
  }
});

export default router;
