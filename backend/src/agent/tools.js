import crypto from 'node:crypto';
import { query, queryFirst, run } from '../database.js';

/**
 * Declaraciones de herramientas para Gemini Function Calling (SDK @google/genai)
 * IMPORTANTE: El SDK requiere `parameters` (NO `parametersJsonSchema`) y tipos en MAYÚSCULAS.
 */
export const toolsDeclarations = [
  {
    name: 'crear_consulta',
    description: 'Registra una nueva consulta o pedido de cliente (lead) en el sistema. Extrae alias, producto, canal, fecha/hora pactada, modalidad de entrega, lugar y notas.',
    parameters: {
      type: 'OBJECT',
      properties: {
        alias: {
          type: 'STRING',
          description: 'Nombre o alias del cliente (ej: "Juan Carlos", "Fernanda R.").'
        },
        product_id: {
          type: 'STRING',
          description: 'ID exacto del producto en catálogo (ej: "pb225", "pb6010", "kp5501"). Mapear semánticamente el nombre solicitado al ID del catálogo.'
        },
        channel: {
          type: 'STRING',
          description: 'Canal de procedencia del cliente.',
          enum: ['Marketplace', 'WhatsApp', 'Otro']
        },
        delivery_mode: {
          type: 'STRING',
          description: 'Modalidad de entrega pactada.',
          enum: ['por_definir', 'persona', 'yango']
        },
        delivery_place: {
          type: 'STRING',
          description: 'Lugar pactado o dirección de referencia (ej: "Cine Center", "UAGRM módulos", "4to anillo radial 19").'
        },
        delivery_at: {
          type: 'STRING',
          description: 'Fecha y hora acordadas en formato ISO local boliviano: YYYY-MM-DDTHH:mm (ej: "2026-10-03T16:00"). Debe convertirse desde expresiones relativas.'
        },
        status: {
          type: 'STRING',
          description: 'Estado del pedido. Si ya se definió lugar y hora, usar "agendado" o "confirmado".',
          enum: ['consulta', 'interesado', 'confirmado', 'comprado', 'agendado', 'entregado', 'cancelado']
        },
        amount: {
          type: 'NUMBER',
          description: 'Precio acordado en Bolivianos (Bs). Si no se negoció, omitir para usar el precio de venta del producto.'
        },
        expenses: {
          type: 'NUMBER',
          description: 'Gastos de envío o empaque en Bs (ej: costo de Yango o pasajes). Por defecto 0.'
        },
        paid: {
          type: 'BOOLEAN',
          description: 'Indica si el pago ya fue recibido y verificado por QR/efectivo. Para Yango es requisito antes del despacho.'
        },
        notes: {
          type: 'STRING',
          description: 'Notas adicionales, referencias de ubicación, teléfono o peticiones específicas del cliente.'
        }
      },
      required: ['alias', 'product_id']
    }
  },
  {
    name: 'actualizar_consulta',
    description: 'Actualiza los datos o estado de una consulta/pedido existente (cambiar a confirmado, agendado, entregado, registrar pago verificado, cambiar fecha o lugar).',
    parameters: {
      type: 'OBJECT',
      properties: {
        lead_id: {
          type: 'STRING',
          description: 'ID de la consulta en la base de datos si se conoce.'
        },
        alias: {
          type: 'STRING',
          description: 'Nombre o alias del cliente para buscar la consulta si no se especificó lead_id.'
        },
        status: {
          type: 'STRING',
          description: 'Nuevo estado de la consulta.',
          enum: ['consulta', 'interesado', 'confirmado', 'comprado', 'agendado', 'entregado', 'cancelado']
        },
        paid: {
          type: 'BOOLEAN',
          description: 'Marcar el pago como verificado (true) o pendiente (false).'
        },
        delivery_mode: {
          type: 'STRING',
          description: 'Nueva modalidad de entrega.',
          enum: ['por_definir', 'persona', 'yango']
        },
        delivery_place: {
          type: 'STRING',
          description: 'Nuevo lugar o dirección pactada.'
        },
        delivery_at: {
          type: 'STRING',
          description: 'Nueva fecha y hora en formato YYYY-MM-DDTHH:mm.'
        },
        amount: {
          type: 'NUMBER',
          description: 'Nuevo monto total acordado en Bs.'
        },
        expenses: {
          type: 'NUMBER',
          description: 'Nuevos gastos en Bs.'
        },
        notes: {
          type: 'STRING',
          description: 'Notas actualizadas o añadidas.'
        }
      }
    }
  },
  {
    name: 'eliminar_consulta',
    description: 'Elimina un pedido o consulta por su ID o por el alias del cliente tras confirmación.',
    parameters: {
      type: 'OBJECT',
      properties: {
        lead_id: {
          type: 'STRING',
          description: 'ID de la consulta a eliminar.'
        },
        alias: {
          type: 'STRING',
          description: 'Alias del cliente para buscar y eliminar la consulta.'
        },
        confirm: {
          type: 'BOOLEAN',
          description: 'Confirmación obligatoria (true) para proceder con el borrado.'
        }
      },
      required: ['confirm']
    }
  },
  {
    name: 'crear_producto',
    description: 'Agrega un nuevo producto al catálogo de ventas con sus especificaciones y costos.',
    parameters: {
      type: 'OBJECT',
      properties: {
        id: {
          type: 'STRING',
          description: 'Identificador corto en minúsculas (slug, ej: "pb300", "auricular-f9"). Si no se envía se generará automáticamente.'
        },
        name: {
          type: 'STRING',
          description: 'Nombre comercial del producto (ej: "Power Bank Yesido PB300 20000mAh").'
        },
        cost: {
          type: 'NUMBER',
          description: 'Costo de adquisición en Bolivianos (Bs).'
        },
        price: {
          type: 'NUMBER',
          description: 'Precio de venta al público anunciado en Bolivianos (Bs).'
        },
        min_price: {
          type: 'NUMBER',
          description: 'Precio mínimo interno en Bolivianos (Bs) por debajo del cual nunca se vende ni se hace rebaja.'
        },
        availability: {
          type: 'STRING',
          description: 'Disponibilidad física del producto.',
          enum: ['en_mano', 'proveedor_confirmado', 'por_confirmar']
        },
        available_units: {
          type: 'NUMBER',
          description: 'Cantidad de unidades en mano (si availability es "en_mano" debe ser >= 1, de lo contrario 0).'
        },
        ready_date: {
          type: 'STRING',
          description: 'Fecha estimada de disponibilidad en formato YYYY-MM-DD.'
        },
        facts: {
          type: 'STRING',
          description: 'Características técnicas comprobadas y advertencias de no prometer datos no verificados.'
        },
        is_active: {
          type: 'BOOLEAN',
          description: 'Si el producto está activo y visible para la venta (por defecto true).'
        }
      },
      required: ['name', 'cost', 'price', 'min_price']
    }
  },
  {
    name: 'actualizar_producto',
    description: 'Modifica los precios, stock disponible, estado de disponibilidad o visibilidad (activo/oculto) de un producto en catálogo.',
    parameters: {
      type: 'OBJECT',
      properties: {
        product_id: {
          type: 'STRING',
          description: 'ID o slug del producto a actualizar (ej: "pb225").'
        },
        name: {
          type: 'STRING',
          description: 'Nuevo nombre comercial del producto.'
        },
        cost: {
          type: 'NUMBER',
          description: 'Nuevo costo en Bs.'
        },
        price: {
          type: 'NUMBER',
          description: 'Nuevo precio de venta en Bs.'
        },
        min_price: {
          type: 'NUMBER',
          description: 'Nuevo precio mínimo interno en Bs.'
        },
        availability: {
          type: 'STRING',
          description: 'Nueva disponibilidad.',
          enum: ['en_mano', 'proveedor_confirmado', 'por_confirmar']
        },
        available_units: {
          type: 'NUMBER',
          description: 'Nuevo número de unidades en stock físico.'
        },
        ready_date: {
          type: 'STRING',
          description: 'Nueva fecha disponible YYYY-MM-DD.'
        },
        facts: {
          type: 'STRING',
          description: 'Nuevos datos técnicos o notas.'
        },
        is_active: {
          type: 'BOOLEAN',
          description: 'Marcar como activo (true) o inactivo/oculto (false).'
        }
      },
      required: ['product_id']
    }
  },
  {
    name: 'consultar_metricas',
    description: 'Calcula y devuelve métricas del negocio: margen cobrado hoy, entregas agendadas para hoy/mañana, resumen general o stock crítico en Santa Cruz.',
    parameters: {
      type: 'OBJECT',
      properties: {
        metric_type: {
          type: 'STRING',
          description: 'Tipo de consulta o métrica solicitada.',
          enum: ['ventas_hoy', 'margen_hoy', 'entregas_agendadas', 'resumen_general', 'stock_critico']
        },
        date: {
          type: 'STRING',
          description: 'Fecha específica a consultar en formato YYYY-MM-DD (por defecto hoy en Bolivia).'
        }
      },
      required: ['metric_type']
    }
  },
  {
    name: 'redactar_respuesta',
    description: 'Redacta una respuesta comercial para copiar y enviar al cliente en WhatsApp o Marketplace, aplicando reglas de Santa Cruz (Yango prepago, entrega presencial y precios mínimos).',
    parameters: {
      type: 'OBJECT',
      properties: {
        product_id: {
          type: 'STRING',
          description: 'ID del producto consultado por el cliente.'
        },
        customer_message: {
          type: 'STRING',
          description: 'Texto o mensaje del cliente que se quiere responder.'
        },
        goal: {
          type: 'STRING',
          description: 'Objetivo de la respuesta (ej: "responder precio", "ofrecer rebaja", "coordinar entrega yango", "aclarar características").'
        }
      },
      required: ['product_id', 'customer_message']
    }
  }
];

