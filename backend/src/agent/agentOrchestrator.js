import { GoogleGenAI } from '@google/genai';
import { toolsDeclarations, executeTool } from './tools.js';
import { query } from '../database.js';

/**
 * Obtiene la fecha, hora y día de la semana actual en Santa Cruz, Bolivia (UTC-4)
 */
export function getBoliviaContext() {
  const now = new Date();

  const formatterFull = new Intl.DateTimeFormat('es-BO', {
    timeZone: 'America/La_Paz',
    weekday: 'long',
    year: 'numeric',
    month: 'long',
    day: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
    hour12: false
  });

  const formatterIsoDate = new Intl.DateTimeFormat('en-CA', {
    timeZone: 'America/La_Paz',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit'
  });

  const formatterTime = new Intl.DateTimeFormat('es-BO', {
    timeZone: 'America/La_Paz',
    hour: '2-digit',
    minute: '2-digit',
    hour12: false
  });

  const fullDateTime = formatterFull.format(now);
  const isoDate = formatterIsoDate.format(now);
  const currentTime = formatterTime.format(now);

  return {
    fullDateTime,
    isoDate,
    currentTime,
    now
  };
}

/**
 * Obtiene el resumen del catálogo activo para dar contexto de entidades a Gemini
 */
export async function getCatalogSummary() {
  let products = [];
  try {
    products = await query(
      'SELECT id, name, price, min_price, availability, available_units FROM products WHERE is_active = TRUE ORDER BY name'
    );
  } catch (err) {
    console.warn('[Agent] Error cargando catálogo de productos:', err.message);
  }

  return products.length > 0
    ? products.map(p => `- ID: "${p.id}" | Nombre: "${p.name}" | Precio: Bs ${p.price} (Mínimo interno: Bs ${p.min_price}) | Stock: ${p.availability} (${p.available_units} u.)`).join('\n')
    : '(Catálogo no disponible)';
}

/**
 * Prompt para la CAPA 1: Traductor Semántico de Prompts y Comandos de Voz
 */
