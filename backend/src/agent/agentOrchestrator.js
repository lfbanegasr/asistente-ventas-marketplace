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
- Identifica modalidades de entrega: "persona" (UAGRM, Cine Center, presencial) o "yango" (envío, moto, delivery).

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

  try {
    const response = await ai.models.generateContent({
      model: modelName,
      contents: [{ role: 'user', parts: [{ text: clean }] }],
      config: {
        systemInstruction: translatorInstruction,
        responseMimeType: 'application/json',
        temperature: 0.1
      }
    });

    const text = response.text?.trim() || '';
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

  for (let turn = 0; turn < MAX_AGENT_TURNS; turn++) {
    const response = await ai.models.generateContent({
      model: modelName,
      contents,
      config: {
        systemInstruction: executionInstruction,
        temperature: 0.2,
        tools: [{ functionDeclarations: toolsDeclarations }]
      }
    });

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
      finalReply = response.text?.trim() || candidate.content.parts?.map(p => p.text || '').join('').trim();
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
  const modelName = process.env.GEMINI_MODEL || 'gemini-2.0-flash';
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
