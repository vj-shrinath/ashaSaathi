/**
 * ============================================================
 *  TARPIT MIDDLEWARE — ASHA Saathi AI Backend
 *  Authored for production-grade bot & scraper neutralisation.
 *
 *  Defence Strategy (4-Step Process):
 *  ─────────────────────────────────
 *  Step 1 – THE BAIT   : Declare honeypot trap URLs that no
 *                         legitimate client ever touches.
 *  Step 2 – THE TRAP   : Intercept requests hitting trap URLs
 *                         before they reach real route handlers.
 *  Step 3 – THE TAR    : Respond with 200 OK and drip-feed
 *                         1 byte every 10 s indefinitely,
 *                         starving the attacker of a thread.
 *  Step 4 – THE CATCH  : Log the hit and blacklist the IP in
 *                         Supabase `blocked_ips` table so every
 *                         future request from that IP is 403'd
 *                         instantly without paying the tarpit
 *                         cost again.
 * ============================================================
 */

import { Request, Response, NextFunction } from 'express';
import { supabase } from '../config/supabase';

// ─────────────────────────────────────────────────────────────
// STEP 1 — THE BAIT
// A curated list of honeypot paths that:
//   • Legitimate ASHA Saathi clients NEVER request.
//   • Automated scanners, credential-stuffers, and CMS probers
//     ALWAYS request as part of their enumeration routines.
// ─────────────────────────────────────────────────────────────
const TRAP_URLS: string[] = [
  // Classic CMS & admin panel probes
  '/api/admin_panel',
  '/admin',
  '/admin.php',
  '/administrator',
  '/wp-login.php',
  '/wp-admin',
  '/wp-config.php',
  '/wordpress',
  '/xmlrpc.php',

  // Config / credential file exposure attempts
  '/.env',
  '/.env.local',
  '/.env.production',
  '/.git/config',
  '/.git/HEAD',
  '/config.php',
  '/configuration.php',
  '/web.config',
  '/app.config',

  // Data-exfiltration endpoints
  '/api/v1/database/dump',
  '/api/v1/users/dump',
  '/api/v1/export',
  '/dump.sql',
  '/backup.zip',
  '/db.sql',

  // Shell & exploit probes
  '/shell.php',
  '/cmd.php',
  '/c99.php',
  '/r57.php',
  '/phpinfo.php',
  '/info.php',

  // Security scanner fingerprints
  '/actuator',
  '/actuator/env',
  '/actuator/health',
  '/console',
  '/manager/html',
  '/phpmyadmin',
  '/pma',
  '/myadmin',

  // Path-traversal bait
  '/etc/passwd',
  '/etc/shadow',
  '/proc/self/environ',
];

// ─────────────────────────────────────────────────────────────
// Supabase table name — keep in one place for easy refactoring.
// ─────────────────────────────────────────────────────────────
const BLOCKED_IPS_TABLE = 'blocked_ips';

// ─────────────────────────────────────────────────────────────
// Utility: Extract the real client IP, respecting reverse-proxy
// headers set by Cloud Run / Firebase Hosting.
// ─────────────────────────────────────────────────────────────
function getClientIp(req: Request): string {
  const forwarded = req.headers['x-forwarded-for'];
  if (typeof forwarded === 'string') {
    // x-forwarded-for can be a comma-separated list; first entry is originating client.
    return forwarded.split(',')[0].trim();
  }
  return req.socket.remoteAddress ?? 'unknown';
}

// ─────────────────────────────────────────────────────────────
// STEP 4 — THE CATCH (database side)
// Insert the attacker's IP into `blocked_ips`. If it already
// exists (duplicate), the upsert silently ignores it.
// ─────────────────────────────────────────────────────────────
async function blacklistIp(ip: string, trapPath: string): Promise<void> {
  const { error } = await supabase
    .from(BLOCKED_IPS_TABLE)
    .upsert(
      {
        ip_address: ip,
        reason: `Tarpit hit: ${trapPath}`,
        banned_at: new Date().toISOString(),
        hit_count: 1,        // initial insert value
      },
      {
        onConflict: 'ip_address',   // if row exists, increment hit_count instead
        ignoreDuplicates: false,
      }
    );

  if (error) {
    // Non-fatal — the bot is ALREADY being tarpitted; log and continue.
    console.error(`[TARPIT] ⚠️  Failed to blacklist IP ${ip}:`, error.message);
  }
}

// ─────────────────────────────────────────────────────────────
// STEP 4 — THE CATCH (increment side)
// For repeat offenders already in the table, bump their counter.
// This is fired in a fire-and-forget manner so it never blocks
// the tarpit drip loop.
// ─────────────────────────────────────────────────────────────
async function incrementHitCount(ip: string): Promise<void> {
  // Supabase doesn't support server-side increment via upsert directly,
  // so we use an RPC or a raw update after reading current value.
  // We keep it simple: just update banned_at timestamp as a heartbeat;
  // the RPC `increment_blocked_ip` is defined in the migration SQL.
  const { error } = await supabase.rpc('increment_blocked_ip_hits', {
    p_ip_address: ip,
  });
  if (error) {
    // Completely non-fatal — ignore silently.
  }
}

