import { createHash, timingSafeEqual, randomUUID } from 'node:crypto';
import jwt from 'jsonwebtoken';
import { queryFirst, run } from './database.js';

const SESSION_SECONDS = 7 * 24 * 60 * 60;
const WINDOW_SECONDS = 15 * 60;
const MAX_ATTEMPTS = 5;

export function passwordReady() {
  return typeof process.env.APP_PASSWORD === 'string' && process.env.APP_PASSWORD.length >= 16;
}

function hash(value) {
  return createHash('sha256').update(value).digest();
}

function passwordsMatch(submitted, expected) {
  if (typeof submitted !== 'string' || submitted.length > 256) return false;
  const left = hash(submitted);
  const right = hash(expected);
  return timingSafeEqual(left, right);
}

function bucketId(ip) {
  return hash(`login-v1:${process.env.APP_PASSWORD}:${ip}`).toString('base64url');
}

export function generateToken() {
  return jwt.sign(
    { v: 1, nonce: randomUUID() },
    process.env.JWT_SECRET,
    { expiresIn: SESSION_SECONDS }
  );
}

export function verifyToken(token) {
  try {
    const payload = jwt.verify(token, process.env.JWT_SECRET);
    return payload.v === 1 && typeof payload.nonce === 'string';
  } catch {
    return false;
  }
}

export async function login(req, res) {
  if (!passwordReady()) {
    return res.status(503).json({ error: 'Falta configurar APP_PASSWORD con al menos 16 caracteres.' });
  }

  const ip = req.headers['x-forwarded-for']?.split(',')[0]?.trim() || req.ip || 'unknown';
  const id = bucketId(ip);
  const now = Math.floor(Date.now() / 1000);

  // Rate limiting
  const existing = await queryFirst('SELECT attempts, reset_at FROM auth_attempts WHERE bucket=?', [id]);
  let attempts;
  if (!existing) {
    await run('INSERT INTO auth_attempts(bucket,attempts,reset_at) VALUES (?,1,?)', [id, now + WINDOW_SECONDS]);
    attempts = 1;
  } else if (Number(existing.reset_at) <= now) {
    await run('UPDATE auth_attempts SET attempts=1, reset_at=? WHERE bucket=?', [now + WINDOW_SECONDS, id]);
    attempts = 1;
  } else {
    await run('UPDATE auth_attempts SET attempts=attempts+1 WHERE bucket=?', [id]);
    attempts = Number(existing.attempts) + 1;
  }

  if (attempts > MAX_ATTEMPTS) {
    return res.status(429).json({ error: 'Demasiados intentos. Espera 15 minutos.' });
  }

  const password = req.body?.password;
  if (!passwordsMatch(password, process.env.APP_PASSWORD)) {
    return res.status(401).json({ error: 'Contraseña incorrecta.' });
  }

  await run('DELETE FROM auth_attempts WHERE bucket=?', [id]);

  const token = generateToken();
  const expiresAt = Date.now() + SESSION_SECONDS * 1000;

  return res.json({ ok: true, token, expiresAt });
}

export function session(req, res) {
  const token = extractToken(req);
  const authenticated = token ? verifyToken(token) : false;
  return res.json({ authenticated, configured: passwordReady() });
}

export function extractToken(req) {
  const auth = req.headers.authorization;
  if (auth?.startsWith('Bearer ')) return auth.slice(7);
  return null;
}