export function buildTranslatorInstruction(bolivia, catalogSummary) {
  return `Eres la CAPA 1 (TRADUCTOR Y NORMALIZADOR DE PROMPTS Y VOZ) de un Asistente Agéntico de Ventas en Santa Cruz de la Sierra, Bolivia.
Tu función es recibir órdenes de voz o texto del vendedor (que pueden venir con modismos bolivianos, expresiones coloquiales, prisas o sinónimos diversos) y traducir lo recibido en una intención limpia, categorizada y estructurada formalmente para su ejecución.

DEBES ADMITIR UN VOCABULARIO MUY AMPLIO en múltiples ámbitos del negocio (no te limites a "crear", "añadir", "elimina", "edita"):

1. ÁMBITO "consultas" (Clientes, Pedidos y Agendamientos):
   - Registrar/Agendar: agendar, anotar, registrar, meter cliente, apuntar, ingresar, "el cliente me dijo...", "se acordó con...", "apartale uno a...", "cita para el viernes", "mandale por moto/yango".
   - Modificar/Avanzar: pasalo a, marcalo, poné que ya pagó, ya me transfirió por QR, ya le entregué, cambiale la fecha, movelo para las 5, cambiale el lugar a Cine Center.
   - Cancelar/Borrar: borralo, quitalo, sacalo, se cayó la venta, canceló el pedido, descartalo, ya no lo quiere.

2. ÁMBITO "productos" (Catálogo, Precios y Stock):
   - Nuevo ítem: meter producto, subir artículo, nuevo ingreso, vamos a vender X cosa a Y precio, cargá un nuevo producto.
   - Precios/Stock: subile diez pesos, bajale el costo, cambiale el precio de venta a 180, anotale 5 unidades en mano, llegaron unidades del proveedor, descontá stock.
   - Visibilidad: pausar, ocultar, desactivar, reactivar, volver a publicar, "ya no hay en tienda", "ocultá los que no tengan stock".

3. ÁMBITO "metricas" (Finanzas, Cobros y Balance diario):
   - Ganancias y cobros: cuánta plata hicimos hoy, cómo va la ganancia, cuánto margen cobrado llevo, balance del día, cuánto dinero entró por QR.
   - Entregas programadas: qué carreras de yango tengo pendientes, qué entregas hay hoy o mañana, qué pedidos faltan entregar, quién viene al módulo.
   - Stock crítico: qué productos tienen poco stock, qué está por acabarse.

4. ÁMBITO "redaccion" (Borradores comerciales para WhatsApp/Marketplace):
   - redactale, contestale, mandale a decir, sugerime respuesta para este cliente, cómo le respondo que Yango se paga antes y que no rebajo más.

5. ÁMBITO "conversacion" (Saludos o preguntas generales):
   - qué puedes hacer, ayuda, buenos días, etc.

CONTEXTO TEMPORAL ACTUAL (SANTA CRUZ, BOLIVIA - GMT-4):
- Fecha y hora actual: ${bolivia.fullDateTime}
- Fecha ISO hoy: ${bolivia.isoDate}
- Hora actual: ${bolivia.currentTime}

CATÁLOGO ACTUAL DE PRODUCTOS ACTIVOS:
${catalogSummary}

REGLAS DE RESOLUCIÓN DE ENTIDADES:
- Identifica el producto en base al catálogo y asigna su "product_id" exacto (ej: "el pb225" -> "pb225", "auricular f9" -> "f9-tws").
- Convierte cualquier fecha/hora relativa ("mañana a las 4pm", "este viernes a las 16:30", "hoy a mediodía") a fecha ISO boliviana YYYY-MM-DDTHH:mm usando la fecha de hoy (${bolivia.isoDate}).
- Identifica modalidades de entrega: "persona" (UAGRM zona módulos, Cine Center, presencial) o "yango" (envío, moto, delivery).

RESPONDE EXCLUSIVAMENTE UN OBJETO JSON con la siguiente estructura (sin formato Markdown adicional):
{
  "ambito": "consultas" | "productos" | "metricas" | "redaccion" | "conversacion",
  "intencion": "Frase concisa que describe lo que el vendedor quiere realizar",
  "es_accionable": true | false,
  "instruccion_normalizada": "Instrucción formal canónica con parámetros claros para ejecutar en base de datos",
  "clarificacion_necesaria": null | "Texto de la pregunta si falta un dato indispensable"
}`;
}

/**
 * Lista priorizada de modelos Gemini que están activos y disponibles.
 * Septiembre 2026: gemini-2.0-flash y gemini-2.5-flash-lite están DISCONTINUADOS.
 * Los modelos vigentes son: gemini-3.5-flash-lite, gemini-3.8-flash
 */
const DEPRECATED_MODELS = new Set([
  'gemini-2.5-flash-lite',
  'gemini-2.0-flash',
  'gemini-1.5-flash',
  'gemini-1.5-pro',
  'gemini-2.5-flash',
]);

export function getActiveGeminiModels() {
  const envModel = process.env.GEMINI_MODEL?.trim();
  const models = [];

  // Only add the env model if it's NOT a known deprecated one
  if (envModel && !DEPRECATED_MODELS.has(envModel)) {
    models.push(envModel);
  }

  // Current working models as of September 2026
  models.push('gemini-3.5-flash-lite', 'gemini-3.8-flash');
  return [...new Set(models)];
}

/**
 * Safely extract text from a Gemini SDK response
 */
function extractResponseText(response) {
  try {
    // The @google/genai SDK v2.x exposes .text as a getter on the response
    if (typeof response?.text === 'string') return response.text.trim();
    // Fallback: dig into candidates
    const parts = response?.candidates?.[0]?.content?.parts;
    if (parts) {
      return parts.map(p => p.text || '').join('').trim();
    }
  } catch {
    // ignore accessor errors
  }
  return '';
}

/**
 * CAPA 1: Traductor y Normalizador de Prompts / Audio
 */
