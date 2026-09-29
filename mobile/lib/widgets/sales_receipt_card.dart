import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/lead.dart';

class SalesReceiptCard extends StatelessWidget {
  const SalesReceiptCard({
    super.key,
    required this.lead,
  });

  final Lead lead;

  String _money(int value) => 'Bs ${NumberFormat('#,##0', 'es').format(value)}';

  String _formatDate(String? raw) {
    if (raw == null || raw.isEmpty) return 'Por coordinar';
    try {
      final dt = DateTime.parse(raw.length > 10 ? raw : '${raw}T12:00:00');
      const weekdays = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
      const months = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];
      final weekday = weekdays[dt.weekday - 1];
      final month = months[dt.month - 1];
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      return '$weekday ${dt.day} $month ${dt.year} · $h:$m';
    } catch (_) {
      return raw;
    }
  }

  @override
  Widget build(BuildContext context) {
    final code = lead.id.length >= 8 ? lead.id.substring(0, 8).toUpperCase() : 'ORD-${lead.id}';
    final issueDate = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());

    return Container(
      width: 330,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F000000),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
        border: Border.all(color: const Color(0xFFD6DDD8), width: 1.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Elegante
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: const BoxDecoration(
              color: Color(0xFF172A3A),
              borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.storefront, color: Color(0xFFDF7447), size: 20),
                        SizedBox(width: 8),
                        Text(
                          'MESA DE VENTAS',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2C4356),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '#$code',
                        style: const TextStyle(
                          color: Color(0xFFDF7447),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'COMPROBANTE DE PEDIDO / RESERVA',
                  style: TextStyle(
                    color: Color(0xFFB0C4DE),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),

          // Contenido Principal
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Cliente
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F5F2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.person, color: Color(0xFF172A3A), size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'CLIENTE',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF6B7280)),
                          ),
                          Text(
                            lead.alias,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF172A3A)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                const Divider(color: Color(0xFFE8ECE9), height: 1),
                const SizedBox(height: 14),

                // Producto y Precio
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'PRODUCTO',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF6B7280)),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            lead.productName.isNotEmpty ? lead.productName : 'Artículo consultado',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF172A3A)),
                          ),
                          Text(
                            'Canal: ${lead.channel}',
                            style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text(
                          'TOTAL ACORDADO',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF6B7280)),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _money(lead.amount),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFFDF7447),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 14),
                const Divider(color: Color(0xFFE8ECE9), height: 1),
                const SizedBox(height: 14),

                // Detalles de Entrega / Cita
                Row(
                  children: [
                    const Icon(Icons.event_outlined, size: 16, color: Color(0xFF172A3A)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _formatDate(lead.deliveryAt),
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF2C3E50)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.place_outlined, size: 16, color: Color(0xFF172A3A)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        lead.deliveryPlace.isNotEmpty ? lead.deliveryPlace : 'Lugar por coordinar',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF2C3E50)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.delivery_dining_outlined, size: 16, color: Color(0xFF172A3A)),
                    const SizedBox(width: 8),
                    Text(
                      lead.deliveryModeLabel,
                      style: const TextStyle(fontSize: 12, color: Color(0xFF55656E)),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Estado del Pago
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: lead.paid ? const Color(0xFFEDF8F4) : const Color(0xFFFFF7ED),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: lead.paid ? const Color(0xFF88D0B7) : const Color(0xFFFED7AA),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        lead.paid ? Icons.check_circle : Icons.schedule,
                        size: 16,
                        color: lead.paid ? const Color(0xFF1B6A53) : const Color(0xFFC2410C),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          lead.paid
                              ? 'PAGO COBRADO Y VERIFICADO ✓'
                              : 'PAGO PENDIENTE CONTRA ENTREGA',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: lead.paid ? const Color(0xFF1B6A53) : const Color(0xFFC2410C),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                if (lead.notes.trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Nota: ${lead.notes.trim()}',
                    style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Color(0xFF6B7280)),
                  ),
                ],
              ],
            ),
          ),

          // Footer
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFFF7FAF8),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(18)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Emisión: $issueDate',
                  style: const TextStyle(fontSize: 10, color: Color(0xFF8E9B96)),
                ),
                const Text(
                  'Santa Cruz · Bolivia',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF536660)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
