const BASE = 'https://ashasaathibackend.onrender.com';

const tests = [
  { label: 'Health check',              method: 'GET',  path: '/health',                         body: null },
  { label: 'Register worker',           method: 'POST', path: '/api/v1/auth/register-worker',    body: { phone: '0000000000', password: 'x', fullName: 'x', role: 'asha' } },
  { label: 'Verify sync token',         method: 'POST', path: '/api/v1/auth/verify-sync-token',  body: { phone: '0000000000', pin: '123456' } },
  { label: 'Admin generate sync token', method: 'POST', path: '/api/v1/auth/admin/generate-sync-token', body: { phone: '0000000000' } },
];

(async () => {
  for (const t of tests) {
    const opts = { method: t.method, headers: { 'Content-Type': 'application/json' } };
    if (t.body) opts.body = JSON.stringify(t.body);
    try {
      const r = await fetch(BASE + t.path, opts);
      const text = await r.text();
      const isHtml = text.trimStart().startsWith('<');
      console.log(`[${r.status}] ${t.label}: ${isHtml ? '⚠️  HTML response (route not found)' : text.slice(0, 120)}`);
    } catch(e) {
      console.log(`[ERR] ${t.label}: ${e.message}`);
    }
  }
})();
