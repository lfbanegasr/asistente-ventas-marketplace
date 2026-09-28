import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { DatabaseSync } from 'node:sqlite';
import worker from '../src/worker.js';

function setup(seed = true) {
  const db = new DatabaseSync(':memory:');
  if (seed) db.exec(readFileSync(new URL('../migrations/0001_init.sql', import.meta.url), 'utf8'));
  const DB = { prepare(sql) { const statement = db.prepare(sql); return { bind(...args) { return { first: async () => statement.get(...args) || null, all: async () => ({ results: statement.all(...args) }), run: async () => ({ meta: { changes: statement.run(...args).changes } }) }; }, first: async () => statement.get() || null, all: async () => ({ results: statement.all() }) }; }, exec: async sql => { db.exec(sql); return { count: 1 }; } };
  const env = { DB, OWNER_EMAIL: 'owner@example.com' };
  const ctx = { access: { getIdentity: async () => ({ email: 'owner@example.com' }) } };
  const call = (path, method = 'GET', data, context = ctx) => worker.fetch(new Request(`https://local.test${path}`, { method, headers: data ? { 'Content-Type': 'application/json', Origin: 'https://local.test' } : {}, body: data ? JSON.stringify(data) : undefined }), env, context);
  return { db, call };
}

test('private data requires a matching Access identity', async () => {
  const { call } = setup();
  assert.equal((await call('/api/state', 'GET', undefined, {})).status, 403);
  assert.equal((await call('/api/state', 'GET', undefined, { access: { getIdentity: async () => ({ email: 'someone@example.com' }) } })).status, 403);
  const response = await call('/api/state');
  assert.equal(response.status, 200);
  assert.equal((await response.json()).products.length, 3);
});

test('the same save request creates only one consultation', async () => {
  const { db, call } = setup();
  const data = { request_id: '0b379d57-2843-43bf-bb19-1fd80bbf69c0', alias: 'Cliente A', channel: 'Marketplace', product_id: 'kp5501' };
  const first = await call('/api/leads', 'POST', data), second = await call('/api/leads', 'POST', data);
  assert.equal(first.status, 201); assert.equal(second.status, 200);
  assert.equal((await first.json()).id, (await second.json()).id);
  assert.equal(db.prepare('SELECT COUNT(*) AS count FROM leads').get().count, 1);
});

test('AI draft does not run without a server-side key', async () => {
  const { call } = setup();
  const response = await call('/api/ai', 'POST', { product_id: 'pb6010', customer_message: '¿Está disponible?' });
  assert.equal(response.status, 503);
});

test('a fresh Cloudflare database initializes when its owner first opens the app', async () => {
  const { db, call } = setup(false);
  const response = await call('/api/state');
  assert.equal(response.status, 200);
  assert.equal((await response.json()).products.length, 3);
  assert.equal(db.prepare('SELECT COUNT(*) AS count FROM products').get().count, 3);
});
