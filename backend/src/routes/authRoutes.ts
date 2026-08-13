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
    .select('id, role, phc_id, full_name, is_active, must_change_password')
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
router.post('/admin/generate-sync-token', requireAdmin, async (_req: Request, res: Response): Promise<void> => {
  res.status(410).json({
    status: 'error',
    message: 'Device sync has been removed. Use admin-managed password reset instead.',
  });
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

router.post('/public-phc', async (req: Request, res: Response): Promise<void> => {
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
  const { email, phone, password, fullName, phc_id } = req.body;

  if (!email || !phone || !password || !fullName || !phc_id) {
    res.status(400).json({
      status: 'error',
      message: 'Email, phone number, password, full name, and PHC are required',
    });
    return;
  }

  const normalizedEmail = String(email).trim().toLowerCase();
  if (!normalizedEmail.includes('@')) {
    res.status(400).json({ status: 'error', message: 'A valid admin email is required' });
    return;
  }

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

    const { user: existingUser, error: findError } = await findUserByEmail(normalizedEmail);
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
          email: normalizedEmail,
          existed: true,
        },
      });
      return;
    }

    const { data: createData, error: createError } = await supabase.auth.admin.createUser({
      email: normalizedEmail,
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
          email: normalizedEmail,
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
router.post('/verify-sync-token', async (_req: Request, res: Response): Promise<void> => {
  res.status(410).json({
    status: 'error',
    message: 'Device sync has been removed.',
  });
});

// ─────────────────────────────────────────────────────────────
// 3. Public Endpoint: Register Worker (Bypasses email SMTP/rate limits)
// ─────────────────────────────────────────────────────────────
router.post('/register-worker', requireAdmin, async (req: Request, res: Response): Promise<void> => {
  const { email, fullName, role, phc_id, doctor_id } = req.body;

  if (!email || !fullName || !role) {
    res.status(400).json({ status: 'error', message: 'Email, full name, and role are required' });
    return;
  }

  if (!['asha', 'doctor', 'admin'].includes(role)) {
    res.status(400).json({ status: 'error', message: 'Invalid role' });
    return;
  }

  const normalizedEmail = String(email).trim().toLowerCase();

  // Generate an easy, memorable 8-character temporary password (e.g. Asha8294)
  const tempPassword = 'Asha' + Math.floor(1000 + Math.random() * 9000).toString();

  try {
    const { user: existingUser, error: findError } = await findUserByEmail(normalizedEmail);
    if (findError) {
      res.status(500).json({ status: 'error', message: findError.message });
      return;
    }

    let userId = existingUser?.id;

    if (!existingUser) {
      const { data: createData, error: createError } = await supabase.auth.admin.createUser({
        email: normalizedEmail,
        password: tempPassword,
        email_confirm: true,
        user_metadata: {
          full_name: String(fullName).trim(),
        },
      });

      if (createError) {
        res.status(400).json({ status: 'error', message: createError.message || 'Failed to create user account' });
        return;
      }

      userId = createData.user?.id;
    } else {
      const { error: updateError } = await supabase.auth.admin.updateUserById(existingUser.id, {
        password: tempPassword,
        user_metadata: {
          full_name: String(fullName).trim(),
        },
      });

      if (updateError) {
        res.status(500).json({ status: 'error', message: updateError.message });
        return;
      }
    }

    if (!userId) {
      res.status(500).json({ status: 'error', message: 'Unable to determine created user id' });
      return;
    }

    const { error: profileError } = await supabase.from('user_profiles').upsert({
      id: userId,
      role,
      full_name: String(fullName).trim(),
      phc_id: phc_id ?? null,
      doctor_id: doctor_id ?? null,
      is_active: true,
      must_change_password: true,
      created_at: new Date().toISOString(),
    }, { onConflict: 'id' });

    if (profileError) {
      res.status(500).json({ status: 'error', message: `Profile sync failed: ${profileError.message}` });
      return;
    }

    res.status(200).json({
      status: 'success',
      message: existingUser ? 'Worker password reset successfully' : 'Worker account created successfully',
      data: {
        user_id: userId,
        temp_password: tempPassword,
        existed: Boolean(existingUser),
      },
    });
  } catch (err: any) {
    res.status(500).json({ status: 'error', message: err.message || 'Internal server error' });
  }
});

router.post('/complete-password-change', async (req: Request, res: Response): Promise<void> => {
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    res.status(401).json({ status: 'error', message: 'No authorization token provided' });
    return;
  }

  const token = authHeader.split(' ')[1];
  const { newPassword } = req.body;

  if (!newPassword || String(newPassword).trim().length < 6) {
    res.status(400).json({ status: 'error', message: 'New password must be at least 6 characters' });
    return;
  }

  try {
    const {
      data: { user },
      error,
    } = await supabase.auth.getUser(token);

    if (error || !user) {
      res.status(401).json({ status: 'error', message: 'Invalid or expired session' });
      return;
    }

    const { data: profile, error: profileError } = await supabase
      .from('user_profiles')
      .select('id, role, full_name, phc_id, doctor_id, is_active, must_change_password, created_at')
      .eq('id', user.id)
      .maybeSingle();

    if (profileError) {
      res.status(500).json({ status: 'error', message: profileError.message });
      return;
    }

    if (!profile) {
      res.status(404).json({ status: 'error', message: 'User profile not found' });
      return;
    }

    const { error: passwordError } = await supabase.auth.admin.updateUserById(user.id, {
      password: String(newPassword),
    });

    if (passwordError) {
      res.status(500).json({ status: 'error', message: passwordError.message });
      return;
    }

    const { error: syncError } = await supabase.from('user_profiles').upsert({
      id: profile.id,
      role: profile.role,
      full_name: profile.full_name ?? null,
      phc_id: profile.phc_id ?? null,
      doctor_id: profile.doctor_id ?? null,
      is_active: profile.is_active ?? true,
      must_change_password: false,
      password_changed_at: new Date().toISOString(),
      created_at: profile.created_at ?? new Date().toISOString(),
    }, { onConflict: 'id' });

    if (syncError) {
      res.status(500).json({ status: 'error', message: `Password updated but profile sync failed: ${syncError.message}` });
      return;
    }

    res.status(200).json({
      status: 'success',
      message: 'Password changed successfully',
      data: {
        user_id: profile.id,
        role: profile.role,
        must_change_password: false,
      },
    });
  } catch (err: any) {
    res.status(500).json({ status: 'error', message: err.message || 'Internal server error' });
  }
});

router.post('/resolve-worker', async (req: Request, res: Response): Promise<void> => {
  res.status(410).json({
    status: 'error',
    message: 'Worker resolution is no longer public.',
  });
});

export default router;
