import pg from 'pg';
import { newDb } from 'pg-mem';
import { postgresSchema } from './schema.js';

let pool = null;

function normalizeSql(sql) {
  if (!sql.includes('?')) return sql;
  let index = 1;
  return sql.replace(/\?/g, () => `$${index++}`);
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
      console.log('[DB] Conectado exitosamente a PostgreSQL Cloud (Neon / Supabase / etc).');
    } catch (err) {
      console.error('[DB] Error conectando a PostgreSQL con DATABASE_URL:', err.message);
      throw err;
    }
  } else {
    // Modo Fallback Local In-Memory PostgreSQL (pg-mem)
    console.log('[DB] ⚠️ DATABASE_URL no configurada.');
    console.log('[DB] Iniciando PostgreSQL en memoria para desarrollo local.');
    console.log('[DB] Para base de datos permanente en la nube gratuita (Neon / Supabase), configura DATABASE_URL en .env');

    const memDb = newDb();
    const memPg = memDb.adapters.createPg();
    pool = new memPg.Pool();
  }

  // Ejecutar migraciones iniciales
  await pool.query(postgresSchema);
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
