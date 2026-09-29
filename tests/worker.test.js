import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { DatabaseSync } from 'node:sqlite';
import worker from '../src/worker.js';

function setup(seed = true) {
  const db = new DatabaseSync(':memory:');
  if (seed) db.exec(readFileSync(new URL('../migrations/0001_init.sql', import.meta.url), 'utf8'));
  const DB = { prepare(sql) { const statement = db.prepare(sql); return { bind(...args) { return { first: async () => statement.get(...args) || null, all: async () => ({ results: statement.all(...args) }), run: async () => ({ meta: { changes: statement.run(...args).changes } }) }; }, first: async () => statement.get() || null, all: async () => ({ results: statement.all() }) }; }, exec: async sql => { db.exec(sql); return { count: 1 }; } };
  const env = { DB, APP_PASSWORD: 'a long private password for tests' };
  const call = (path, method = 'GET', data, cookie = '', origin = 'https://local.test') => worker.fetch(new Request(`https://local.test${path}`, { method, headers: { ...(data ? { 'Content-Type': 'application/json' } : {}), ...(!['GET', 'HEAD'].includes(method) ? { Origin: origin } : {}), ...(cookie ? { Cookie: cookie } : {}) }, body: data ? JSON.stringify(data) : undefined }), env, {});
  const signIn = async () => (await call('/api/login', 'POST', { password: env.APP_PASSWORD })).headers.get('set-cookie').split(';')[0];
  return { db, call, signIn, env };
}

test('private data requires app sign-in, and sign-out clears the browser cookie', async () => {
  const { call, signIn } = setup();
  assert.equal((await call('/api/state')).status, 401);
  assert.equal((await call('/')).status, 302);
  assert.equal((await call('/login')).status, 200);
  const cookie = await signIn();
  assert.match(cookie, /^ventas_session=/);
  assert.equal((await call('/api/session', 'GET', undefined, cookie)).status, 200);
  const response = await call('/api/state', 'GET', undefined, cookie);
  assert.equal(response.status, 200);
  assert.equal((await response.json()).products.length, 3);
  const logout = await call('/api/logout', 'POST', undefined, cookie);
  assert.equal(logout.status, 200);
  assert.match(logout.headers.get('set-cookie'), /Max-Age=0/);
  assert.equal((await call('/api/state', 'GET', undefined, cookie + 'x')).status, 401);
});

test('changing the password invalidates existing sessions', async () => {
  const { call, signIn, env } = setup();
  const cookie = await signIn();
  env.APP_PASSWORD = 'another long private password for tests';
  assert.equal((await call('/api/state', 'GET', undefined, cookie)).status, 401);
});

test('wrong password and cross-site posts are rejected', async () => {
  const { call } = setup();
  assert.equal((await call('/api/login', 'POST', { password: 'wrong' }, '', 'https://other.test')).status, 403);
  for (let attempt = 0; attempt < 5; attempt++) assert.equal((await call('/api/login', 'POST', { password: 'wrong' })).status, 401);
  assert.equal((await call('/api/login', 'POST', { password: 'wrong' })).status, 429);
});

test('missing password configuration fails closed', async () => {
  const { call, env } = setup();
  delete env.APP_PASSWORD;
  assert.equal((await call('/api/login', 'POST', { password: 'anything' })).status, 503);
  assert.equal((await call('/api/state')).status, 401);
});

test('the same save request creates only one consultation', async () => {
  const { db, call, signIn } = setup();
  const cookie = await signIn();
  const data = { request_id: '0b379d57-2843-43bf-bb19-1fd80bbf69c0', alias: 'Cliente A', channel: 'Marketplace', product_id: 'kp5501', status: 'agendado', amount: 155, actual_cost: 85, expenses: 5, delivery_mode: 'persona', delivery_place: 'UAGRM', delivery_at: '2026-10-01T16:00', paid: false, notes: 'Confirmar antes de salir' };
  const first = await call('/api/leads', 'POST', data, cookie), second = await call('/api/leads', 'POST', data, cookie);
  assert.equal(first.status, 201); assert.equal(second.status, 200);
  assert.equal((await first.json()).id, (await second.json()).id);
  assert.equal(db.prepare('SELECT COUNT(*) AS count FROM leads').get().count, 1);
  const saved = db.prepare('SELECT status,amount,delivery_place,notes FROM leads').get();
  assert.deepEqual({ ...saved }, { status: 'agendado', amount: 155, delivery_place: 'UAGRM', notes: 'Confirmar antes de salir' });
});

