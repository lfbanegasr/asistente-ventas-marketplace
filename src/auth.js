const encoder = new TextEncoder();
const SESSION_SECONDS = 7 * 24 * 60 * 60;
const WINDOW_SECONDS = 15 * 60;
const MAX_ATTEMPTS = 5;
const authHeaders = { 'Cache-Control': 'no-store' };
function reply(data, status = 200, extraHeaders = {}) {
  return Response.json(data, { status, headers: { ...authHeaders, ...extraHeaders } });
}

function passwordReady(env) {
  return typeof env.APP_PASSWORD === 'string' && env.APP_PASSWORD.length >= 16;
}

function encode(bytes) {
  let value = '';
  for (const byte of bytes) value += String.fromCharCode(byte);
  return btoa(value).replaceAll('+', '-').replaceAll('/', '_').replace(/=+$/, '');
}

function decode(value) {
  const padded = value.replaceAll('-', '+').replaceAll('_', '/') + '='.repeat((4 - value.length % 4) % 4);
  return Uint8Array.from(atob(padded), character => character.charCodeAt(0));
}

async function key(env) {
  return crypto.subtle.importKey('raw', encoder.encode(`ventas-session-v1:${env.APP_PASSWORD}`), { name: 'HMAC', hash: 'SHA-256' }, false, ['sign', 'verify']);
}

async function hash(value) {
  return new Uint8Array(await crypto.subtle.digest('SHA-256', encoder.encode(value)));
}

async function passwordsMatch(submitted, expected) {
  if (typeof submitted !== 'string' || submitted.length > 256) return false;
  const [left, right] = await Promise.all([hash(submitted), hash(expected)]);
  let different = 0;
  for (let index = 0; index < left.length; index++) different |= left[index] ^ right[index];
  return different === 0;
}

function cookieValue(request) {
  const match = request.headers.get('cookie')?.match(/(?:^|;\s*)ventas_session=([^;]*)/);
  return match?.[1] || '';
}

async function authenticated(request, env) {
  if (!passwordReady(env)) return false;
  const token = cookieValue(request);
  const parts = token.split('.');
  if (parts.length !== 2 || parts.some(part => !/^[A-Za-z0-9_-]{1,500}$/.test(part))) return false;
  try {
    const valid = await crypto.subtle.verify('HMAC', await key(env), decode(parts[1]), encoder.encode(parts[0]));
    if (!valid) return false;
    const payload = JSON.parse(new TextDecoder().decode(decode(parts[0])));
    return payload.v === 1 && Number.isSafeInteger(payload.exp) && payload.exp > Date.now() && payload.exp <= Date.now() + SESSION_SECONDS * 1000 && typeof payload.nonce === 'string';
  } catch { return false; }
}

async function sessionCookie(env) {
  const payload = encode(encoder.encode(JSON.stringify({ v: 1, exp: Date.now() + SESSION_SECONDS * 1000, nonce: crypto.randomUUID() })));
  const signature = encode(new Uint8Array(await crypto.subtle.sign('HMAC', await key(env), encoder.encode(payload))));
  return `ventas_session=${payload}.${signature}; HttpOnly; Secure; SameSite=Lax; Path=/; Max-Age=${SESSION_SECONDS}`;
}

function clearCookie() {
  return 'ventas_session=; HttpOnly; Secure; SameSite=Lax; Path=/; Max-Age=0';
}

async function bucket(request, env) {
  const ip = request.headers.get('cf-connecting-ip') || 'unknown';
  return encode(await hash(`login-v1:${env.APP_PASSWORD}:${ip}`));
}

async function login(request, env) {
  if (!passwordReady(env)) return reply({ error: 'Falta configurar APP_PASSWORD con al menos 16 caracteres.' }, 503);
  if (!env.DB) return reply({ error: 'Base de datos sin configurar.' }, 503);
  await env.DB.exec('CREATE TABLE IF NOT EXISTS auth_attempts (bucket TEXT PRIMARY KEY, attempts INTEGER NOT NULL, reset_at INTEGER NOT NULL);');
  const id = await bucket(request, env);
  const now = Math.floor(Date.now() / 1000);
  const row = await env.DB.prepare('INSERT INTO auth_attempts(bucket,attempts,reset_at) VALUES (?,1,?) ON CONFLICT(bucket) DO UPDATE SET attempts=CASE WHEN reset_at<=? THEN 1 ELSE attempts+1 END, reset_at=CASE WHEN reset_at<=? THEN excluded.reset_at ELSE reset_at END RETURNING attempts')
    .bind(id, now + WINDOW_SECONDS, now, now).first();
  if (row.attempts > MAX_ATTEMPTS) return reply({ error: 'Demasiados intentos. Espera 15 minutos.' }, 429);

  let data;
  try {
    if (!request.headers.get('content-type')?.startsWith('application/json') || Number(request.headers.get('content-length') || 0) > 2000) throw new Error();
    const raw = await request.text();
    if (raw.length > 2000) throw new Error();
    data = JSON.parse(raw);
  } catch { return reply({ error: 'Solicitud inválida.' }, 400); }
  const valid = await passwordsMatch(data?.password, env.APP_PASSWORD);
  if (!valid) return reply({ error: 'Contraseña incorrecta.' }, 401);
  await env.DB.prepare('DELETE FROM auth_attempts WHERE bucket=?').bind(id).run();
  return reply({ ok: true }, 200, { 'Set-Cookie': await sessionCookie(env) });
}

export { authenticated, clearCookie, login, passwordReady };
