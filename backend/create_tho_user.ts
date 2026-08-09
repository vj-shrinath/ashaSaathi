import { createClient } from '@supabase/supabase-js';
import dotenv from 'dotenv';
import ws from 'ws';
dotenv.config();

const supabase = createClient(
  process.env.SUPABASE_URL || '',
  process.env.SUPABASE_SERVICE_ROLE_KEY || '',
  {
    auth: {
      autoRefreshToken: false,
      persistSession: false,
    },
    realtime: {
        // @ts-ignore
        transport: ws,
    }
  }
);

async function createThoUser() {
  const email = 'tho@health.gov.in';
  const password = 'Password@123';
  console.log(`Setting up THO test user: ${email}...`);

  // 1. Create the user in auth.users
  const { data: userData, error: authError } = await supabase.auth.admin.createUser({
    email: email,
    password: password,
    email_confirm: true,
    user_metadata: { full_name: 'Taluka Health Officer' }
  });

  if (authError) {
    if (authError.message.includes('already registered')) {
        console.log('THO user already exists in auth. Updating profile...');
    } else {
        console.error('Error creating THO auth user:', authError.message);
        return;
    }
  }

  // 2. Fetch the ID (either newly created, or try to get existing)
  let userId = userData?.user?.id;
  if (!userId) {
     const { data: users } = await supabase.auth.admin.listUsers();
     const existingUser = users.users.find(u => u.email === email);
     if (existingUser) userId = existingUser.id;
  }

  if (userId) {
    // 3. Upsert into user_profiles
    const { error: profileError } = await supabase.from('user_profiles').upsert({
      id: userId,
      role: 'tho',
      full_name: 'Taluka Health Officer',
      is_active: true,
      must_change_password: false
    });

    if (profileError) {
      console.error('Error adding THO role in user_profiles:', profileError.message);
    } else {
      console.log('✅ Success! THO Credentials Created!');
      console.log('------------------------------------');
      console.log(`Email:    ${email}`);
      console.log(`Password: ${password}`);
      console.log('------------------------------------');
    }
  }
}

createThoUser();
