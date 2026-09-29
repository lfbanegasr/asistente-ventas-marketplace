import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/lead.dart';
import '../models/dashboard_metrics.dart';
import '../utils/url_helper.dart';
import '../modals/receipt_modal.dart';

class DashboardTab extends StatelessWidget {
  const DashboardTab({
    super.key,
    required this.metrics,
    required this.onRefresh,
    required this.onNewLeadTap,
    required this.onLeadTap,
  });

  final DashboardMetrics metrics;
  final Future<void> Function() onRefresh;
  final VoidCallback onNewLeadTap;
  final ValueChanged<Lead> onLeadTap;

  String _money(int value) => 'Bs ${NumberFormat('#,##0', 'es').format(value)}';

  String _formatFriendlyDateTime(DateTime dt) {
    const weekdays = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
    const months = [
      'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
      'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'
    ];
    final weekday = weekdays[dt.weekday - 1];
    final day = dt.day;
    final month = months[dt.month - 1];
    final year = dt.year;
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final targetDay = DateTime(dt.year, dt.month, dt.day);
    final diffDays = targetDay.difference(today).inDays;

    String relative = '';
    if (diffDays == 0) {
      relative = ' (Hoy)';
    } else if (diffDays == 1) {
      relative = ' (Mañana)';
    } else if (diffDays == -1) {
      relative = ' (Ayer)';
    }

    return '$weekday $day $month $year$relative · $hour:$minute';
  }

  String _formatHourOnly(String? raw) {
    if (raw == null || raw.isEmpty) return 'Hora pendiente';
    try {
      final dt = DateTime.parse(raw.length > 10 ? raw : '${raw}T12:00:00');
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      return '$h:$m';
    } catch (_) {
      return raw;
    }
  }

  String _localDate(String? value) {
    if (value == null || value.isEmpty) return 'Sin fecha';
    try {
      final dt = DateTime.parse(value.length > 10 ? value : '${value}T12:00:00');
      return _formatFriendlyDateTime(dt);
    } catch (_) {
      return value;
    }
  }

  Widget _metricCard(String label, String value) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE0E5DF)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: Color(0xFF68787B)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.8,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTodayDeliveryCard(BuildContext context, Lead lead) {
    final hour = _formatHourOnly(lead.deliveryAt);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDF7447), width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF2EC),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.alarm, color: Color(0xFFDF7447), size: 18),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              lead.alias,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF172A3A),
                              ),
                            ),
                            Text(
                              '${lead.productName} · Total ${_money(lead.amount)}',
                              style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF172A3A),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    hour,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.place_outlined, size: 16, color: Color(0xFF172A3A)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    lead.deliveryPlace.isNotEmpty ? lead.deliveryPlace : 'Lugar pendiente de definir',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF374151)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(color: Color(0xFFF0F3F1), height: 1),
            const SizedBox(height: 10),

            // Acciones Rápidas (WhatsApp, Mapa, Recibo)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      side: const BorderSide(color: Color(0xFF25D366)),
                      foregroundColor: const Color(0xFF15803D),
                    ),
                    icon: const Icon(Icons.chat_bubble_outline, size: 15, color: Color(0xFF25D366)),
                    label: const Text('WhatsApp', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    onPressed: () {
                      final msg = '¡Hola ${lead.alias}! Te escribo de Mesa de Ventas para coordinar la entrega de tu ${lead.productName} hoy a las $hour en ${lead.deliveryPlace}. ¿Todo listo?';
                      UrlHelper.openWhatsAppChat(text: msg);
                    },
                  ),
                ),
                const SizedBox(width: 6),
                if (lead.deliveryPlace.isNotEmpty) ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        side: const BorderSide(color: Color(0xFFDCE2DD)),
                        foregroundColor: const Color(0xFF172A3A),
                      ),
                      icon: const Icon(Icons.map_outlined, size: 15),
                      label: const Text('Mapa', style: TextStyle(fontSize: 12)),
                      onPressed: () => UrlHelper.openMapForLocation(lead.deliveryPlace),
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                IconButton.filledTonal(
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFFF3F5F2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.receipt_long, size: 18, color: Color(0xFF172A3A)),
                  tooltip: 'Comprobante',
                  onPressed: () => ReceiptModal.show(context, lead: lead),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(BuildContext context, Lead lead) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE7EAE7)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  lead.alias,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  '${lead.productName} · ${_localDate(lead.deliveryAt)} · ${lead.deliveryPlace.isNotEmpty ? lead.deliveryPlace : "lugar pendiente"}',
                  style: const TextStyle(color: Color(0xFF6D7B7F), fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.receipt_long, size: 18, color: Color(0xFF172A3A)),
            tooltip: 'Comprobante',
            onPressed: () => ReceiptModal.show(context, lead: lead),
          ),
          const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheduled = metrics.upcomingDeliveries;
    final today = metrics.todayDeliveries;
    final isMorning = DateTime.now().hour < 13;

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          // Morning Reminder Banner
          if (today.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFFDBA74)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.wb_sunny_rounded, color: Color(0xFFEA580C), size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      isMorning
                          ? '¡Buen día! Tienes ${today.length} entrega(s) agendada(s) para hoy.'
                          : 'Recordatorio: ${today.length} entrega(s) agendada(s) para hoy.',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF9A3412),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Hero card
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF172A3A),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'TU DÍA, CLARO',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                    color: Color(0xFFD46E3D),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Responde, confirma\ny entrega.',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -1.2,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Registra solo las consultas que necesitan seguimiento.',
                  style: TextStyle(color: Color(0xFFC5D1D4), fontSize: 14),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD46E3D),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: onNewLeadTap,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text(
                    '+ Nueva consulta',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Metrics grid
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.65,
            children: [
              _metricCard('Consultas activas', '${metrics.openLeadsCount}'),
              _metricCard('Confirmados', '${metrics.confirmedCount}'),
              _metricCard('Entregados', '${metrics.deliveredCount}'),
              _metricCard('Margen cobrado', _money(metrics.collectedMargin)),
            ],
          ),
          const SizedBox(height: 18),

          // SECCIÓN DESTACADA: ENTREGAS PARA HOY
          if (today.isNotEmpty) ...[
            Row(
              children: [
                const Icon(Icons.local_shipping, size: 20, color: Color(0xFFDF7447)),
                const SizedBox(width: 8),
                Text(
                  'Entregas para HOY (${today.length})',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF172A3A),
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            for (final l in today) _buildTodayDeliveryCard(context, l),
            const SizedBox(height: 10),
          ],

          // Upcoming deliveries
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text(
              'Próximas entregas',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
          ),
          if (scheduled.isEmpty)
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9F5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Aún no hay entregas agendadas.',
                style: TextStyle(color: Color(0xFF66777C), fontSize: 14),
              ),
            )
          else
            ...scheduled.take(5).map((l) => InkWell(
                  onTap: () => onLeadTap(l),
                  borderRadius: BorderRadius.circular(12),
                  child: _infoRow(context, l),
                )),
        ],
      ),
    );
  }
}
