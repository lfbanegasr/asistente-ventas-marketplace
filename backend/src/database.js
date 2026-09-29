import pg from 'pg';
import { newDb } from 'pg-mem';
import { postgresSchema } from './schema.js';

let pool = null;
let dbType = 'uninitialized';

function maskUri(uri) {
  if (!uri) return 'none';
  try {
    const parsed = new URL(uri);
    return `${parsed.protocol}//${parsed.username ? '***' : ''}${parsed.password ? ':***@' : ''}${parsed.host}${parsed.pathname}`;
  } catch (_) {
    return uri.replace(/:([^@]+)@/, ':***@');
  }
}

function normalizeSql(sql) {
  if (!sql.includes('?')) return sql;
  let index = 1;
  return sql.replace(/\?/g, () => `$${index++}`);
}

export async function getDbDiagnosis() {
  if (!pool) {
    return { type: dbType, connected: false, latency_ms: null };
  }
  const start = Date.now();
  try {
    await pool.query('SELECT 1');
    const latency_ms = Date.now() - start;
    return {
      type: dbType,
      connected: true,
      latency_ms,
      pool_total: pool.totalCount ?? 1,
      pool_idle: pool.idleCount ?? 1,
      pool_waiting: pool.waitingCount ?? 0,
    };
  } catch (err) {
    return {
      type: dbType,
      connected: false,
      error: err.message,
      latency_ms: Date.now() - start,
    };
  }
}

export async function initDb() {
  const connectionString = process.env.DATABASE_URL;

  if (connectionString && connectionString.trim() !== '') {
    // Modo Cloud PostgreSQL (Neon, Supabase, Render, Railway, etc.)
    const isLocalhost = connectionString.includes('localhost') || connectionString.includes('127.0.0.1');
    pool = new pg.Pool({
      connectionString,
      ssl: isLocalhost ? false : { rejectUnauthorized: false },
      max: 10,
      idleTimeoutMillis: 30000,
      connectionTimeoutMillis: 10000,
    });

    try {
      const client = await pool.connect();
      try {
        await client.query('SELECT 1');
      } finally {
        client.release();
      }
      dbType = 'postgres-cloud';
      console.log(`[DB] Conectado exitosamente a PostgreSQL Cloud: ${maskUri(connectionString)}`);
    } catch (err) {
      console.error('[DB] Error conectando a PostgreSQL con DATABASE_URL:', err.message);
      throw err;
    }
  } else {
    // Protección contra pérdida de datos en despliegue
    if (process.env.NODE_ENV === 'production' && process.env.ALLOW_EPHEMERAL_DB !== 'true') {
      const errorMsg = '[DB] 🚨 FATAL: En producción es obligatorio configurar DATABASE_URL (Neon / Supabase). Para pruebas volátiles defina ALLOW_EPHEMERAL_DB=true.';
      console.error(errorMsg);
      throw new Error(errorMsg);
    }

    // Modo Fallback Local In-Memory PostgreSQL (pg-mem)
    console.log('[DB] ⚠️ DATABASE_URL no configurada.');
    console.log('[DB] Iniciando PostgreSQL en memoria (pg-mem) para desarrollo o tests locales.');
    console.log('[DB] Para persistencia en la nube (Neon / Supabase), configura DATABASE_URL en variables de entorno.');

    const memDb = newDb();
    const memPg = memDb.adapters.createPg();
    pool = new memPg.Pool();
    dbType = 'pg-mem-fallback';
  }

  // Ejecutar migraciones iniciales
  await pool.query(postgresSchema);
  try {
    await pool.query('ALTER TABLE products ADD COLUMN IF NOT EXISTS is_active BOOLEAN NOT NULL DEFAULT TRUE');
  } catch (_e) {
    // Columna ya existe o base de datos en memoria inicializada
  }
  console.log('[DB] Tablas y esquema de PostgreSQL inicializados correctamente.');
}

export async function query(sql, params = []) {
  const pgSql = normalizeSql(sql);
  const res = await pool.query(pgSql, params);
  return res.rows;
}

export async function queryFirst(sql, params = []) {
  const rows = await query(sql, params);
  return rows[0] || null;
}

export async function run(sql, params = []) {
  const pgSql = normalizeSql(sql);
  const res = await pool.query(pgSql, params);
  return {
    changes: res.rowCount ?? 0,
    rows: res.rows || []
  };
}

export async function closeDb() {
  if (pool) {
    await pool.end();
  }
}
