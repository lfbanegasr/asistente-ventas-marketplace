import { readFileSync, existsSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join, resolve } from 'node:path';

const thisDir = dirname(fileURLToPath(import.meta.url));

function findMigrationsDir() {
  const devPath = resolve(thisDir, '..', '..', 'migrations');
  if (existsSync(devPath)) return devPath;
  const dockerPath = resolve(thisDir, '..', 'migrations');
  if (existsSync(dockerPath)) return dockerPath;
  throw new Error('No se encontró el directorio de migraciones.');
}

const migrationsDir = findMigrationsDir();

function loadSql(name) {
  return readFileSync(join(migrationsDir, name), 'utf8');
}

export const postgresSchema = loadSql('0001_postgres_init.sql');