// ─────────────────────────────────────────────────────────────
// Implementaciones de ejecución de las herramientas en PostgreSQL
// ─────────────────────────────────────────────────────────────

export async function handleCrearConsulta(args) {
  const alias = typeof args.alias === 'string' ? args.alias.trim() : '';
  const productId = typeof args.product_id === 'string' ? args.product_id.trim().toLowerCase() : '';

  if (!alias || !productId) {
    return { error: 'Faltan datos obligatorios: alias del cliente o producto.' };
  }

  // Buscar producto por ID exacto o coincidencia parcial de nombre
  let product = await queryFirst('SELECT * FROM products WHERE LOWER(id) = ?', [productId]);
  if (!product) {
    product = await queryFirst('SELECT * FROM products WHERE LOWER(name) LIKE ? LIMIT 1', [`%${productId}%`]);
  }

  if (!product) {
    return { error: `Producto "${productId}" no encontrado en el catálogo. Revisa los productos disponibles.` };
  }

  const channel = ['Marketplace', 'WhatsApp', 'Otro'].includes(args.channel) ? args.channel : 'Marketplace';
  const deliveryMode = ['por_definir', 'persona', 'yango'].includes(args.delivery_mode) ? args.delivery_mode : 'por_definir';
  const deliveryPlace = typeof args.delivery_place === 'string' ? args.delivery_place.trim() : '';
  const deliveryAt = typeof args.delivery_at === 'string' ? args.delivery_at.trim() : '';
  
  let status = args.status;
  if (!status || !['consulta', 'interesado', 'confirmado', 'comprado', 'agendado', 'entregado', 'cancelado'].includes(status)) {
    status = (deliveryPlace && deliveryAt && deliveryMode !== 'por_definir') ? 'agendado' : 'consulta';
  }

  const amount = Number.isSafeInteger(Number(args.amount)) && Number(args.amount) >= 0 ? Number(args.amount) : product.price;
  const actualCost = product.cost;
  const expenses = Number.isSafeInteger(Number(args.expenses)) && Number(args.expenses) >= 0 ? Number(args.expenses) : 0;
  const paid = args.paid === true ? 1 : 0;
  const notes = typeof args.notes === 'string' ? args.notes.trim() : '';

  const id = crypto.randomUUID();
  const requestId = crypto.randomUUID();

  await run(
    `INSERT INTO leads (
      id, request_id, channel, product_id, alias, status, 
      amount, actual_cost, expenses, delivery_mode, delivery_place, 
      delivery_at, paid, notes, created_at, updated_at
    ) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)`,
    [id, requestId, channel, product.id, alias, status, amount, actualCost, expenses, deliveryMode, deliveryPlace, deliveryAt, paid, notes]
  );

  return {
    success: true,
    action: 'crear_consulta',
    lead_id: id,
    alias,
    product_id: product.id,
    product_name: product.name,
    amount,
    status,
    delivery_mode: deliveryMode,
    delivery_place: deliveryPlace,
    delivery_at: deliveryAt,
    paid: paid === 1,
    notes
  };
}

