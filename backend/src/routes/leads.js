import { Router } from 'express';
import { query, queryFirst, run } from '../database.js';

const router = Router();

const statuses = new Set(['consulta', 'interesado', 'confirmado', 'comprado', 'agendado', 'entregado', 'cancelado']);
const modes = new Set(['por_definir', 'persona', 'yango']);
const channels = new Set(['Marketplace', 'WhatsApp', 'Otro']);

function str(value, max = 200) {
  return typeof value === 'string' ? value.trim().slice(0, max) : '';
}
function money(value) {
  const num = Number(value);
  return Number.isSafeInteger(num) && num >= 0 && num <= 1000000 ? num : null;
}
function validDateTime(value) {
  if (value === '') return true;
  if (!/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}$/.test(value)) return false;
  const datePart = value.slice(0, 10);
  if (!/^\d{4}-\d{2}-\d{2}$/.test(datePart)) return false;
  const [year, month, day] = datePart.split('-').map(Number);
  const date = new Date(Date.UTC(year, month - 1, day));
  if (date.getUTCFullYear() !== year || date.getUTCMonth() !== month - 1 || date.getUTCDate() !== day) return false;
  const hours = Number(value.slice(11, 13)), minutes = Number(value.slice(14, 16));
  return hours < 24 && minutes < 60;
}

function leadDetails(data, defaultAmount, defaultCost) {
  const alias = str(data.alias, 100), place = str(data.delivery_place, 200), at = str(data.delivery_at, 16), notes = str(data.notes, 1000);
  const amount = money(data.amount ?? defaultAmount), cost = money(data.actual_cost ?? defaultCost), expenses = money(data.expenses ?? 0);
  const status = data.status ?? 'consulta', mode = data.delivery_mode ?? 'por_definir';
  if (!alias || !statuses.has(status) || !modes.has(mode) || amount === null || cost === null || expenses === null || !validDateTime(at)) {
    return { error: 'Revisa los datos del pedido.' };
  }
  if (['agendado', 'entregado'].includes(status) && (mode === 'por_definir' || !at || !place)) {
    return { error: 'Para agendar o entregar, indica modalidad, lugar y fecha.' };
  }
  const paid = data.paid === true ? 1 : 0;
  if (status === 'entregado' && !paid) return { error: 'Verifica el pago antes de marcar entregado.' };
  return { values: [alias, status, amount, cost, expenses, mode, place, at, paid, notes] };
}

// GET /api/leads
router.get('/', async (req, res) => {
  try {
    const leads = await query(
      "SELECT l.*, p.name AS product_name FROM leads l JOIN products p ON p.id=l.product_id ORDER BY CASE WHEN l.status='entregado' THEN 1 ELSE 0 END, l.updated_at DESC LIMIT 500"
    );
    res.json({ leads });
  } catch (err) {
    console.error('Error fetching leads:', err);
    res.status(500).json({ error: 'Error al obtener consultas.' });
  }
});

// POST /api/leads
router.post('/', async (req, res) => {
  try {
    const data = req.body;
    const alias = str(data.alias, 100), productId = str(data.product_id, 100);
    const product = await queryFirst('SELECT * FROM products WHERE id=?', [productId]);

    if (!alias || !product || !channels.has(data.channel)) {
      return res.status(400).json({ error: 'Escribe un alias, canal y producto válidos.' });
    }

    const requestId = str(data.request_id, 80);
    if (!/^[a-f0-9-]{36}$/.test(requestId)) {
      return res.status(400).json({ error: 'Falta el identificador de la consulta.' });
    }

    const details = leadDetails(data, product.price, product.cost);
    if (details.error) return res.status(400).json({ error: details.error });

    const id = crypto.randomUUID();
    try {
      await run('INSERT INTO leads (id,request_id,channel,product_id,alias,status,amount,actual_cost,expenses,delivery_mode,delivery_place,delivery_at,paid,notes) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?)',
        [id, requestId, data.channel, productId, ...details.values]);
      return res.status(201).json({ id });
    } catch (e) {
      if (e.message?.includes('duplicate key') || e.message?.includes('UNIQUE')) {
        const existing = await queryFirst('SELECT id FROM leads WHERE request_id=?', [requestId]);
        if (existing) return res.json({ id: existing.id, duplicate: true });
      }
      throw e;
    }
  } catch (err) {
    console.error('Error creating lead:', err);
    res.status(500).json({ error: 'Error al registrar consulta.' });
  }
});

// PATCH /api/leads/:id
router.patch('/:id', async (req, res) => {
  try {
    const data = req.body;
    const details = leadDetails(data);
    if (details.error) return res.status(400).json({ error: details.error });

    const result = await run('UPDATE leads SET alias=?, status=?, amount=?, actual_cost=?, expenses=?, delivery_mode=?, delivery_place=?, delivery_at=?, paid=?, notes=?, updated_at=CURRENT_TIMESTAMP WHERE id=?',
      [...details.values, req.params.id]);
    if (!result.changes) return res.status(404).json({ error: 'Consulta no encontrada.' });
    res.json({ id: req.params.id });
  } catch (err) {
    console.error('Error updating lead:', err);
    res.status(500).json({ error: 'Error al actualizar consulta.' });
  }
});

export default router;