export async function normalizeUserPrompt(rawCommand, ai, modelName, boliviaContext, catalogSummary) {
  const clean = typeof rawCommand === 'string' ? rawCommand.trim() : '';
  if (!clean) {
    return {
      ambito: 'conversacion',
      intencion: 'Comando vacío',
      es_accionable: false,
      instruccion_normalizada: '',
      clarificacion_necesaria: 'Por favor proporciona una orden por voz o texto.'
    };
  }

  const translatorInstruction = buildTranslatorInstruction(boliviaContext, catalogSummary);
  const models = getActiveGeminiModels();
  let response;
  let lastError;

  for (const m of models) {
    try {
      console.log(`[Capa 1] Intentando modelo: ${m}`);
      response = await ai.models.generateContent({
        model: m,
        contents: [{ role: 'user', parts: [{ text: clean }] }],
        config: {
          systemInstruction: translatorInstruction,
          responseMimeType: 'application/json',
          temperature: 0.1
        }
      });
      if (response) {
        console.log(`[Capa 1] Modelo ${m} respondió exitosamente.`);
        break;
      }
    } catch (err) {
      lastError = err;
      console.warn(`[Capa 1] Modelo ${m} falló: ${err.message}`);
      // Always try the next model on any API error
      continue;
    }
  }

  try {
    const text = extractResponseText(response);
    if (!text) throw new Error('Empty response');
    const parsed = JSON.parse(text);

    return {
      ambito: parsed.ambito || 'consultas',
      intencion: parsed.intencion || 'Procesar orden',
      es_accionable: parsed.es_accionable ?? true,
      instruccion_normalizada: parsed.instruccion_normalizada || clean,
      clarificacion_necesaria: parsed.clarificacion_necesaria || null
    };
  } catch (err) {
    console.warn('[Capa 1: Normalizador] Falló el parsing JSON de normalización, usando fallback directo:', err.message);
    if (lastError) console.warn('[Capa 1: Normalizador] Último error de API:', lastError.message);
    return {
      ambito: 'consultas',
      intencion: 'Procesar instrucción',
      es_accionable: true,
      instruccion_normalizada: clean,
      clarificacion_necesaria: null
    };
  }
}

/**
 * Prompt para la CAPA 2: Ejecutor Agéntico con Function Calling
 */
export function buildExecutionInstruction(bolivia, catalogSummary, interpretation) {
  return `Eres la CAPA 2 (MOTOR DE EJECUCIÓN AGÉNTICA) de Ventas en Santa Cruz de la Sierra, Bolivia.
Has recibido una instrucción normalizada por la Capa 1:
- Ámbito: ${interpretation.ambito}
- Intención detectada: ${interpretation.intencion}
- Instrucción canónica: ${interpretation.instruccion_normalizada}

Tu tarea es EJECUTAR LA ACCIÓN REAL llamando a la herramienta adecuada de PostgreSQL (Tool Calling):
- Ámbito consultas -> "crear_consulta", "actualizar_consulta", "eliminar_consulta"
- Ámbito productos -> "crear_producto", "actualizar_producto"
- Ámbito metricas -> "consultar_metricas"
- Ámbito redaccion -> "redactar_respuesta"

REGLAS DE NEGOCIO EN SANTA CRUZ:
1. Modalidades de entrega: "persona" (UAGRM zona módulos, Cine Center, pago al recibir) y "yango" (envío por app, REQUISITO: pago 100% por adelantado por QR antes del despacho, carrera a cuenta del cliente).
2. Precios: en Bolivianos (Bs). Nunca vender por debajo de "min_price".
3. Formato de fechas: estrictamente YYYY-MM-DDTHH:mm.

CATÁLOGO ACTUAL DE PRODUCTOS:
${catalogSummary}

FECHA Y HORA ACTUAL: ${bolivia.fullDateTime} (ISO: ${bolivia.isoDate})

FORMATO DE CONFIRMACIÓN FINAL:
Una vez ejecutada la herramienta en la base de datos, genera una confirmación BREVE, NATURAL y PRECISA en español boliviano, con emojis amigables, perfecta para ser leída por síntesis de voz (TTS) o vista en pantalla.
Ejemplo: "✅ Consulta registrada para Juan Carlos con el PB225 para el viernes 2 de octubre a las 16:00 vía Yango en el 4to anillo radial 19."`;
}

/**
 * Motor de ejecución de respaldo determinista (para contingencias de API Key inválida o cuota de Gemini)
 */