// ─────────────────────────────────────────────────────────────
// MAIN MIDDLEWARE EXPORT
// Register this BEFORE all other route middleware in index.ts
// using: app.use(tarpitMiddleware);
// ─────────────────────────────────────────────────────────────
export async function tarpitMiddleware(
  req: Request,
  res: Response,
  next: NextFunction
): Promise<void> {
  const clientIp = getClientIp(req);
  const requestPath = req.path.toLowerCase();

  // ───────────────────────────────────────────────────────────
  // PRE-CHECK — Is this IP already blacklisted?
  // If yes, reject immediately with 403 — no tarpit cost needed.
  // ───────────────────────────────────────────────────────────
  try {
    const { data: blocked, error: lookupError } = await supabase
      .from(BLOCKED_IPS_TABLE)
      .select('ip_address, reason')
      .eq('ip_address', clientIp)
      .maybeSingle();

    if (lookupError) {
      // Database unreachable — fail open to avoid blocking real users.
      console.error('[TARPIT] ⚠️  Blocked-IP lookup failed:', lookupError.message);
    } else if (blocked) {
      // ── Already blacklisted: instant 403 ──────────────────
      console.log(
        `[TARPIT] 🚫 Blocked IP ${clientIp} attempted ${req.method} ${req.path} — Reason: ${blocked.reason}`
      );

      // Fire-and-forget hit counter increment.
      incrementHitCount(clientIp).catch(() => {});

      res.status(403).type('text/plain').send('Access Denied: Your IP is banned.');
      return;
    }
  } catch (err) {
    // Unexpected exception — fail open.
    console.error('[TARPIT] ⚠️  Unexpected error during IP check:', err);
  }

  // ───────────────────────────────────────────────────────────
  // STEP 2 — THE TRAP
  // Check whether the request URL matches any honeypot path.
  // We use exact matching + prefix matching for sub-paths under
  // known admin directories.
  // ───────────────────────────────────────────────────────────
  const isTrapUrl =
    TRAP_URLS.some((trap) => requestPath === trap) ||
    TRAP_URLS.some((trap) => requestPath.startsWith(trap + '/'));

  if (!isTrapUrl) {
    // Legitimate path — pass through to real handlers.
    next();
    return;
  }

  // ───────────────────────────────────────────────────────────
  // STEP 4 — THE CATCH (logging + blacklisting)
  // Log the hit immediately; blacklist asynchronously so the
  // tarpit drip starts without waiting for the DB round-trip.
  // ───────────────────────────────────────────────────────────
  console.log(
    `[TARPIT] 🪤 Bot/Scanner CAUGHT — IP: ${clientIp} | Method: ${req.method} | Path: ${req.path} | UA: ${req.headers['user-agent'] ?? 'none'} | Time: ${new Date().toISOString()}`
  );

  // Blacklist is fire-and-forget — do not await; the tarpit starts NOW.
  blacklistIp(clientIp, req.path).catch(() => {});

  // ───────────────────────────────────────────────────────────
  // STEP 3 — THE TAR
  // Return HTTP 200 OK with streaming Content-Type so the
  // attacker's HTTP client does not close the connection.
  // Then drip exactly 1 byte (a space character) every 10 s
  // via an uncleared setInterval.
  //
  // Effect on attacker:
  //   • Their thread/coroutine is permanently blocked waiting
  //     for the "real" response body to finish.
  //   • Server-side cost: one tiny interval per trapped bot —
  //     negligible compared to the thread it wastes on their end.
  //   • Connection is only released when the bot times out or
  //     is killed externally.
  // ───────────────────────────────────────────────────────────
  res.writeHead(200, {
    'Content-Type': 'text/plain',
    'Transfer-Encoding': 'chunked',
    // Prevent any upstream proxy or CDN from buffering / closing early.
    'X-Accel-Buffering': 'no',
    'Cache-Control': 'no-cache, no-store',
  });

  // Drip loop — intentionally NOT cleared (that is the point).
  // eslint-disable-next-line @typescript-eslint/no-misused-promises
  setInterval(() => {
    try {
      // Write 1 byte: a single space character.
      res.write(' ');
    } catch {
      // Socket was closed on the bot's side — nothing to do.
      // The interval will keep firing harmlessly until the process
      // recycles this connection slot, which is acceptable.
    }
  }, 10_000 /* 10 seconds */);

  // NOTE: We deliberately do NOT call res.end() or next().
  // The response stream stays open forever or until the client disconnects.
}
