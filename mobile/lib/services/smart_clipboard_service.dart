import '../models/product.dart';

class ClipboardAnalysisResult {
  const ClipboardAnalysisResult({
    required this.originalText,
    this.matchedProduct,
    required this.detectedIntent,
    required this.suggestedReply,
  });

  final String originalText;
  final Product? matchedProduct;
  final String detectedIntent; // 'precio' | 'disponibilidad' | 'entrega' | 'general'
  final String suggestedReply;
}

class SmartClipboardService {
  /// Analiza texto del portapapeles y genera una respuesta comercial persuasiva
  static ClipboardAnalysisResult analyze(String text, List<Product> products) {
    final clean = text.trim();
    if (clean.isEmpty) {
      return const ClipboardAnalysisResult(
        originalText: '',
        detectedIntent: 'general',
        suggestedReply: '¡Hola! Con gusto te paso la información. ¿Cuál de nuestros productos te interesa?',
      );
    }

    final lower = clean.toLowerCase();

    // 1. Detección de Producto
    Product? matched;
    int bestScore = 0;

    for (final p in products) {
      int score = 0;
      final pNameLower = p.name.toLowerCase();

      // Coincidencia exacta de nombre o subcadena
      if (lower.contains(pNameLower)) {
        score += 10;
      }

      // Coincidencia por palabras clave del modelo (ej. "pb6010", "pb225", "yesido")
      final tokens = pNameLower.split(RegExp(r'\s+')).where((t) => t.length > 2);
      for (final t in tokens) {
        if (lower.contains(t)) {
          score += 3;
        }
      }

      if (score > bestScore) {
        bestScore = score;
        matched = p;
      }
    }

    // 2. Detección de Intención
    String intent = 'general';
    if (RegExp(r'(precio|cu[aá]nto|sale|cuesta|costo|rebaja|descuento|menos)').hasMatch(lower)) {
      intent = 'precio';
    } else if (RegExp(r'(stock|tienes|hay|disponible|quedan|unidades)').hasMatch(lower)) {
      intent = 'disponibilidad';
    } else if (RegExp(r'(delivery|donde|d[oó]nde|entrega|env[ií]o|lugar|ubicaci[oó]n|yango)').hasMatch(lower)) {
      intent = 'entrega';
    }

    // 3. Generación de Respuesta Comercial Local (Bolivia)
    String reply;
    if (matched != null) {
      final name = matched.name;
      final price = 'Bs ${matched.price}';
      final inHand = matched.isInHand && matched.availableUnits > 0;

      if (intent == 'precio') {
        if (inHand) {
          reply = '¡Hola! El $name está a $price con entrega inmediata en Santa Cruz. ¿Te gustaría coordinar la entrega hoy en persona o por Yango?';
        } else {
          reply = '¡Buenas! El $name tiene un precio de $price. Podemos apartártelo para coordinar entrega. ¿Para qué fecha lo necesitas?';
        }
      } else if (intent == 'disponibilidad') {
        if (inHand) {
          reply = '¡Hola! Sí, tenemos stock disponible del $name (${matched.availableUnits} unidad(es) listas para entrega). El precio es $price. ¿Te reservo una?';
        } else {
          reply = '¡Hola! El $name está confirmado con proveedor para entrega ${matched.readyDate.isNotEmpty ? 'el ${matched.readyDate}' : 'próximamente'}. El precio es $price. ¿Deseas asegurar tu reserva?';
        }
      } else if (intent == 'entrega') {
        reply = '¡Buenas! Entregamos en puntos céntricos como Cine Center, UAGRM, Ventura Mall o envío a domicilio por Yango moto en Santa Cruz. El $name está a $price. ¿Qué punto te queda más cerca?';
      } else {
        reply = '¡Hola! El $name está disponible a $price. Es un producto verificado con excelente rendimiento. ¿Deseas coordinar la entrega o tienes alguna consulta puntual?';
      }
    } else {
      reply = '¡Hola! Con gusto te brindo información y precios con entrega en Santa Cruz. ¿Cuál producto o modelo estás buscando?';
    }

    return ClipboardAnalysisResult(
      originalText: clean,
      matchedProduct: matched,
      detectedIntent: intent,
      suggestedReply: reply,
    );
  }
}