export async function handleActualizarConsulta(args) {
  let lead = null;
  if (args.lead_id) {
    lead = await queryFirst('SELECT * FROM leads WHERE id = ?', [args.lead_id]);
  } else if (args.alias) {
    lead = await queryFirst(
      'SELECT * FROM leads WHERE LOWER(alias) LIKE ? ORDER BY updated_at DESC LIMIT 1',
      [`%${args.alias.trim().toLowerCase()}%`]
    );
  }

  if (!lead) {
    return { error: 'No se encontró la consulta especificada para actualizar.' };
  }

  const status = args.status && ['consulta', 'interesado', 'confirmado', 'comprado', 'agendado', 'entregado', 'cancelado'].includes(args.status)
    ? args.status
    : lead.status;

  const paid = args.paid !== undefined ? (args.paid ? 1 : 0) : lead.paid;

  if (status === 'entregado' && paid !== 1) {
    return { error: 'Regla de negocio: No se puede marcar como "entregado" sin verificar previamente el pago.' };
  }

  const deliveryMode = args.delivery_mode && ['por_definir', 'persona', 'yango'].includes(args.delivery_mode)
    ? args.delivery_mode
    : lead.delivery_mode;

  const deliveryPlace = args.delivery_place !== undefined ? String(args.delivery_place).trim() : lead.delivery_place;
  const deliveryAt = args.delivery_at !== undefined ? String(args.delivery_at).trim() : lead.delivery_at;
  const amount = Number.isSafeInteger(Number(args.amount)) && Number(args.amount) >= 0 ? Number(args.amount) : lead.amount;
  const expenses = Number.isSafeInteger(Number(args.expenses)) && Number(args.expenses) >= 0 ? Number(args.expenses) : lead.expenses;
  
  let notes = lead.notes;
  if (args.notes !== undefined) {
    const newNote = String(args.notes).trim();
    notes = notes ? `${notes} | ${newNote}` : newNote;
  }

  await run(
    `UPDATE leads SET 
      status = ?, paid = ?, delivery_mode = ?, delivery_place = ?, 
      delivery_at = ?, amount = ?, expenses = ?, notes = ?, updated_at = CURRENT_TIMESTAMP
    WHERE id = ?`,
    [status, paid, deliveryMode, deliveryPlace, deliveryAt, amount, expenses, notes, lead.id]
  );

  return {
    success: true,
    action: 'actualizar_consulta',
    lead_id: lead.id,
    alias: lead.alias,
    status,
    paid: paid === 1,
    delivery_mode: deliveryMode,
    delivery_place: deliveryPlace,
    delivery_at: deliveryAt,
    amount,
    notes
  };
}

