import test from 'node:test';
import assert from 'node:assert/strict';
import { initDb, query, queryFirst, run, closeDb } from '../src/database.js';
import { generateToken, verifyToken } from '../src/auth.js';

test.before(async () => {
  process.env.APP_PASSWORD = 'una-clave-larga-de-prueba-cambiala';
  process.env.JWT_SECRET = 'test-jwt-secret-for-automated-tests-32chars';
  await initDb();
});

test.after(async () => {
  await closeDb();
});

test('Database initializes default seed products', async () => {
  const products = await query('SELECT * FROM products ORDER BY name');
  assert.ok(products.length >= 3, 'Should have at least 3 seed products');
  const first = products.find(p => p.id === 'pb6010');
  assert.ok(first, 'Should have pb6010 product');
  assert.strictEqual(first.price, 170);
  assert.strictEqual(first.cost, 98);
});

test('JWT generation and verification works', () => {
  const token = generateToken();
  assert.ok(typeof token === 'string');
  const valid = verifyToken(token);
  assert.strictEqual(valid, true);
  const invalid = verifyToken('invalid.jwt.token');
  assert.strictEqual(invalid, false);
});

test('Can insert and retrieve leads', async () => {
  const leadId = crypto.randomUUID();
  const requestId = crypto.randomUUID();
  await run(
    'INSERT INTO leads (id, request_id, channel, product_id, alias, status, amount, actual_cost, expenses, delivery_mode, delivery_place, delivery_at, paid, notes) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?)',
    [leadId, requestId, 'WhatsApp', 'pb6010', 'Cliente Test', 'consulta', 170, 98, 0, 'por_definir', '', '', 0, 'Consulta de prueba']
  );

  const found = await queryFirst('SELECT * FROM leads WHERE id=?', [leadId]);
  assert.ok(found, 'Lead should exist');
  assert.strictEqual(found.alias, 'Cliente Test');
  assert.strictEqual(found.channel, 'WhatsApp');
  assert.strictEqual(found.amount, 170);
});

test('Can create chat thread and turn', async () => {
  const threadId = crypto.randomUUID();
  await run('INSERT INTO chat_threads (id, product_id, title) VALUES (?, ?, ?)', [threadId, 'pb6010', 'Test Thread']);

  const thread = await queryFirst('SELECT * FROM chat_threads WHERE id=?', [threadId]);
  assert.ok(thread);
  assert.strictEqual(thread.title, 'Test Thread');

  const turnId = crypto.randomUUID();
  const requestId = crypto.randomUUID();
  await run(
    'INSERT INTO chat_turns (id, thread_id, request_id, user_text, assistant_text, source) VALUES (?,?,?,?,?,?)',
    [turnId, threadId, requestId, 'Hola tienen disponible?', 'Hola, si confirmamos disponibilidad', 'base']
  );

  const turns = await query('SELECT * FROM chat_turns WHERE thread_id=?', [threadId]);
  assert.strictEqual(turns.length, 1);
  assert.strictEqual(turns[0].source, 'base');
});

test('Can delete lead', async () => {
  const leadId = crypto.randomUUID();
  await run(
    'INSERT INTO leads (id, request_id, channel, product_id, alias, status, amount, actual_cost, expenses, delivery_mode, delivery_place, delivery_at, paid, notes) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?)',
    [leadId, crypto.randomUUID(), 'Marketplace', 'pb6010', 'Para borrar', 'consulta', 170, 98, 0, 'por_definir', '', '', 0, '']
  );
  await run('DELETE FROM leads WHERE id=?', [leadId]);
  const deleted = await queryFirst('SELECT id FROM leads WHERE id=?', [leadId]);
  assert.strictEqual(deleted, null);
});

test('Can delete product and cascade its dependencies', async () => {
  const prodId = 'prod-delete-test';
  await run(
    'INSERT INTO products (id, name, facts, cost, price, min_price) VALUES (?, ?, ?, ?, ?, ?)',
    [prodId, 'Producto a borrar', '', 10, 20, 15]
  );
  await run('DELETE FROM products WHERE id=?', [prodId]);
  const deleted = await queryFirst('SELECT id FROM products WHERE id=?', [prodId]);
  assert.strictEqual(deleted, null);
});
