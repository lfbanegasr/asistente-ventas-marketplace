import 'package:flutter/material.dart';

class InteractiveDateTimePicker extends StatelessWidget {
  const InteractiveDateTimePicker({
    super.key,
    required this.selectedDateTime,
    required this.onDateTimeChanged,
  });

  final DateTime? selectedDateTime;
  final ValueChanged<DateTime?> onDateTimeChanged;

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

  String _toIsoDateTime(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$y-$m-${d}T$h:$min';
  }

  Future<void> _pickInteractiveDateTime(BuildContext context) async {
    final now = DateTime.now();
    final base = selectedDateTime ?? now;
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: base,
      firstDate: now.subtract(const Duration(days: 90)),
      lastDate: now.add(const Duration(days: 365)),
      helpText: 'SELECCIONA EL DÍA DE ENTREGA / CITA',
      confirmText: 'SIGUIENTE: HORA',
      cancelText: 'CANCELAR',
    );
    if (pickedDate == null || !context.mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: base.hour, minute: base.minute),
      helpText: 'SELECCIONA LA HORA',
      confirmText: 'CONFIRMAR',
      cancelText: 'CANCELAR',
    );
    if (pickedTime == null) return;

    onDateTimeChanged(DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    ));
  }

  Future<void> _pickOnlyDate(BuildContext context) async {
    final now = DateTime.now();
    final base = selectedDateTime ?? now;
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: base,
      firstDate: now.subtract(const Duration(days: 90)),
      lastDate: now.add(const Duration(days: 365)),
      helpText: 'CAMBIAR DÍA',
    );
    if (pickedDate != null) {
      final currentH = selectedDateTime?.hour ?? 16;
      final currentM = selectedDateTime?.minute ?? 0;
      onDateTimeChanged(DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        currentH,
        currentM,
      ));
    }
  }

  Future<void> _pickOnlyTime(BuildContext context) async {
    final base = selectedDateTime ?? DateTime.now();
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: base.hour, minute: base.minute),
      helpText: 'CAMBIAR HORA',
    );
    if (pickedTime != null) {
      final d = selectedDateTime ?? DateTime.now();
      onDateTimeChanged(DateTime(
        d.year,
        d.month,
        d.day,
        pickedTime.hour,
        pickedTime.minute,
      ));
    }
  }

  void _applyPreset({
    int hoursOffset = 0,
    int? targetHour,
    int? targetMinute,
    int daysOffset = 0,
  }) {
    final now = DateTime.now();
    DateTime target;
    if (targetHour != null) {
      final d = now.add(Duration(days: daysOffset));
      target = DateTime(d.year, d.month, d.day, targetHour, targetMinute ?? 0);
    } else {
      final raw = now.add(Duration(hours: hoursOffset));
      final roundedMin = (raw.minute / 15).ceil() * 15;
      if (roundedMin >= 60) {
        target = DateTime(raw.year, raw.month, raw.day, raw.hour + 1, 0);
      } else {
        target = DateTime(raw.year, raw.month, raw.day, raw.hour, roundedMin);
      }
    }
    onDateTimeChanged(target);
  }

  @override
  Widget build(BuildContext context) {
    final hasDate = selectedDateTime != null;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: hasDate ? const Color(0xFFF7FBF9) : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasDate ? const Color(0xFF3B9B7E) : const Color(0xFFE5E7EB),
          width: hasDate ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.event_available_rounded,
                    size: 20,
                    color: hasDate ? const Color(0xFF1B6A53) : const Color(0xFF6B7280),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Fecha y hora de entrega / cita',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ],
              ),
              if (hasDate)
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFFC81E1E)),
                  tooltip: 'Quitar fecha',
                  constraints: const BoxConstraints(),
                  padding: EdgeInsets.zero,
                  onPressed: () => onDateTimeChanged(null),
                ),
            ],
          ),
          const SizedBox(height: 10),

          if (!hasDate) ...[
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Sin fecha programada (opcional)',
                    style: TextStyle(color: Color(0xFF6B7280), fontSize: 13),
                  ),
                ),
                FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF172A3A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.calendar_month, size: 17),
                  label: const Text(
                    'Elegir fecha y hora',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  onPressed: () => _pickInteractiveDateTime(context),
                ),
              ],
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFD1E7DD)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.schedule, color: Color(0xFF1B6A53), size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _formatFriendlyDateTime(selectedDateTime!),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Color(0xFF111827),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Código para sistema: ${_toIsoDateTime(selectedDateTime!)}',
                          style: const TextStyle(fontSize: 10, color: Color(0xFF6B7280)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.calendar_today, size: 15),
                    label: const Text('Cambiar día', style: TextStyle(fontSize: 12)),
                    onPressed: () => _pickOnlyDate(context),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.access_time, size: 15),
                    label: const Text('Cambiar hora', style: TextStyle(fontSize: 12)),
                    onPressed: () => _pickOnlyTime(context),
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 10),
          const Text(
            '⚡ Atajos rápidos de un toque:',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF4B5563),
            ),
          ),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ActionChip(
                  avatar: const Icon(Icons.flash_on, size: 14, color: Color(0xFFDF7447)),
                  label: const Text('Hoy +1h', style: TextStyle(fontSize: 11)),
                  onPressed: () => _applyPreset(hoursOffset: 1),
                ),
                const SizedBox(width: 6),
                ActionChip(
                  avatar: const Icon(Icons.flash_on, size: 14, color: Color(0xFFDF7447)),
                  label: const Text('Hoy +2h', style: TextStyle(fontSize: 11)),
                  onPressed: () => _applyPreset(hoursOffset: 2),
                ),
                const SizedBox(width: 6),
                ActionChip(
                  label: const Text('Hoy 16:00', style: TextStyle(fontSize: 11)),
                  onPressed: () => _applyPreset(targetHour: 16, targetMinute: 0),
                ),
                const SizedBox(width: 6),
                ActionChip(
                  label: const Text('Hoy 18:30', style: TextStyle(fontSize: 11)),
                  onPressed: () => _applyPreset(targetHour: 18, targetMinute: 30),
                ),
                const SizedBox(width: 6),
                ActionChip(
                  label: const Text('Mañana 10:00', style: TextStyle(fontSize: 11)),
                  onPressed: () => _applyPreset(daysOffset: 1, targetHour: 10, targetMinute: 0),
                ),
                const SizedBox(width: 6),
                ActionChip(
                  label: const Text('Mañana 15:30', style: TextStyle(fontSize: 11)),
                  onPressed: () => _applyPreset(daysOffset: 1, targetHour: 15, targetMinute: 30),
                ),
                const SizedBox(width: 6),
                ActionChip(
                  label: const Text('Mañana 18:00', style: TextStyle(fontSize: 11)),
                  onPressed: () => _applyPreset(daysOffset: 1, targetHour: 18, targetMinute: 0),
                ),
                const SizedBox(width: 6),
                ActionChip(
                  label: const Text('En 2 días 15:00', style: TextStyle(fontSize: 11)),
                  onPressed: () => _applyPreset(daysOffset: 2, targetHour: 15, targetMinute: 0),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
