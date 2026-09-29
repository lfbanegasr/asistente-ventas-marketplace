import { writeFileSync, mkdirSync, existsSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import pg from 'pg';

const __dirname = dirname(fileURLToPath(import.meta.url));

async function exportBackup() {
  const connectionString = process.env.DATABASE_URL;
  if (!connectionString) {
    console.error('❌ Error: Define la variable DATABASE_URL antes de ejecutar este script.');
    console.error('Ejemplo: $env:DATABASE_URL="postgresql://..." ; node src/scripts/export-backup.js');
    process.exit(1);
  }

  const isLocalhost = connectionString.includes('localhost') || connectionString.includes('127.0.0.1');
  const pool = new pg.Pool({
    connectionString,
    ssl: isLocalhost ? false : { rejectUnauthorized: false }
  });

  try {
    console.log('🔄 Conectando a la base de datos PostgreSQL...');
    const client = await pool.connect();
    console.log('✅ Conexión establecida.');

    const productsRes = await client.query('SELECT * FROM products ORDER BY name');
    const checksRes = await client.query('SELECT * FROM availability_checks');
    const leadsRes = await client.query('SELECT * FROM leads ORDER BY created_at DESC');
    const threadsRes = await client.query('SELECT * FROM chat_threads ORDER BY created_at DESC');
    const turnsRes = await client.query('SELECT * FROM chat_turns ORDER BY created_at ASC');
    const aiUsageRes = await client.query('SELECT * FROM ai_usage ORDER BY day DESC');

    client.release();

    const backupData = {
      exported_at: new Date().toISOString(),
      counts: {
        products: productsRes.rowCount,
        availability_checks: checksRes.rowCount,
        leads: leadsRes.rowCount,
        chat_threads: threadsRes.rowCount,
        chat_turns: turnsRes.rowCount,
        ai_usage: aiUsageRes.rowCount,
      },
      data: {
        products: productsRes.rows,
        availability_checks: checksRes.rows,
        leads: leadsRes.rows,
        chat_threads: threadsRes.rows,
        chat_turns: turnsRes.rows,
        ai_usage: aiUsageRes.rows,
      }
    };

    const outDir = join(__dirname, '..', '..', 'backups');
    if (!existsSync(outDir)) {
      mkdirSync(outDir, { recursive: true });
    }

    const dateStr = new Date().toISOString().replace(/[:.]/g, '-');
    const jsonPath = join(outDir, `backup-${dateStr}.json`);
    writeFileSync(jsonPath, JSON.stringify(backupData, null, 2), 'utf8');

    // Export leads to CSV as well
    const cols = ['id', 'alias', 'channel', 'product_id', 'status', 'amount', 'actual_cost', 'expenses', 'delivery_mode', 'delivery_place', 'delivery_at', 'paid', 'notes', 'created_at'];
    const quote = v => `"${String(v ?? '').replaceAll('"', '""')}"`;
    const csvContent = '\ufeff' + [cols.join(','), ...leadsRes.rows.map(row => cols.map(col => quote(row[col])).join(','))].join('\r\n');
    const csvPath = join(outDir, `leads-${dateStr}.csv`);
    writeFileSync(csvPath, csvContent, 'utf8');

    console.log(`\n🎉 Respaldo completado con éxito:`);
    console.log(`- Archivo JSON completo: ${jsonPath}`);
    console.log(`- Archivo CSV de leads:  ${csvPath}`);
    console.log(`- Total productos:       ${productsRes.rowCount}`);
    console.log(`- Total consultas:       ${leadsRes.rowCount}`);
    console.log(`- Total conversaciones:  ${threadsRes.rowCount}`);
    console.log(`- Total mensajes chat:   ${turnsRes.rowCount}`);
  } catch (err) {
    console.error('❌ Error durante el respaldo:', err.message);
  } finally {
    await pool.end();
  }
}

exportBackup();