export async function executeDeterministicAction(interpretation, boliviaContext) {
  const norm = (interpretation.instruccion_normalizada || interpretation.intencion || '').toLowerCase();

  try {
    // 1. Balance o métricas
    if (norm.includes('margen') || norm.includes('ganancia') || norm.includes('cuanto') || norm.includes('cuánto') || norm.includes('balance') || norm.includes('ventas')) {
      const res = await executeTool('consultar_metricas', { metric_type: 'resumen_general' });
      return {
        reply: `📊 Resumen de hoy: ${res.entregas_pendientes_hoy || 0} entregas pendientes, margen cobrado: Bs ${res.margen_cobrado_hoy_bs || 0}, venta total: Bs ${res.venta_total_hoy_bs || 0}.`,
        executed_tools: [{ name: 'consultar_metricas', result: res }],
        state_updated: false
      };
    }

    // 2. Entregas pendientes o agenda
    if (norm.includes('entregas') || norm.includes('pendientes') || norm.includes('carreras') || norm.includes('agenda')) {
      const res = await executeTool('consultar_metricas', { metric_type: 'entregas_agendadas' });
      return {
        reply: `📦 Entregas agendadas: ${res.total_agendadas || 0} pendientes.${res.entregas?.length ? '\n' + res.entregas.map(e => `• ${e.alias} — ${e.producto} (${e.modalidad}) ${e.hora || 'sin hora'}`).join('\n') : ''}`,
        executed_tools: [{ name: 'consultar_metricas', result: res }],
        state_updated: false
      };
    }

    // 3. Modificar precio o stock de producto
    const products = await query('SELECT id, name, price, min_price, available_units FROM products WHERE is_active = TRUE');
    const matchedProduct = products.find(p => norm.includes(p.id.toLowerCase()) || norm.includes(p.name.toLowerCase()));

    if (matchedProduct && (norm.includes('precio') || norm.includes('pesos') || norm.includes('subi') || norm.includes('baja') || norm.includes('stock') || norm.includes('unidad'))) {
      const numMatch = norm.match(/(\d+)/);
      const num = numMatch ? parseInt(numMatch[1], 10) : null;
      let newPrice;
      let newUnits;
      if (num !== null) {
        if (norm.includes('subi') || norm.includes('aument')) {
          newPrice = matchedProduct.price + num;
        } else if (norm.includes('baja') || norm.includes('rebaj')) {
          newPrice = Math.max(matchedProduct.min_price, matchedProduct.price - num);
        } else if (norm.includes('unidad') || norm.includes('stock') || norm.includes('en mano')) {
          newUnits = num;
        } else {
          newPrice = num;
        }
      }
      const updateArgs = { product_id: matchedProduct.id };
      if (newPrice !== undefined) updateArgs.price = newPrice;
      if (newUnits !== undefined) updateArgs.available_units = newUnits;

      const res = await executeTool('actualizar_producto', updateArgs);
      return {
        reply: `✅ Catálogo actualizado: ${matchedProduct.name} ahora a Bs ${res.price ?? matchedProduct.price} (${res.available_units ?? matchedProduct.available_units} u. en mano).`,
        executed_tools: [{ name: 'actualizar_producto', args: updateArgs, result: res }],
        state_updated: true
      };
    }

    // 4. Agendar o registrar consulta
    if (norm.includes('agend') || norm.includes('anot') || norm.includes('registr') || norm.includes('cliente') || norm.includes('consulta')) {
      const prodId = matchedProduct ? matchedProduct.id : (products[0]?.id || 'pb225');
      const isYango = norm.includes('yango') || norm.includes('moto') || norm.includes('envio') || norm.includes('envío');
      const place = isYango ? 'Envío por Yango (Santa Cruz)' : (norm.includes('cine') ? 'Cine Center' : 'UAGRM Módulos');

      let clientName = 'Cliente nuevo';
      const forMatch = norm.match(/(?:para|a|de)\s+([a-zA-ZáéíóúÁÉÍÓÚñÑ]+(?:\s+[a-zA-ZáéíóúÁÉÍÓÚñÑ]+)?)/i);
      if (forMatch && !['este', 'esta', 'el', 'la', 'los', 'las', 'un', 'una', 'yango'].includes(forMatch[1].toLowerCase())) {
        clientName = forMatch[1].trim();
      }

      const leadArgs = {
        alias: clientName,
        product_id: prodId,
        channel: norm.includes('wsp') || norm.includes('whatsapp') ? 'WhatsApp' : 'Marketplace',
        delivery_mode: isYango ? 'yango' : 'persona',
        delivery_place: place,
        delivery_at: `${boliviaContext.isoDate}T16:00`,
        agreed_price: matchedProduct ? matchedProduct.price : 180
      };

      const res = await executeTool('crear_consulta', leadArgs);
      return {
        reply: `✅ Consulta registrada con éxito: ${clientName} para ${matchedProduct?.name || 'producto'} vía ${isYango ? 'Yango (pago anticipado requerido)' : 'entrega presencial'}.`,
        executed_tools: [{ name: 'crear_consulta', args: leadArgs, result: res }],
        state_updated: true
      };
    }
  } catch (fallbackErr) {
    console.warn('[executeDeterministicAction] Fallback error:', fallbackErr.message);
  }

  return null;
}

