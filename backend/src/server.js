import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import { login, session } from './auth.js';
import { authenticate } from './middleware/authenticate.js';
import { initDb, query, closeDb } from './database.js';
import productsRouter from './routes/products.js';
import leadsRouter from './routes/leads.js';
import chatsRouter from './routes/chats.js';
import aiRouter from './routes/ai.js';

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
    if (!origin || allowedOrigins.includes(origin)) {
      callback(null, true);
    } else {
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

// ── Health check ─────────────────────────────────────
app.get('/api/health', async (req, res) => {
  try {
    await query('SELECT 1');
    res.json({ status: 'ok', service: 'asistente-ventas-backend' });
  } catch (err) {
    res.status(503).json({ status: 'error', message: err.message });
  }
});

// ── Protected routes ─────────────────────────────────
app.use('/api/products', authenticate, productsRouter);
app.use('/api/leads', authenticate, leadsRouter);
app.use('/api/chats', authenticate, chatsRouter);
app.use('/api/ai', authenticate, aiRouter);

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

// ── Start server ─────────────────────────────────────
async function start() {
  await initDb();

  const server = app.listen(PORT, '0.0.0.0', () => {
    console.log(`Backend listening on port ${PORT}`);
  });

  async function shutdown() {
    console.log('Shutting down gracefully...');
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
