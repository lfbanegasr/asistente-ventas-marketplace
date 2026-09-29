import 'package:flutter/material.dart';

class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.text,
    required this.status,
  });

  final String text;
  final String status;

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;

    switch (status) {
      case 'entregado':
        bg = const Color(0xFFDCFCE7);
        fg = const Color(0xFF15803D);
        break;
      case 'consulta':
        bg = const Color(0xFFF3F4F6);
        fg = const Color(0xFF4B5563);
        break;
      case 'interesado':
        bg = const Color(0xFFFEF3C7);
        fg = const Color(0xFFB45309);
        break;
      case 'confirmado':
        bg = const Color(0xFFCCFBF1);
        fg = const Color(0xFF0F766E);
        break;
      case 'agendado':
        bg = const Color(0xFFDBEAFE);
        fg = const Color(0xFF1D4ED8);
        break;
      case 'comprado':
        bg = const Color(0xFFD1FAE5);
        fg = const Color(0xFF047857);
        break;
      case 'cancelado':
        bg = const Color(0xFFFEE2E2);
        fg = const Color(0xFFB91C1C);
        break;
      case 'en_mano':
        bg = const Color(0xFFEDF4F0);
        fg = const Color(0xFF2C7569);
        break;
      case 'proveedor_confirmado':
        bg = const Color(0xFFEDF8F4);
        fg = const Color(0xFF1B6A53);
        break;
      case 'por_confirmar':
      default:
        bg = const Color(0xFFFFF3E6);
        fg = const Color(0xFFA65C2B);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(50),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: fg,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