/**
 * CAPA 2: Ejecutor Agéntico con Function Calling
 */
export async function executeAgentPipeline(interpretation, ai, modelName, boliviaContext, catalogSummary) {
  const executionInstruction = buildExecutionInstruction(boliviaContext, catalogSummary, interpretation);
  const executedTools = [];
  let stateUpdated = false;

  const contents = [
    {
      role: 'user',
      parts: [{ text: interpretation.instruccion_normalizada }]
    }
  ];

  let finalReply = '';
  const MAX_AGENT_TURNS = 5;

  const models = getActiveGeminiModels();

  for (let turn = 0; turn < MAX_AGENT_TURNS; turn++) {
    let response;
    let apiErr;

    for (const m of models) {
      try {
        console.log(`[Capa 2] Intentando modelo: ${m} (turno ${turn + 1})`);
        response = await ai.models.generateContent({
          model: m,
          contents,
          config: {
            systemInstruction: executionInstruction,
            temperature: 0.2,
            tools: [{ functionDeclarations: toolsDeclarations }]
          }
        });
        if (response) {
          console.log(`[Capa 2] Modelo ${m} respondió exitosamente.`);
          break;
        }
      } catch (err) {
        apiErr = err;
        console.warn(`[Capa 2] Modelo ${m} falló: ${err.message}`);
        // Always try next model
        continue;
      }
    }

    if (!response) {
      console.warn('[Capa 2: Execution] Todos los modelos fallaron. Último error:', apiErr?.message);
      const fallback = await executeDeterministicAction(interpretation, boliviaContext);
      if (fallback) {
        return fallback;
      }
      return {
        reply: `⚠️ No se pudo conectar con Gemini (${apiErr?.message || 'Error de conexión'}). Verifica tu GEMINI_API_KEY en Render (dashboard.render.com > Environment).`,
        executed_tools: [],
        state_updated: false
      };
    }

    const candidate = response.candidates?.[0];
    if (!candidate || !candidate.content) {
      break;
    }

    const functionCalls = response.functionCalls || [];

    if (functionCalls.length > 0) {
      // 1. Agregar la respuesta del modelo con las llamadas a herramientas al historial
      contents.push({
        role: 'model',
        parts: candidate.content.parts
      });

      // 2. Ejecutar cada una de las herramientas solicitadas contra PostgreSQL Neon
      const toolResponses = [];
      for (const fn of functionCalls) {
        console.log(`[Capa 2: Execution] Ejecutando Tool "${fn.name}" con args:`, JSON.stringify(fn.args));
        const toolResult = await executeTool(fn.name, fn.args);

        executedTools.push({
          name: fn.name,
          args: fn.args,
          result: toolResult
        });

        if (['crear_consulta', 'actualizar_consulta', 'eliminar_consulta', 'crear_producto', 'actualizar_producto'].includes(fn.name)) {
          if (toolResult && toolResult.success) {
            stateUpdated = true;
          }
        }

        toolResponses.push({
          functionResponse: {
            name: fn.name,
            response: toolResult
          }
        });
      }

      // 3. Devolver los resultados de la base de datos a Gemini
      contents.push({
        role: 'user',
        parts: toolResponses
      });

      // Continúa el loop para el turno de síntesis verbal final
    } else {
      // Síntesis conversacional final completada
      finalReply = extractResponseText(response);
      break;
    }
  }

  if (!finalReply && executedTools.length > 0) {
    const firstTool = executedTools[0];
    finalReply = firstTool.result?.success
      ? `✅ Operación completada: ${firstTool.name.replace(/_/g, ' ')}.`
      : `⚠️ ${firstTool.result?.error || 'No se pudo completar la operación.'}`;
  }

  return {
    reply: finalReply || 'Entendido.',
    executed_tools: executedTools,
    state_updated: stateUpdated
  };
}

