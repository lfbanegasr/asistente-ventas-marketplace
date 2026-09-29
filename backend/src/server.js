import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import { login, session } from './auth.js';
import { authenticate } from './middleware/authenticate.js';
import { initDb, query, closeDb, getDbDiagnosis } from './database.js';
import productsRouter from './routes/products.js';
import leadsRouter from './routes/leads.js';
import chatsRouter from './routes/chats.js';
import aiRouter from './routes/ai.js';
import agentRouter from './routes/agent.js';

const app = express();
const PORT = process.env.PORT || 3001;

// ── Security ─────────────────────────────────────────────────
app.use(helmet());
app.set('trust proxy', 1);

// ── CORS ─────────────────────────────────────────────────────
const allowedOrigins = (process.env.CORS_ORIGINS || 'http://localhost:5173')
  .split(',')
  .map(o => o.trim())
  .filter(Boolean);

app.use(cors({
  origin(origin, callback) {
    // Permitir llamadas sin origin (apps móviles, curl, etc.)
    if (!origin) return callback(null, true);

    const isLocal = origin.includes('localhost') || origin.includes('127.0.0.1');
    const isVercel = origin.endsWith('.vercel.app');
    const isExplicit = allowedOrigins.includes('*') || allowedOrigins.includes(origin);

    if (isLocal || isVercel || isExplicit) {
      callback(null, true);
    } else {
      console.warn(`[CORS] Origen bloqueado: ${origin}. Permitidos: ${allowedOrigins.join(', ')}`);
      callback(new Error('Origen no permitido por CORS.'));
    }
  },
  credentials: true,
  maxAge: 86400
}));

// ── Body parsing ─────────────────────────────────────────────
app.use(express.json({ limit: '12kb' }));

// ── Public routes ────────────────────────────────────
app.post('/api/login', login);
app.get('/api/session', session);

// ── Health check & Diagnostics ───────────────────────
const healthCheckHandler = async (req, res) => {
  try {
    const diagnosis = await getDbDiagnosis();
    const isHealthy = diagnosis.connected;
    res.status(isHealthy ? 200 : 503).json({
      status: isHealthy ? 'ok' : 'degraded',
      service: 'asistente-ventas-backend',
      uptime_seconds: Math.floor(process.uptime()),
      database: diagnosis,
      timestamp: new Date().toISOString(),
    });
  } catch (err) {
    res.status(503).json({ status: 'error', message: err.message });
  }
};
app.get('/health', healthCheckHandler);
app.get('/api/health', healthCheckHandler);

// ── Protected routes ─────────────────────────────────
app.use('/api/products', authenticate, productsRouter);
app.use('/api/leads', authenticate, leadsRouter);
app.use('/api/chats', authenticate, chatsRouter);
app.use('/api/ai', authenticate, aiRouter);
app.use('/api/agent', authenticate, agentRouter);

// Combined state endpoint
app.get('/api/state', authenticate, async (req, res) => {
  try {
    const rawProducts = await query(
      'SELECT p.*, c.checked_at AS availability_checked_at FROM products p LEFT JOIN availability_checks c ON c.product_id=p.id ORDER BY p.name'
    );
    const products = rawProducts.map(p => ({
      ...p,
      availability_checked_at: p.availability_checked_at ? new Date(p.availability_checked_at).toISOString() : ''
    }));
    const leads = await query(
      "SELECT l.*, p.name AS product_name FROM leads l JOIN products p ON p.id=l.product_id ORDER BY CASE WHEN l.status='entregado' THEN 1 ELSE 0 END, l.updated_at DESC LIMIT 500"
    );
    res.json({ products, leads, ai_ready: !!process.env.GEMINI_API_KEY });
  } catch (err) {
    console.error('Error fetching state:', err);
    res.status(500).json({ error: 'Error al obtener estado.' });
  }
});

// ── Error handling ───────────────────────────────────
app.use((err, req, res, _next) => {
  if (err.message === 'Origen no permitido por CORS.') {
    return res.status(403).json({ error: 'Origen no permitido.' });
  }
  console.error('Request failed:', err.message || err);
  res.status(500).json({ error: 'Ocurrió un error. Reintenta una vez.' });
});

// ── Catch-all 404 ────────────────────────────────────
app.use((req, res) => {
  res.status(404).json({ error: 'Ruta no encontrada.' });
});

// ── Keep-Alive Pinger (Render Free Tier Sleep Prevention) ───
let pingerInterval = null;

function startKeepAlive() {
  const isProd = process.env.NODE_ENV === 'production' || !!process.env.RENDER || !!process.env.RENDER_EXTERNAL_URL;
  const enabled = process.env.KEEP_ALIVE === 'true' || isProd;
  if (!enabled) return;

  const target = process.env.RENDER_EXTERNAL_URL
    ? `${process.env.RENDER_EXTERNAL_URL.replace(/\/$/, '')}/api/health`
    : (process.env.KEEP_ALIVE_URL || 'https://asistente-ventas-marketplace.onrender.com/api/health');

  // Ping cada 10 minutos (Render duerme a los 15 min de inactividad)
  const intervalMs = Number(process.env.KEEP_ALIVE_INTERVAL_MS) || 600000;

  console.log(`[Keep-Alive] Servicio de prevención de latencia activo hacia ${target} (cada ${intervalMs / 1000}s)`);

  pingerInterval = setInterval(async () => {
    try {
      const res = await fetch(target, {
        headers: { 'User-Agent': 'MesaVentas-KeepAlive/1.0' }
      });
      console.log(`[Keep-Alive] Ping ${target} -> HTTP ${res.status}`);
    } catch (err) {
      console.warn(`[Keep-Alive] Ping falló a ${target}:`, err.message);
    }
  }, intervalMs);

  if (pingerInterval.unref) pingerInterval.unref();
}

// ── Start server ─────────────────────────────────────
async function start() {
  await initDb();

  const server = app.listen(PORT, '0.0.0.0', () => {
    console.log(`Backend listening on port ${PORT}`);
    startKeepAlive();
  });

  async function shutdown() {
    console.log('Shutting down gracefully...');
    if (pingerInterval) clearInterval(pingerInterval);
    server.close(async () => {
      await closeDb();
      process.exit(0);
    });
  }
  process.on('SIGTERM', shutdown);
  process.on('SIGINT', shutdown);
}

start().catch(err => {
  console.error('Failed to start server:', err);
  process.exit(1);
});

export default app;
