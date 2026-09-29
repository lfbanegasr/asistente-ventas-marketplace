import 'package:flutter/material.dart';

class StatusSelectorChips extends StatelessWidget {
  const StatusSelectorChips({
    super.key,
    required this.selectedStatus,
    required this.onStatusSelected,
  });

  final String selectedStatus;
  final ValueChanged<String> onStatusSelected;

  static const List<Map<String, dynamic>> _statusItems = [
    {
      'key': 'consulta',
      'label': 'Consulta',
      'icon': Icons.chat_bubble_outline,
      'color': Color(0xFF4B5563),
      'bg': Color(0xFFF3F4F6),
    },
    {
      'key': 'interesado',
      'label': 'Interesado',
      'icon': Icons.visibility_outlined,
      'color': Color(0xFFB45309),
      'bg': Color(0xFFFEF3C7),
    },
    {
      'key': 'confirmado',
      'label': 'Confirmado',
      'icon': Icons.thumb_up_alt_outlined,
      'color': Color(0xFF0F766E),
      'bg': Color(0xFFCCFBF1),
    },
    {
      'key': 'agendado',
      'label': 'Agendado',
      'icon': Icons.calendar_month_outlined,
      'color': Color(0xFF1D4ED8),
      'bg': Color(0xFFDBEAFE),
    },
    {
      'key': 'comprado',
      'label': 'Comprado',
      'icon': Icons.attach_money,
      'color': Color(0xFF047857),
      'bg': Color(0xFFD1FAE5),
    },
    {
      'key': 'entregado',
      'label': 'Entregado',
      'icon': Icons.check_circle_outline,
      'color': Color(0xFF15803D),
      'bg': Color(0xFFDCFCE7),
    },
    {
      'key': 'cancelado',
      'label': 'Cancelado',
      'icon': Icons.cancel_outlined,
      'color': Color(0xFFB91C1C),
      'bg': Color(0xFFFEE2E2),
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Estado de la consulta',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF4B5563),
              ),
            ),
            Text(
              selectedStatus.toUpperCase(),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Color(0xFFDF7447),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _statusItems.map((st) {
              final isSel = selectedStatus == st['key'];
              final color = st['color'] as Color;
              final bg = st['bg'] as Color;
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  avatar: Icon(
                    st['icon'] as IconData,
                    size: 16,
                    color: isSel ? Colors.white : color,
                  ),
                  label: Text(st['label'] as String),
                  selected: isSel,
                  selectedColor: color,
                  backgroundColor: bg,
                  labelStyle: TextStyle(
                    color: isSel ? Colors.white : const Color(0xFF1F2937),
                    fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                    fontSize: 12,
                  ),
                  showCheckmark: false,
                  onSelected: (selected) {
                    if (selected) {
                      onStatusSelected(st['key'] as String);
                    }
                  },
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
