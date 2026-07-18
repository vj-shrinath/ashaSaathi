import express from 'express';
import cors from 'cors';
import dotenv from 'dotenv';
import visitRoutes from './routes/visitRoutes';
import webhookRoutes from './routes/webhookRoutes';
import emergencyRoutes from './routes/emergencyRoutes';
import authRoutes from './routes/authRoutes';
import { tarpitMiddleware } from './middleware/tarpitMiddleware';

dotenv.config();

const app = express();
const PORT = parseInt(process.env.PORT || '3000', 10);
const HOST = process.env.HOST || '0.0.0.0';

const allowedOrigins = [
  'http://localhost:3000',
  'http://10.0.2.2:3000',
  'http://192.168.*.*',
  'http://10.*.*.*',
  'http://172.16.*.*',
  'http://172.17.*.*',
  'http://172.18.*.*',
  'http://172.19.*.*',
  'http://172.20.*.*',
  'http://172.21.*.*',
  'http://172.22.*.*',
  'http://172.23.*.*',
  'http://172.24.*.*',
  'http://172.25.*.*',
  'http://172.26.*.*',
  'http://172.27.*.*',
  'http://172.28.*.*',
  'http://172.29.*.*',
  'http://172.30.*.*',
  'http://172.31.*.*',
];

// ─── SECURITY: Tarpit — must be the FIRST middleware registered ───────────────
// Checks every inbound request against the blacklist and honeypot trap URLs
// before CORS, parsing, logging, or any route handler runs.
app.use(tarpitMiddleware);

app.use(cors({
  origin: (origin, callback) => {
    if (!origin) return callback(null, true);
    if (allowedOrigins.some(o => origin.match(new RegExp('^' + o.replace('*', '.*') + '$')))) {
      return callback(null, true);
    }
    return callback(null, true);
  },
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization'],
}));
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Request logging
app.use((req, _res, next) => {
  console.log(`[${new Date().toISOString()}] ${req.method} ${req.path}`);
  next();
});

// Health Check — HTML for browsers, JSON for API clients
const startTime = new Date();