export async function handleEliminarConsulta(args) {
  if (!args.confirm) {
    return { error: 'Se requiere confirmación explícita para eliminar la consulta.' };
  }

  let lead = null;
  if (args.lead_id) {
    lead = await queryFirst('SELECT id, alias FROM leads WHERE id = ?', [args.lead_id]);
  } else if (args.alias) {
    lead = await queryFirst('SELECT id, alias FROM leads WHERE LOWER(alias) LIKE ? ORDER BY updated_at DESC LIMIT 1', [
      `%${args.alias.trim().toLowerCase()}%`
    ]);
  }

  if (!lead) {
    return { error: 'No se encontró la consulta que se desea eliminar.' };
  }

  await run('DELETE FROM leads WHERE id = ?', [lead.id]);

  return {
    success: true,
    action: 'eliminar_consulta',
    deleted_lead_id: lead.id,
    alias: lead.alias
  };
}

export async function handleCrearProducto(args) {
  const name = typeof args.name === 'string' ? args.name.trim() : '';
  const cost = Number(args.cost);
  const price = Number(args.price);
  const minPrice = Number(args.min_price);

  if (!name || isNaN(cost) || isNaN(price) || isNaN(minPrice)) {
    return { error: 'Nombre, costo, precio de venta y precio mínimo son requeridos.' };
  }

  if (minPrice > price) {
    return { error: 'El precio mínimo interno no puede ser mayor que el precio de venta.' };
  }

  let id = typeof args.id === 'string' && args.id.trim() ? args.id.trim().toLowerCase() : '';
  if (!id) {
    id = name.toLowerCase().replace(/[^a-z0-9]+/g, '-').slice(0, 30).replace(/^-+|-+$/g, '') || `prod-${Date.now().toString().slice(-4)}`;
  }

  // Verificar colisión
  const existing = await queryFirst('SELECT id FROM products WHERE id = ?', [id]);
  if (existing) {
    id = `${id}-${Math.floor(Math.random() * 1000)}`;
  }

  const availability = ['en_mano', 'proveedor_confirmado', 'por_confirmar'].includes(args.availability)
    ? args.availability
    : 'por_confirmar';

  let units = Number(args.available_units) || 0;
  if (availability === 'en_mano' && units < 1) units = 1;
  if (availability !== 'en_mano') units = 0;

  const readyDate = typeof args.ready_date === 'string' ? args.ready_date.trim() : '';
  const facts = typeof args.facts === 'string' ? args.facts.trim() : '';
  const isActive = args.is_active !== undefined ? Boolean(args.is_active) : true;

  await run(
    `INSERT INTO products (id, name, facts, cost, price, min_price, availability, available_units, ready_date, is_active, updated_at)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP)`,
    [id, name, facts, Math.round(cost), Math.round(price), Math.round(minPrice), availability, units, readyDate, isActive]
  );

  return {
    success: true,
    action: 'crear_producto',
    product_id: id,
    name,
    price,
    min_price: minPrice,
    cost,
    availability,
    available_units: units,
    is_active: isActive
  };
}

