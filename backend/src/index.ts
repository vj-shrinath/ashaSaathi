import express from 'express';
import cors from 'cors';
import dotenv from 'dotenv';
import visitRoutes from './routes/visitRoutes';
import webhookRoutes from './routes/webhookRoutes';
import emergencyRoutes from './routes/emergencyRoutes';

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

// Health Check
app.get('/health', (_req, res) => {
  res.status(200).json({ status: 'ok', service: 'ASHA Saathi AI API', version: '1.0.0' });
});

// Routes
app.use('/api/v1/visit', visitRoutes);
app.use('/api/v1/webhooks', webhookRoutes);
app.use('/api/v1/emergency', emergencyRoutes);

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
