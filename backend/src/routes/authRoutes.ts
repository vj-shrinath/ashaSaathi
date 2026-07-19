import { Router, Request, Response, NextFunction } from 'express';
import { supabase } from '../config/supabase';
import crypto from 'crypto';

const router = Router();

const normalizePhone = (phone: string) => phone.replace(/\D/g, '');
const buildEmail = (phone: string) => `${normalizePhone(phone)}@gmail.com`;
const slugify = (value: string) =>
  value
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '');

const buildPhcCode = (district: string, taluka: string, village: string, name: string) => {
  const parts = [district, taluka, village, name].map(slugify).filter(Boolean);
  return parts.join('-').toUpperCase();
};

const findUserByEmail = async (email: string) => {
  const { data: usersData, error } = await supabase.auth.admin.listUsers();
  if (error) return { error };

  const user = usersData.users.find(u => u.email === email);
  return { user };
};

const getAdminProfile = async (adminId: string) => {
  const { data: profile, error } = await supabase
    .from('user_profiles')
    .select('id, role, phc_id, full_name, is_active')
    .eq('id', adminId)
    .maybeSingle();

  if (error) return { error };
  return { profile };
};

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
    const { profile, error: dbError } = await getAdminProfile(user.id);

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

  const email = buildEmail(phone);

  try {
    // A. Check if the user exists in Supabase Auth using admin client
    const { user: matchedUser, error: findError } = await findUserByEmail(email);
    if (findError) {
       res.status(500).json({ status: 'error', message: findError.message });
       return;
    }
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

router.get('/phcs', async (_req: Request, res: Response): Promise<void> => {
  try {
    const { data, error } = await supabase
      .from('phcs')
      .select('id, name, code, district, taluka, village, address, is_active, created_at')
      .eq('is_active', true)
      .order('name', { ascending: true });

    if (error) {
      res.status(500).json({ status: 'error', message: error.message });
      return;
    }

    res.status(200).json({ status: 'success', data: data ?? [] });
  } catch (err: any) {
    res.status(500).json({ status: 'error', message: err.message || 'Internal server error' });
  }
});

router.get('/phcs/:phcId/doctors', async (req: Request, res: Response): Promise<void> => {
  const { phcId } = req.params;
  try {
    const { data, error } = await supabase
      .from('user_profiles')
      .select('id, full_name, role, phc_id, is_active')
      .eq('role', 'doctor')
      .eq('phc_id', phcId)
      .eq('is_active', true)
      .order('full_name', { ascending: true });

    if (error) {
      res.status(500).json({ status: 'error', message: error.message });
      return;
    }

    res.status(200).json({ status: 'success', data: data ?? [] });
  } catch (err: any) {
    res.status(500).json({ status: 'error', message: err.message || 'Internal server error' });
  }
});

router.post('/admin/phc', requireAdmin, async (req: Request, res: Response): Promise<void> => {
  const { name, district, taluka, village, address } = req.body;
  if (!name || !district || !taluka || !village || !address) {
    res.status(400).json({ status: 'error', message: 'PHC name, district, taluka, village, and address are required' });
    return;
  }

  try {
    const code = buildPhcCode(String(district), String(taluka), String(village), String(name));
    const { data, error } = await supabase
      .from('phcs')
      .upsert({
        name: String(name).trim(),
        code,
        district: String(district).trim(),
        taluka: String(taluka).trim(),
        village: String(village).trim(),
        address: String(address).trim(),
        is_active: true,
      }, { onConflict: 'code' })
      .select('id, name, code, district, taluka, village, address, is_active, created_at')
      .single();

    if (error) {
      res.status(500).json({ status: 'error', message: error.message });
      return;
    }

    res.status(200).json({ status: 'success', data });
  } catch (err: any) {
    res.status(500).json({ status: 'error', message: err.message || 'Internal server error' });
  }
});

router.patch('/admin/phc/:phcId', requireAdmin, async (req: Request, res: Response): Promise<void> => {
  const { phcId } = req.params;
  const { name, district, taluka, village, address, is_active } = req.body;

  if (!name || !district || !taluka || !village || !address) {
    res.status(400).json({ status: 'error', message: 'PHC name, district, taluka, village, and address are required' });
    return;
  }

  try {
    const code = buildPhcCode(String(district), String(taluka), String(village), String(name));
    const { data, error } = await supabase
      .from('phcs')
      .update({
        name: String(name).trim(),
        code,
        district: String(district).trim(),
        taluka: String(taluka).trim(),
        village: String(village).trim(),
        address: String(address).trim(),
        is_active: typeof is_active === 'boolean' ? is_active : true,
      })
      .eq('id', phcId)
      .select('id, name, code, district, taluka, village, address, is_active, created_at')
      .single();

    if (error) {
      res.status(500).json({ status: 'error', message: error.message });
      return;
    }

    res.status(200).json({ status: 'success', data });
  } catch (err: any) {
    res.status(500).json({ status: 'error', message: err.message || 'Internal server error' });
  }
});

router.post('/admin/phc-admin', requireAdmin, async (req: Request, res: Response): Promise<void> => {
  const { phone, password, fullName, phc_id } = req.body;

  if (!phone || !password || !fullName || !phc_id) {
    res.status(400).json({
      status: 'error',
      message: 'Phone number, password, full name, and PHC are required',
    });
    return;
  }

  const email = buildEmail(phone);

  try {
    const { data: phc, error: phcError } = await supabase
      .from('phcs')
      .select('id, name, is_active')
      .eq('id', phc_id)
      .maybeSingle();

    if (phcError) {
      res.status(500).json({ status: 'error', message: phcError.message });
      return;
    }

    if (!phc || !phc.is_active) {
      res.status(400).json({ status: 'error', message: 'Selected PHC is not available' });
      return;
    }

    const { user: existingUser, error: findError } = await findUserByEmail(email);
    if (findError) {
      res.status(500).json({ status: 'error', message: findError.message });
      return;
    }

    if (existingUser) {
      const { error: updateError } = await supabase.auth.admin.updateUserById(existingUser.id, {
        password,
        user_metadata: {
          role: 'admin',
          full_name: String(fullName).trim(),
          phone: normalizePhone(phone),
          phc_id,
        },
      });

      if (updateError) {
        res.status(500).json({ status: 'error', message: `Admin update failed: ${updateError.message}` });
        return;
      }

      const { error: profileError } = await supabase.from('user_profiles').upsert({
        id: existingUser.id,
        role: 'admin',
        full_name: String(fullName).trim(),
        phc_id,
        doctor_id: null,
        is_active: true,
        created_at: new Date().toISOString(),
      }, { onConflict: 'id' });

      if (profileError) {
        res.status(500).json({ status: 'error', message: `Admin profile sync failed: ${profileError.message}` });
        return;
      }

      res.status(200).json({
        status: 'success',
        message: 'PHC admin profile restored successfully',
        data: {
          user_id: existingUser.id,
          phc_id,
          existed: true,
        },
      });
      return;
    }

    const { data: createData, error: createError } = await supabase.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
      user_metadata: {
        role: 'admin',
        full_name: String(fullName).trim(),
        phone: normalizePhone(phone),
        phc_id,
      },
    });

    if (createError) {
      res.status(400).json({
        status: 'error',
        message: createError.message || 'Failed to create admin account',
      });
      return;
    }

    if (!createData.user) {
      res.status(500).json({ status: 'error', message: 'Admin creation failed' });
      return;
    }

    const { error: profileError } = await supabase.from('user_profiles').upsert({
      id: createData.user.id,
      role: 'admin',
      full_name: String(fullName).trim(),
      phc_id,
      doctor_id: null,
      is_active: true,
      created_at: new Date().toISOString(),
    }, { onConflict: 'id' });

    if (profileError) {
      await supabase.auth.admin.deleteUser(createData.user.id);
      res.status(500).json({ status: 'error', message: `Admin profile creation failed: ${profileError.message}` });
      return;
    }

    res.status(200).json({
      status: 'success',
      message: 'PHC admin registered successfully',
      data: {
        user_id: createData.user.id,
        phc_id,
        existed: false,
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
    const email = buildEmail(phone);
    const { user, error: listError } = await findUserByEmail(email);
    
    let fullName = 'ASHA Worker';
    let role = 'asha';
    if (!listError && user) {
      if (user.user_metadata && user.user_metadata.full_name) {
        fullName = user.user_metadata.full_name;
      }
      if (user.user_metadata && user.user_metadata.role) {
        role = user.user_metadata.role;
      }
    }

    // D. Return the authorized temp password back to the setup client
    res.status(200).json({
      status: 'success',
      data: {
        temp_password: tokenRecord.temp_password,
        full_name: fullName,
        role,
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
  const { phone, password, fullName, role, phc_id, doctor_id } = req.body;

  if (!phone || !password || !fullName || !role || !phc_id) {
    res.status(400).json({ status: 'error', message: 'All registration parameters are required' });
    return;
  }

  const email = buildEmail(phone);

  try {
    const { data: phc, error: phcError } = await supabase
      .from('phcs')
      .select('id, name, is_active')
      .eq('id', phc_id)
      .maybeSingle();

    if (phcError) {
      res.status(500).json({ status: 'error', message: phcError.message });
      return;
    }

    if (!phc || !phc.is_active) {
      res.status(400).json({ status: 'error', message: 'Selected PHC is not available' });
      return;
    }

    if (role === 'asha' && !doctor_id) {
      res.status(400).json({ status: 'error', message: 'Doctor selection is required for ASHA workers' });
      return;
    }

    if (role === 'asha') {
      const { data: doctorProfile, error: doctorError } = await supabase
        .from('user_profiles')
        .select('id, role, phc_id, is_active')
        .eq('id', doctor_id)
        .eq('role', 'doctor')
        .eq('phc_id', phc_id)
        .eq('is_active', true)
        .maybeSingle();

      if (doctorError) {
        res.status(500).json({ status: 'error', message: doctorError.message });
        return;
      }

      if (!doctorProfile) {
        res.status(400).json({ status: 'error', message: 'Selected doctor does not belong to this PHC' });
        return;
      }
    }

    const { user: existingUser, error: findError } = await findUserByEmail(email);
    if (findError) {
      res.status(500).json({ status: 'error', message: findError.message });
      return;
    }

    if (existingUser) {
      const { error: updateUserError } = await supabase.auth.admin.updateUserById(existingUser.id, {
        password,
        user_metadata: {
          role,
          full_name: fullName,
          phone: normalizePhone(phone),
          phc_id,
          doctor_id: doctor_id ?? null,
        },
      });

      if (updateUserError) {
        res.status(500).json({ status: 'error', message: `Profile update failed: ${updateUserError.message}` });
        return;
      }

      const { error: profileError } = await supabase.from('user_profiles').upsert({
        id: existingUser.id,
        role,
        full_name: fullName,
        phc_id,
        doctor_id: doctor_id ?? null,
        is_active: true,
        created_at: new Date().toISOString(),
      }, { onConflict: 'id' });

      if (profileError) {
        res.status(500).json({ status: 'error', message: `Profile sync failed: ${profileError.message}` });
        return;
      }

      res.status(200).json({
        status: 'success',
        message: 'Worker profile restored successfully',
        data: {
          user_id: existingUser.id,
          existed: true,
        },
      });
      return;
    }

    // A. Use admin API to create the user directly (bypassing confirmation emails)
    const { data: createData, error: createError } = await supabase.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
      user_metadata: {
        role,
        full_name: fullName,
        phone: normalizePhone(phone),
        phc_id,
        doctor_id: doctor_id ?? null,
      }
    });

    if (createError) {
      res.status(400).json({
        status: 'error',
        message: createError.message || 'Failed to create user account',
      });
      return;
    }

    if (!createData.user) {
      res.status(500).json({ status: 'error', message: 'User generation failed' });
      return;
    }

    const { error: profileError } = await supabase.from('user_profiles').upsert({
      id: createData.user.id,
      role,
      full_name: fullName,
      phc_id,
      doctor_id: doctor_id ?? null,
      is_active: true,
      created_at: new Date().toISOString(),
    }, { onConflict: 'id' });

    if (profileError) {
      await supabase.auth.admin.deleteUser(createData.user.id);
      res.status(500).json({ status: 'error', message: `Profile creation failed: ${profileError.message}` });
      return;
    }

    res.status(200).json({
      status: 'success',
      message: 'Worker registered successfully',
      data: {
        user_id: createData.user.id,
        existed: false,
      },
    });

  } catch (err: any) {
    res.status(500).json({ status: 'error', message: err.message || 'Internal server error' });
  }
});

router.post('/resolve-worker', async (req: Request, res: Response): Promise<void> => {
  const { phone } = req.body;
  if (!phone || typeof phone !== 'string') {
    res.status(400).json({ status: 'error', message: 'Valid phone number is required' });
    return;
  }

  try {
    const email = buildEmail(phone);
    const { user, error } = await findUserByEmail(email);
    if (error) {
      res.status(500).json({ status: 'error', message: error.message });
      return;
    }

    if (!user) {
      res.status(404).json({ status: 'error', message: 'No account found for this phone number' });
      return;
    }

    const { data: profile, error: profileError } = await supabase
      .from('user_profiles')
      .select('role, full_name, phc_id, doctor_id, is_active')
      .eq('id', user.id)
      .maybeSingle();

    if (profileError) {
      res.status(500).json({ status: 'error', message: profileError.message });
      return;
    }

    res.status(200).json({
      status: 'success',
      data: {
        user_id: user.id,
        email: user.email,
        role: profile?.role ?? user.user_metadata?.role ?? 'asha',
        full_name: profile?.full_name ?? user.user_metadata?.full_name ?? 'ASHA Worker',
        phc_id: profile?.phc_id ?? user.user_metadata?.phc_id ?? null,
        doctor_id: profile?.doctor_id ?? user.user_metadata?.doctor_id ?? null,
        is_active: profile?.is_active ?? true,
      },
    });
  } catch (err: any) {
    res.status(500).json({ status: 'error', message: err.message || 'Internal server error' });
  }
});

export default router;