export async function handleActualizarProducto(args) {
  const productId = typeof args.product_id === 'string' ? args.product_id.trim().toLowerCase() : '';
  if (!productId) {
    return { error: 'Debes especificar el ID del producto a modificar.' };
  }

  let product = await queryFirst('SELECT * FROM products WHERE LOWER(id) = ?', [productId]);
  if (!product) {
    product = await queryFirst('SELECT * FROM products WHERE LOWER(name) LIKE ? LIMIT 1', [`%${productId}%`]);
  }

  if (!product) {
    return { error: `Producto "${productId}" no encontrado en el catálogo.` };
  }

  const name = args.name !== undefined ? String(args.name).trim() : product.name;
  const cost = args.cost !== undefined ? Math.round(Number(args.cost)) : product.cost;
  const price = args.price !== undefined ? Math.round(Number(args.price)) : product.price;
  const minPrice = args.min_price !== undefined ? Math.round(Number(args.min_price)) : product.min_price;

  if (minPrice > price) {
    return { error: 'El precio mínimo interno no puede ser mayor que el precio de venta.' };
  }

  const availability = args.availability && ['en_mano', 'proveedor_confirmado', 'por_confirmar'].includes(args.availability)
    ? args.availability
    : product.availability;

  let units = args.available_units !== undefined ? Number(args.available_units) : product.available_units;
  if (availability === 'en_mano' && units < 1) units = 1;
  if (availability !== 'en_mano') units = 0;

  const readyDate = args.ready_date !== undefined ? String(args.ready_date).trim() : product.ready_date;
  const facts = args.facts !== undefined ? String(args.facts).trim() : product.facts;
  const isActive = args.is_active !== undefined ? Boolean(args.is_active) : product.is_active;

  await run(
    `UPDATE products SET 
      name = ?, cost = ?, price = ?, min_price = ?, availability = ?, 
      available_units = ?, ready_date = ?, facts = ?, is_active = ?, updated_at = CURRENT_TIMESTAMP
    WHERE id = ?`,
    [name, cost, price, minPrice, availability, units, readyDate, facts, isActive, product.id]
  );

  return {
    success: true,
    action: 'actualizar_producto',
    product_id: product.id,
    name,
    price,
    min_price: minPrice,
    availability,
    available_units: units,
    is_active: isActive
  };
}