test('cannot mark a delivery complete without verified payment or valid details', async () => {
  const { db, call, signIn } = setup();
  const cookie = await signIn();
  const data = { request_id: crypto.randomUUID(), alias: 'Cliente B', channel: 'WhatsApp', product_id: 'pb6010', status: 'entregado', delivery_mode: 'yango', delivery_place: 'Centro', delivery_at: '2026-02-30T25:00', paid: false };
  assert.equal((await call('/api/leads', 'POST', data, cookie)).status, 400);
  data.delivery_at = '2026-10-01T16:00';
  assert.equal((await call('/api/leads', 'POST', data, cookie)).status, 400);
  assert.equal(db.prepare('SELECT COUNT(*) AS count FROM leads').get().count, 0);
  data.paid = true;
  assert.equal((await call('/api/leads', 'POST', data, cookie)).status, 201);
});

test('existing product data is kept and availability needs explicit verification', async () => {
  const { db, call, signIn } = setup();
  const cookie = await signIn();
  const initial = await (await call('/api/state', 'GET', undefined, cookie)).json();
  assert.equal(initial.products.find(p => p.id === 'pb6010').availability_checked_at, '');
  const product = initial.products.find(p => p.id === 'pb6010');
  const save = async updates => call('/api/products/pb6010', 'PATCH', { ...product, availability: 'en_mano', available_units: 1, ...updates }, cookie);
  assert.equal((await save({ availability_checked: true })).status, 200);
  assert.ok(db.prepare("SELECT checked_at FROM availability_checks WHERE product_id='pb6010'").get().checked_at);
  assert.equal((await save({ available_units: 2, availability_checked: false })).status, 200);
  assert.equal(db.prepare("SELECT checked_at FROM availability_checks WHERE product_id='pb6010'").get(), undefined);
  assert.equal((await save({ availability: 'por_confirmar', available_units: 1 })).status, 400);
});

test('AI draft does not run without a server-side key', async () => {
  const { call, signIn } = setup();
  const response = await call('/api/ai', 'POST', { product_id: 'pb6010', customer_message: '¿Está disponible?' }, await signIn());
  assert.equal(response.status, 503);
});

test('a fresh Cloudflare database initializes when its owner first opens the app', async () => {
  const { db, call, signIn } = setup(false);
  const response = await call('/api/state', 'GET', undefined, await signIn());
  assert.equal(response.status, 200);
  assert.equal((await response.json()).products.length, 3);
  assert.equal(db.prepare('SELECT COUNT(*) AS count FROM products').get().count, 3);
});

test('chat history stays private and a retried message is stored only once', async () => {
  const { db, call, signIn } = setup();
  const chatId = crypto.randomUUID(), requestId = crypto.randomUUID();
  assert.equal((await call('/api/chats')).status, 401);
  assert.equal((await call('/api/chats', 'POST', { id: chatId, product_id: 'pb6010' })).status, 401);
  const cookie = await signIn();
  assert.equal((await call('/api/chats', 'POST', { id: chatId, product_id: 'pb6010' }, cookie)).status, 200);
  const payload = { request_id: requestId, message: 'Cliente: ¿Envío por Yango al barrio Centro? Teléfono 76543210' };
  const first = await call(`/api/chats/${chatId}/turns`, 'POST', payload, cookie);
  assert.equal(first.status, 201);
  const answer = (await first.json()).turn;
  assert.equal(answer.source, 'base');
  assert.match(answer.assistant_text, /antes de despacharlo/);
  assert.doesNotMatch(answer.user_text, /76543210/);
  const retry = await call(`/api/chats/${chatId}/turns`, 'POST', payload, cookie);
  assert.equal(retry.status, 200);
  assert.equal((await retry.json()).duplicate, true);
  assert.equal(db.prepare('SELECT COUNT(*) AS count FROM chat_turns').get().count, 1);
  const loaded = await (await call(`/api/chats/${chatId}`, 'GET', undefined, cookie)).json();
  assert.equal(loaded.turns.length, 1);
  assert.equal((await call(`/api/chats/${chatId}`)).status, 401);
});

test('Gemini failure keeps a safe base answer in the chat', async () => {
  const { call, signIn, env } = setup();
  const cookie = await signIn();
  const id = crypto.randomUUID();
  await call('/api/chats', 'POST', { id, product_id: 'pb225' }, cookie);
  env.GEMINI_API_KEY = 'test-only';
  const originalFetch = globalThis.fetch;
  globalThis.fetch = async () => { throw new Error('offline'); };
  try {
    const response = await call(`/api/chats/${id}/turns`, 'POST', { request_id: crypto.randomUUID(), message: '¿Está disponible hoy?' }, cookie);
    assert.equal(response.status, 201);
    const result = await response.json();
    assert.equal(result.turn.source, 'base');
    assert.match(result.turn.assistant_text, /confirmo disponibilidad y fecha/);
    assert.match(result.warning, /Gemini/);
  } finally { globalThis.fetch = originalFetch; }
});
