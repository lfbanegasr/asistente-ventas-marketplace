import { Router } from 'express';
import { runAgentCommand } from '../agent/agentOrchestrator.js';
import { queryFirst, run } from '../database.js';

const router = Router();

// POST /api/agent/command
router.post('/command', async (req, res) => {
  if (!process.env.GEMINI_API_KEY) {
    return res.status(503).json({
      error: 'Falta configurar GEMINI_API_KEY en el servidor.',
      details: 'Ve a dashboard.render.com > Tu servicio Backend > Environment Variables y agrega la variable GEMINI_API_KEY con tu clave gratuita de Google AI Studio (aistudio.google.com).'
    });
  }

  const { command } = req.body;
  if (!command || typeof command !== 'string' || !command.trim()) {
    return res.status(400).json({
      error: 'Debes proporcionar un comando de voz o texto en el campo "command".'
    });
  }

  try {
    // Control de cuota diaria de IA (Santa Cruz, Bolivia)
    const day = new Intl.DateTimeFormat('en-CA', {
      timeZone: 'America/La_Paz',
      year: 'numeric',
      month: '2-digit',
      day: '2-digit'
    }).format(new Date());

    const existing = await queryFirst('SELECT count FROM ai_usage WHERE day = ?', [day]);
    if (!existing) {
      await run('INSERT INTO ai_usage(day, count) VALUES (?, 1) ON CONFLICT (day) DO UPDATE SET count = ai_usage.count + 1', [day]);
    } else if (Number(existing.count) >= 60) {
      return res.status(429).json({
        error: 'Límite diario de 60 peticiones agénticas alcanzado. Puedes operar manualmente en las secciones de pedidos y productos.'
      });
    } else {
      await run('UPDATE ai_usage SET count = count + 1 WHERE day = ?', [day]);
    }

    // Ejecutar el orquestador agéntico con Google Gemini SDK y Function Calling
    const result = await runAgentCommand(command.trim());

    res.json(result);
  } catch (err) {
    console.error('[API Agent Command Error]:', err);
    res.status(500).json({
      error: 'Error al procesar el comando con el Agente Inteligente.',
      details: err.message
    });
  }
});

export default router;
