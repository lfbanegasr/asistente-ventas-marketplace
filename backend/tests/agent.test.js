import test from 'node:test';
import assert from 'node:assert/strict';
import { initDb, closeDb, queryFirst } from '../src/database.js';
import {
  toolsDeclarations,
  executeTool,
  handleCrearConsulta,
  handleActualizarConsulta,
  handleEliminarConsulta,
  handleCrearProducto,
  handleActualizarProducto,
  handleConsultarMetricas,
  handleRedactarRespuesta
} from '../src/agent/tools.js';
import { getBoliviaContext, buildSystemInstruction } from '../src/agent/agentOrchestrator.js';

test.before(async () => {
  process.env.APP_PASSWORD = 'test-password-for-agent-testing';
  process.env.JWT_SECRET = 'test-jwt-secret-for-agent-test-32chars';
  await initDb();
});

test.after(async () => {
  await closeDb();
});

test('Agent Tools: Todas las 7 herramientas están declaradas con JSON Schema válido', () => {
  assert.strictEqual(toolsDeclarations.length, 7);
  const names = toolsDeclarations.map(t => t.name);
  assert.ok(names.includes('crear_consulta'));
  assert.ok(names.includes('actualizar_consulta'));
  assert.ok(names.includes('eliminar_consulta'));
  assert.ok(names.includes('crear_producto'));
  assert.ok(names.includes('actualizar_producto'));
  assert.ok(names.includes('consultar_metricas'));
  assert.ok(names.includes('redactar_respuesta'));

  for (const tool of toolsDeclarations) {
    assert.ok(tool.description, `Tool ${tool.name} must have a description`);
    assert.strictEqual(tool.parametersJsonSchema.type, 'object');
    assert.ok(tool.parametersJsonSchema.properties);
  }
});

test('Agent Tool: crear_consulta registra lead en PostgreSQL con modalidad y fecha local', async () => {
  const result = await handleCrearConsulta({
    alias: 'Juan Carlos',
    product_id: 'pb225',
    delivery_mode: 'yango',
    delivery_place: '4to anillo radial 19',
    delivery_at: '2026-10-03T16:00',
    channel: 'Marketplace',
    notes: 'Pide que se le avise al despachar'
  });

  assert.strictEqual(result.success, true);
  assert.ok(result.lead_id);
  assert.strictEqual(result.alias, 'Juan Carlos');
  assert.strictEqual(result.delivery_mode, 'yango');
  assert.strictEqual(result.delivery_place, '4to anillo radial 19');
  assert.strictEqual(result.delivery_at, '2026-10-03T16:00');
  assert.strictEqual(result.status, 'agendado');

  const inDb = await queryFirst('SELECT * FROM leads WHERE id = ?', [result.lead_id]);
  assert.ok(inDb);
  assert.strictEqual(inDb.alias, 'Juan Carlos');
  assert.strictEqual(inDb.product_id, 'pb225');
  assert.strictEqual(inDb.delivery_mode, 'yango');
});

test('Agent Tool: actualizar_consulta modifica estado y valida pago para entrega', async () => {
  // 1. Crear consulta inicial
  const created = await handleCrearConsulta({
    alias: 'Marcos Vaca',
    product_id: 'pb6010',
    delivery_mode: 'persona',
    delivery_place: 'UAGRM módulos'
  });

  // 2. Intentar marcar 'entregado' sin pago debe arrojar error de regla de negocio
  const failUpdate = await handleActualizarConsulta({
    lead_id: created.lead_id,
    status: 'entregado',
    paid: false
  });
  assert.ok(failUpdate.error, 'Should fail when marking entregado without payment verification');

  // 3. Marcar pago verificado y entregado exitosamente
  const successUpdate = await handleActualizarConsulta({
    lead_id: created.lead_id,
    status: 'entregado',
    paid: true
  });
  assert.strictEqual(successUpdate.success, true);
  assert.strictEqual(successUpdate.status, 'entregado');
  assert.strictEqual(successUpdate.paid, true);

  const inDb = await queryFirst('SELECT * FROM leads WHERE id = ?', [created.lead_id]);
  assert.strictEqual(inDb.status, 'entregado');
  assert.strictEqual(inDb.paid, 1);
});

test('Agent Tool: crear_producto y actualizar_producto gestionan catálogo y visibilidad', async () => {
  const newProd = await handleCrearProducto({
    id: 'f9-tws',
    name: 'Auriculares F9 Bluetooth',
    cost: 35,
    price: 70,
    min_price: 60,
    availability: 'en_mano',
    available_units: 5,
    facts: 'Batería de estuche con display digital',
    is_active: true
  });

  assert.strictEqual(newProd.success, true);
  assert.strictEqual(newProd.product_id, 'f9-tws');

  // Actualizar precio y ocultar producto
  const updated = await handleActualizarProducto({
    product_id: 'f9-tws',
    price: 75,
    is_active: false
  });

  assert.strictEqual(updated.success, true);
  assert.strictEqual(updated.price, 75);
  assert.strictEqual(updated.is_active, false);

  const inDb = await queryFirst('SELECT * FROM products WHERE id = ?', ['f9-tws']);
  assert.strictEqual(inDb.price, 75);
  assert.strictEqual(inDb.is_active, false);
});

