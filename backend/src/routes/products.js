import { Router } from 'express';
import { query, queryFirst, run } from '../database.js';

const router = Router();

const availability = new Set(['en_mano', 'proveedor_confirmado', 'por_confirmar']);

function str(value, max = 200) {
  return typeof value === 'string' ? value.trim().slice(0, max) : '';
}
function money(value) {
  const num = Number(value);
  return Number.isSafeInteger(num) && num >= 0 && num <= 1000000 ? num : null;
}
function validDate(value) {
  if (value === '') return true;
  if (!/^\d{4}-\d{2}-\d{2}$/.test(value)) return false;
  const [year, month, day] = value.split('-').map(Number);
  const date = new Date(Date.UTC(year, month - 1, day));
  return date.getUTCFullYear() === year && date.getUTCMonth() === month - 1 && date.getUTCDate() === day;
}

// GET /api/products
router.get('/', async (req, res) => {
  try {
    const raw = await query(
      'SELECT p.*, c.checked_at AS availability_checked_at FROM products p LEFT JOIN availability_checks c ON c.product_id=p.id ORDER BY p.name'
    );
    const products = raw.map(p => ({
      ...p,
      availability_checked_at: p.availability_checked_at ? new Date(p.availability_checked_at).toISOString() : ''
    }));
    res.json({ products });
  } catch (err) {
    console.error('Error fetching products:', err);
    res.status(500).json({ error: 'Error al obtener productos.' });
  }
});

// POST /api/products
router.post('/', async (req, res) => saveProduct(req, res, null));

// PATCH /api/products/:id
router.patch('/:id', async (req, res) => saveProduct(req, res, req.params.id));

async function saveProduct(req, res, id) {
  try {
    const data = req.body;
    const name = str(data.name, 100), facts = str(data.facts, 1200), readyDate = str(data.ready_date, 10);
    const cost = money(data.cost), price = money(data.price), minPrice = money(data.min_price);
    const units = money(data.available_units);

    if (!name || cost === null || price === null || minPrice === null || units === null || !availability.has(data.availability) || !validDate(readyDate)) {
      return res.status(400).json({ error: 'Revisa la ficha, los precios y la fecha.' });
    }
    if (minPrice > price) return res.status(400).json({ error: 'El precio mínimo no puede superar al precio publicado.' });
    if (data.availability === 'en_mano' && units < 1) return res.status(400).json({ error: 'Si está en mano, indica al menos una unidad.' });
    if (data.availability !== 'en_mano' && units !== 0) return res.status(400).json({ error: 'Las unidades en mano deben ser cero si no tienes el producto.' });

    const checked = data.availability_checked === true && data.availability !== 'por_confirmar';
    const key = id || crypto.randomUUID();

    let previous;
    if (id) {
      previous = await queryFirst('SELECT availability,available_units,ready_date FROM products WHERE id=?', [id]);
      if (!previous) return res.status(404).json({ error: 'Producto no encontrado.' });
      const result = await run('UPDATE products SET name=?, facts=?, cost=?, price=?, min_price=?, availability=?, available_units=?, ready_date=?, updated_at=CURRENT_TIMESTAMP WHERE id=?',
        [name, facts, cost, price, minPrice, data.availability, units, readyDate, id]);
      if (!result.changes) return res.status(404).json({ error: 'Producto no encontrado.' });
    } else {
      await run('INSERT INTO products (id,name,facts,cost,price,min_price,availability,available_units,ready_date) VALUES (?,?,?,?,?,?,?,?,?)',
        [key, name, facts, cost, price, minPrice, data.availability, units, readyDate]);
    }

    if (checked) {
      await run('INSERT INTO availability_checks(product_id,checked_at) VALUES (?,CURRENT_TIMESTAMP) ON CONFLICT (product_id) DO UPDATE SET checked_at=CURRENT_TIMESTAMP', [key]);
    } else if (!id || previous.availability !== data.availability || previous.available_units !== units || previous.ready_date !== readyDate) {
      await run('DELETE FROM availability_checks WHERE product_id=?', [key]);
    }

    res.json({ id: key });
  } catch (err) {
    console.error('Error saving product:', err);
    res.status(500).json({ error: 'Error al guardar el producto.' });
  }
}

export default router;
