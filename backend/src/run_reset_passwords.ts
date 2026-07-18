import { supabase } from './config/supabase';
import * as fs from 'fs';
import * as path from 'path';

const TARGET_EMAILS = [
  'admin@asha.local',
  'doctor@asha.local',
  'test@asha.local'
];

const NEW_PASSWORD = 'password123';

async function resetPasswords() {
  const log: string[] = [];
  try {
    const { data: usersData, error: listError } = await supabase.auth.admin.listUsers();
    if (listError) {
      log.push('Error listing users: ' + listError.message);
      fs.writeFileSync(path.join(__dirname, '..', 'reset_log.json'), JSON.stringify({ log }, null, 2));
      return;
    }

    log.push('--- RESETTING PASSWORDS ---');
    for (const email of TARGET_EMAILS) {
      const user = usersData.users.find(u => u.email === email);
      if (user) {
        log.push(`Found user: ${email} (ID: ${user.id})`);
        const { error: updateError } = await supabase.auth.admin.updateUserById(user.id, {
          password: NEW_PASSWORD,
        });
        if (updateError) {
          log.push(`FAILED to reset password for ${email}: ${updateError.message}`);
        } else {
          log.push(`Successfully reset password for ${email} to "${NEW_PASSWORD}"`);
        }
      } else {
        log.push(`User ${email} not found in database. Creating it...`);
        let role = '';
        if (email.startsWith('admin')) role = 'admin';
        else if (email.startsWith('doctor')) role = 'doctor';
        else role = 'asha';

        const { data: createData, error: createError } = await supabase.auth.admin.createUser({
          email,
          password: NEW_PASSWORD,
          email_confirm: true,
          user_metadata: { role }
        });

        if (createError) {
          log.push(`FAILED to create user ${email}: ${createError.message}`);
        } else {
          log.push(`Successfully created user ${email} with password "${NEW_PASSWORD}"`);
        }
      }
    }
  } catch (e: any) {
    log.push('Exception during password reset: ' + e.message);
  }
  fs.writeFileSync(path.join(__dirname, '..', 'reset_log.json'), JSON.stringify({ log }, null, 2));
}

resetPasswords();