/**
 * Orquestador Integral de Dos Capas (Traductor Semántico + Ejecutor Agéntico)
 * @param {string} userCommand Comando de voz o texto del vendedor
 * @returns {Promise<{ success: boolean, transcription: string, interpretation: object, reply: string, executed_tools: Array, state_updated: boolean }>}
 */
export async function runAgentCommand(userCommand) {
  if (!process.env.GEMINI_API_KEY) {
    throw new Error('Falta configurar GEMINI_API_KEY en las variables de entorno del servidor.');
  }

  const cleanCommand = typeof userCommand === 'string' ? userCommand.trim().slice(0, 1500) : '';
  if (!cleanCommand) {
    return {
      success: false,
      transcription: '',
      interpretation: {
        ambito: 'conversacion',
        intencion: 'Comando vacío',
        instruccion_normalizada: ''
      },
      reply: 'Por favor presiona el micrófono o escribe una instrucción para que pueda ayudarte.',
      executed_tools: [],
      state_updated: false
    };
  }

  const boliviaContext = getBoliviaContext();
  const catalogSummary = await getCatalogSummary();

  // Force a working model — ignore deprecated env values
  const activeModels = getActiveGeminiModels();
  const modelName = activeModels[0];
  console.log(`[Agent] Modelo principal seleccionado: ${modelName} (de ${activeModels.length} disponibles)`);

  const ai = new GoogleGenAI({ apiKey: process.env.GEMINI_API_KEY });

  // ═══════════════════════════════════════════════════════════════
  // CAPA 1: TRADUCTOR Y NORMALIZADOR DEL PROMPT
  // ═══════════════════════════════════════════════════════════════
  console.log(`[Capa 1: Ingesta] Recibido comando: "${cleanCommand}"`);
  const interpretation = await normalizeUserPrompt(cleanCommand, ai, modelName, boliviaContext, catalogSummary);
  console.log('[Capa 1: Normalizado]', JSON.stringify(interpretation));

  // Si requiere aclaración inmediata del vendedor (faltan datos indispensables)
  if (interpretation.clarificacion_necesaria) {
    return {
      success: true,
      transcription: cleanCommand,
      interpretation,
      reply: interpretation.clarificacion_necesaria,
      executed_tools: [],
      state_updated: false
    };
  }

  // Si no es accionable (saludo cordial o duda general)
  if (!interpretation.es_accionable) {
    return {
      success: true,
      transcription: cleanCommand,
      interpretation,
      reply: interpretation.intencion || '¡Hola! ¿En qué puedo ayudarte hoy con las ventas o consultas?',
      executed_tools: [],
      state_updated: false
    };
  }

  // ═══════════════════════════════════════════════════════════════
  // CAPA 2: MOTOR DE EJECUCIÓN AGÉNTICA (TOOL CALLING + DB)
  // ═══════════════════════════════════════════════════════════════
  const executionResult = await executeAgentPipeline(interpretation, ai, modelName, boliviaContext, catalogSummary);

  return {
    success: true,
    transcription: cleanCommand,
    interpretation,
    reply: executionResult.reply,
    executed_tools: executionResult.executed_tools,
    state_updated: executionResult.state_updated
  };
}

// Mantener retrocompatibilidad con tests anteriores
export async function buildSystemInstruction() {
  const bolivia = getBoliviaContext();
  const catalogSummary = await getCatalogSummary();
  return buildExecutionInstruction(bolivia, catalogSummary, {
    ambito: 'consultas',
    intencion: 'Procesar comando',
    instruccion_normalizada: 'Comando general'
  });
}