test('Agent Tool: consultar_metricas calcula márgenes y entregas en Bolivia', async () => {
  const metrics = await handleConsultarMetricas({
    metric_type: 'resumen_general'
  });

  assert.strictEqual(metrics.metric, 'resumen_general');
  assert.ok(typeof metrics.fecha_bolivia === 'string');
  assert.ok(typeof metrics.entregas_pendientes_hoy === 'number');

  const stockCritico = await handleConsultarMetricas({
    metric_type: 'stock_critico'
  });
  assert.strictEqual(stockCritico.metric, 'stock_critico');
  assert.ok(Array.isArray(stockCritico.productos));
});

test('Agent Tool: redactar_respuesta provee directrices de venta locales', async () => {
  const draftData = await handleRedactarRespuesta({
    product_id: 'pb225',
    customer_message: '¿Hacen entregas a domicilio? ¿Cuánto lo último?',
    goal: 'cerrar venta por Yango'
  });

  assert.strictEqual(draftData.success, true);
  assert.strictEqual(draftData.product_name, 'Yesido PB225');
  assert.ok(draftData.policy_guideline.includes('Yango'));
  assert.ok(draftData.policy_guideline.includes(String(draftData.min_price)));
});

test('Agent Tool: eliminar_consulta borra con confirmación', async () => {
  const created = await handleCrearConsulta({
    alias: 'Cliente Temporal',
    product_id: 'pb225'
  });

  const withoutConfirm = await handleEliminarConsulta({
    lead_id: created.lead_id,
    confirm: false
  });
  assert.ok(withoutConfirm.error);

  const deleted = await handleEliminarConsulta({
    lead_id: created.lead_id,
    confirm: true
  });
  assert.strictEqual(deleted.success, true);

  const inDb = await queryFirst('SELECT * FROM leads WHERE id = ?', [created.lead_id]);
  assert.strictEqual(inDb, null);
});

test('Agent Dispatcher: executeTool maneja errores y llamadas', async () => {
  const unknown = await executeTool('herramienta_inexistente', {});
  assert.ok(unknown.error);

  const valid = await executeTool('consultar_metricas', { metric_type: 'stock_critico' });
  assert.strictEqual(valid.metric, 'stock_critico');
});

test('Agent Context: getBoliviaContext y buildSystemInstruction generan contexto temporal y comercial', async () => {
  const bolivia = getBoliviaContext();
  assert.ok(bolivia.fullDateTime);
  assert.ok(/^\d{4}-\d{2}-\d{2}$/.test(bolivia.isoDate));

  const prompt = await buildSystemInstruction();
  assert.ok(prompt.includes('Santa Cruz de la Sierra, Bolivia'));
  assert.ok(prompt.includes('Yango'));
  assert.ok(prompt.includes('UAGRM'));
  assert.ok(prompt.includes(bolivia.isoDate));
});

test('Agent Orchestrator: Controla ausencia de GEMINI_API_KEY limpiamente', async () => {
  const original = process.env.GEMINI_API_KEY;
  delete process.env.GEMINI_API_KEY;
  await assert.rejects(
    async () => {
      const { runAgentCommand } = await import('../src/agent/agentOrchestrator.js');
      await runAgentCommand('Hola');
    },
    /GEMINI_API_KEY/
  );
  if (original) process.env.GEMINI_API_KEY = original;
});

test('Agent Capa 1: buildTranslatorInstruction cubre múltiples ámbitos y vocabulario amplio', async () => {
  const { buildTranslatorInstruction, getBoliviaContext } = await import('../src/agent/agentOrchestrator.js');
  const bolivia = getBoliviaContext();
  const instruction = buildTranslatorInstruction(bolivia, 'Catálogo test');

  // Ámbitos
  assert.ok(instruction.includes('consultas'));
  assert.ok(instruction.includes('productos'));
  assert.ok(instruction.includes('metricas'));
  assert.ok(instruction.includes('redaccion'));
  assert.ok(instruction.includes('conversacion'));

  // Vocabulario coloquial amplio
  assert.ok(instruction.includes('agendar'));
  assert.ok(instruction.includes('ya me transfirió'));
  assert.ok(instruction.includes('pasalo a'));
  assert.ok(instruction.includes('se cayó la venta'));
  assert.ok(instruction.includes('pausar'));
  assert.ok(instruction.includes('ocultar'));
  assert.ok(instruction.includes('cuánta plata'));
  assert.ok(instruction.includes('carreras'));
  assert.ok(instruction.includes('redactale'));
});