app.get('/health', (req, res) => {
  const uptimeMs = Date.now() - startTime.getTime();
  const uptimeSecs = Math.floor(uptimeMs / 1000);
  const hours   = Math.floor(uptimeSecs / 3600);
  const minutes = Math.floor((uptimeSecs % 3600) / 60);
  const seconds = uptimeSecs % 60;
  const uptimeStr = `${hours}h ${minutes}m ${seconds}s`;

  const acceptsHtml = req.headers.accept?.includes('text/html');

  if (!acceptsHtml) {
    // API clients (curl, Flutter, Postman) get clean JSON
    res.status(200).json({
      status: 'ok',
      service: 'ASHA Saathi AI API',
      version: '1.0.0',
      uptime: uptimeStr,
      timestamp: new Date().toISOString(),
    });
    return;
  }

  // Browsers get a rich HTML status page
  const now = new Date().toLocaleString('en-IN', { timeZone: 'Asia/Kolkata' });
  res.status(200).send(`<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8"/>
  <meta name="viewport" content="width=device-width, initial-scale=1.0"/>
  <title>ASHA Saathi AI — Service Status</title>
  <link rel="preconnect" href="https://fonts.googleapis.com"/>
  <link href="https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700&display=swap" rel="stylesheet"/>
  <style>
    *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      font-family: 'Inter', sans-serif;
      background: #0a0e1a;
      color: #e2e8f0;
      min-height: 100vh;
      display: flex;
      align-items: center;
      justify-content: center;
      padding: 2rem;
    }
    .card {
      background: #111827;
      border: 1px solid #1f2937;
      border-radius: 20px;
      padding: 2.5rem;
      max-width: 560px;
      width: 100%;
      box-shadow: 0 25px 50px rgba(0,0,0,0.5);
    }
    .header {
      display: flex;
      align-items: center;
      gap: 1rem;
      margin-bottom: 2rem;
    }
    .logo {
      width: 52px; height: 52px;
      background: linear-gradient(135deg, #6366f1, #8b5cf6);
      border-radius: 14px;
      display: flex; align-items: center; justify-content: center;
      font-size: 1.5rem;
      flex-shrink: 0;
    }
    .title { font-size: 1.3rem; font-weight: 700; color: #f1f5f9; }
    .subtitle { font-size: 0.8rem; color: #64748b; margin-top: 2px; }

    .status-badge {
      display: inline-flex; align-items: center; gap: 8px;
      background: rgba(16,185,129,0.12);
      border: 1px solid rgba(16,185,129,0.3);
      color: #10b981;
      padding: 6px 14px;
      border-radius: 999px;
      font-size: 0.82rem;
      font-weight: 600;
      margin-bottom: 1.8rem;
    }
    .dot {
      width: 8px; height: 8px;
      background: #10b981;
      border-radius: 50%;
      animation: pulse 2s ease-in-out infinite;
    }
    @keyframes pulse {
      0%, 100% { opacity: 1; transform: scale(1); }
      50% { opacity: 0.5; transform: scale(0.8); }
    }

    .grid { display: grid; grid-template-columns: 1fr 1fr; gap: 12px; margin-bottom: 1.8rem; }
    .stat {
      background: #0f172a;
      border: 1px solid #1e293b;
      border-radius: 12px;
      padding: 14px 16px;
    }
    .stat-label { font-size: 0.72rem; color: #64748b; text-transform: uppercase; letter-spacing: 0.05em; margin-bottom: 6px; }
    .stat-value { font-size: 1.1rem; font-weight: 600; color: #f1f5f9; }

    .endpoints { margin-bottom: 1.8rem; }
    .endpoints-title { font-size: 0.72rem; color: #64748b; text-transform: uppercase; letter-spacing: 0.05em; margin-bottom: 10px; }
    .ep {
      display: flex; align-items: center; gap: 10px;
      padding: 9px 12px;
      border-radius: 8px;
      margin-bottom: 6px;
      font-size: 0.82rem;
    }
    .ep:nth-child(odd) { background: #0f172a; }
    .method {
      font-size: 0.68rem; font-weight: 700;
      padding: 2px 7px; border-radius: 4px;
      flex-shrink: 0;
    }
    .post { background: rgba(99,102,241,0.2); color: #818cf8; }
    .get  { background: rgba(16,185,129,0.15); color: #34d399; }
    .path { color: #94a3b8; font-family: 'Courier New', monospace; }
    .desc { color: #475569; font-size: 0.75rem; margin-left: auto; }

    .footer {
      text-align: center;
      font-size: 0.75rem;
      color: #334155;
      padding-top: 1.2rem;
      border-top: 1px solid #1e293b;
    }
    .footer a { color: #6366f1; text-decoration: none; }

    @media (max-width: 480px) {
      .grid { grid-template-columns: 1fr; }
      .desc { display: none; }
    }
  </style>
</head>
<body>
  <div class="card">
    <div class="header">
      <div class="logo">🌿</div>
      <div>
        <div class="title">ASHA Saathi AI</div>
        <div class="subtitle">Backend API Service · v1.0.0</div>
      </div>
    </div>

    <div class="status-badge">
      <div class="dot"></div>
      All Systems Operational
    </div>

    <div class="grid">
      <div class="stat">
        <div class="stat-label">Uptime</div>
        <div class="stat-value">${uptimeStr}</div>
      </div>
      <div class="stat">
        <div class="stat-label">Environment</div>
        <div class="stat-value">Production</div>
      </div>
      <div class="stat">
        <div class="stat-label">Region</div>
        <div class="stat-value">Singapore</div>
      </div>
      <div class="stat">
        <div class="stat-label">Last checked</div>
        <div class="stat-value" style="font-size:0.82rem">${now}</div>
      </div>
    </div>

    <div class="endpoints">
      <div class="endpoints-title">API Endpoints</div>
      <div class="ep"><span class="method post">POST</span><span class="path">/api/v1/auth/register-worker</span><span class="desc">Register</span></div>
      <div class="ep"><span class="method post">POST</span><span class="path">/api/v1/auth/verify-sync-token</span><span class="desc">Device sync</span></div>
      <div class="ep"><span class="method post">POST</span><span class="path">/api/v1/auth/admin/generate-sync-token</span><span class="desc">Admin</span></div>
      <div class="ep"><span class="method post">POST</span><span class="path">/api/v1/visit/</span><span class="desc">Visits</span></div>
      <div class="ep"><span class="method get">GET</span><span class="path">/health</span><span class="desc">This page</span></div>
    </div>

    <div class="footer">
      Deployed on <a href="https://render.com" target="_blank">Render</a> · 
      Built with Node.js + TypeScript · 
      <a href="https://supabase.com" target="_blank">Supabase</a>
    </div>
  </div>
</body>
</html>`);
});

// Routes
app.use('/api/v1/visit', visitRoutes);
app.use('/api/v1/webhooks', webhookRoutes);
app.use('/api/v1/emergency', emergencyRoutes);
app.use('/api/v1/auth', authRoutes);

// Global Error Handler
app.use((err: Error, _req: express.Request, res: express.Response, _next: express.NextFunction) => {
  console.error('[ERROR]', err.stack);
  res.status(500).json({ status: 'error', message: err.message || 'Internal Server Error' });
});

app.listen(PORT, HOST, () => {
  console.log(`✅ ASHA Saathi AI Backend running on ${HOST}:${PORT}`);
  console.log(`   Health: http://${HOST === '0.0.0.0' ? 'localhost' : HOST}:${PORT}/health`);
  console.log(`   API Base: http://${HOST === '0.0.0.0' ? 'localhost' : HOST}:${PORT}/api/v1`);
});