export async function handleConsultarMetricas(args) {
  const metricType = args.metric_type || 'resumen_general';
  
  // Fecha en Santa Cruz (Bolivia)
  const now = new Date();
  const todayBolivia = new Intl.DateTimeFormat('en-CA', {
    timeZone: 'America/La_Paz',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit'
  }).format(now);

  const queryDate = args.date || todayBolivia;

  switch (metricType) {
    case 'ventas_hoy':
    case 'margen_hoy': {
      // Ventas entregadas y cobradas en la fecha indicada
      const deliveredLeads = await query(
        `SELECT l.*, p.name AS product_name 
         FROM leads l 
         JOIN products p ON p.id = l.product_id 
         WHERE l.status = 'entregado' AND l.paid = 1 AND l.delivery_at LIKE ?`,
        [`${queryDate}%`]
      );

      const totalVendido = deliveredLeads.reduce((acc, lead) => acc + (lead.amount || 0), 0);
      const totalCosto = deliveredLeads.reduce((acc, lead) => acc + (lead.actual_cost || 0), 0);
      const totalGastos = deliveredLeads.reduce((acc, lead) => acc + (lead.expenses || 0), 0);
      const margenNeto = totalVendido - totalCosto - totalGastos;

      return {
        metric: metricType,
        date: queryDate,
        entregas_completadas: deliveredLeads.length,
        total_ingresos_bs: totalVendido,
        total_costos_bs: totalCosto,
        total_gastos_bs: totalGastos,
        margen_cobrado_bs: margenNeto,
        detalle: deliveredLeads.map(l => ({
          alias: l.alias,
          producto: l.product_name,
          monto: l.amount,
          ganancia: l.amount - l.actual_cost - l.expenses
        }))
      };
    }

    case 'entregas_agendadas': {
      const scheduledLeads = await query(
        `SELECT l.*, p.name AS product_name 
         FROM leads l 
         JOIN products p ON p.id = l.product_id 
         WHERE (l.status IN ('agendado', 'confirmado') OR (l.delivery_at LIKE ? AND l.status != 'cancelado'))
         ORDER BY l.delivery_at ASC`,
        [`${queryDate}%`]
      );

      return {
        metric: 'entregas_agendadas',
        date: queryDate,
        total_agendadas: scheduledLeads.length,
        entregas: scheduledLeads.map(l => ({
          alias: l.alias,
          producto: l.product_name,
          modalidad: l.delivery_mode,
          lugar: l.delivery_place,
          hora: l.delivery_at,
          pago_verificado: l.paid === 1,
          monto_bs: l.amount,
          estado: l.status
        }))
      };
    }

    case 'stock_critico': {
      const lowStockProducts = await query(
        `SELECT id, name, availability, available_units, price, min_price 
         FROM products 
         WHERE is_active = TRUE AND (
           (availability = 'en_mano' AND available_units <= 2) OR 
           availability = 'por_confirmar'
         )
         ORDER BY available_units ASC, name ASC`
      );

      return {
        metric: 'stock_critico',
        cantidad_productos_atencion: lowStockProducts.length,
        productos: lowStockProducts
      };
    }

    case 'resumen_general':
    default: {
      const allLeads = await query(
        'SELECT status, created_at, delivery_at, paid, amount, actual_cost, expenses FROM leads'
      );

      const statusCounts = {};
      let agendadasHoy = 0;
      let margenCobrado = 0;
      let ventaTotal = 0;

      for (const l of allLeads) {
        const createdStr = l.created_at ? new Date(l.created_at).toISOString().slice(0, 10) : '';
        const deliveryStr = l.delivery_at || '';
        const isToday = createdStr === queryDate || deliveryStr.startsWith(queryDate);

        if (isToday) {
          statusCounts[l.status] = (statusCounts[l.status] || 0) + 1;
        }

        if (deliveryStr.startsWith(queryDate) && ['agendado', 'confirmado'].includes(l.status)) {
          agendadasHoy++;
        }

        if (l.status === 'entregado' && Number(l.paid) === 1 && (deliveryStr.startsWith(queryDate) || createdStr === queryDate)) {
          margenCobrado += ((Number(l.amount) || 0) - (Number(l.actual_cost) || 0) - (Number(l.expenses) || 0));
          ventaTotal += (Number(l.amount) || 0);
        }
      }

      return {
        metric: 'resumen_general',
        fecha_bolivia: queryDate,
        entregas_pendientes_hoy: agendadasHoy,
        margen_cobrado_hoy_bs: margenCobrado,
        venta_total_hoy_bs: ventaTotal,
        leads_por_estado: Object.entries(statusCounts).map(([status, cant]) => ({ status, cant }))
      };
    }
  }
}

export async function handleRedactarRespuesta(args) {
  const productId = typeof args.product_id === 'string' ? args.product_id.trim().toLowerCase() : '';
  const customerMessage = typeof args.customer_message === 'string' ? args.customer_message.trim() : '';
  const goal = args.goal || 'responder consulta';

  if (!productId || !customerMessage) {
    return { error: 'Se requiere el producto y el mensaje del cliente para redactar.' };
  }

  let product = await queryFirst(
    `SELECT p.*, c.checked_at AS availability_checked_at 
     FROM products p 
     LEFT JOIN availability_checks c ON c.product_id = p.id 
     WHERE LOWER(p.id) = ?`,
    [productId]
  );
  if (!product) {
    product = await queryFirst('SELECT * FROM products WHERE LOWER(name) LIKE ? LIMIT 1', [`%${productId}%`]);
  }

  if (!product) {
    return { error: `Producto "${productId}" no encontrado.` };
  }

  return {
    success: true,
    action: 'redactar_respuesta',
    product_id: product.id,
    product_name: product.name,
    product_facts: product.facts,
    price: product.price,
    min_price: product.min_price,
    availability: product.availability,
    available_units: product.available_units,
    customer_message: customerMessage,
    goal,
    policy_guideline: `Responde en español boliviano de forma breve, cálida y directa.
- Precio público: Bs ${product.price}.
- Si el cliente pide rebaja, no bajes nunca de Bs ${product.min_price}. Jamás reveles este mínimo.
- Entrega en persona: Coordinar en UAGRM zona módulos o Cine Center (pago al recibir).
- Envío por Yango: Indicar que el producto se paga por adelantado mediante QR y el envío se cotiza según su ubicación.
- No prometer envío gratis. Si faltan datos, haz una sola pregunta.`
  };
}

/**
 * Despachador de herramientas
 */
export async function executeTool(name, args) {
  try {
    switch (name) {
      case 'crear_consulta':
        return await handleCrearConsulta(args);
      case 'actualizar_consulta':
        return await handleActualizarConsulta(args);
      case 'eliminar_consulta':
        return await handleEliminarConsulta(args);
      case 'crear_producto':
        return await handleCrearProducto(args);
      case 'actualizar_producto':
        return await handleActualizarProducto(args);
      case 'consultar_metricas':
        return await handleConsultarMetricas(args);
      case 'redactar_respuesta':
        return await handleRedactarRespuesta(args);
      default:
        return { error: `Herramienta desconocida: "${name}".` };
    }
  } catch (err) {
    console.error(`[Tool Execution Error: ${name}]`, err);
    return { error: `Error ejecutando la herramienta ${name}: ${err.message}` };
  }
}
