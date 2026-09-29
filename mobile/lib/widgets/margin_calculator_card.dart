import 'package:flutter/material.dart';

class MarginCalculatorCard extends StatelessWidget {
  const MarginCalculatorCard({
    super.key,
    required this.amount,
    required this.cost,
    required this.expenses,
    this.onResetBase,
  });

  final int amount;
  final int cost;
  final int expenses;
  final VoidCallback? onResetBase;

  int get netMargin => amount - cost - expenses;

  @override
  Widget build(BuildContext context) {
    final isPositive = netMargin >= 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isPositive ? const Color(0xFFEDF8F4) : const Color(0xFFFDE8E8),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isPositive ? const Color(0xFFB0DFCE) : const Color(0xFFF8B4B4),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                isPositive ? Icons.trending_up : Icons.trending_down,
                size: 18,
                color: isPositive ? const Color(0xFF1B6A53) : const Color(0xFFC81E1E),
              ),
              const SizedBox(width: 6),
              Text(
                'Margen neto: Bs $netMargin',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: isPositive ? const Color(0xFF1B6A53) : const Color(0xFFC81E1E),
                ),
              ),
            ],
          ),
          if (onResetBase != null)
            TextButton(
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: onResetBase,
              child: const Text(
                'Restablecer base',
                style: TextStyle(fontSize: 11),
              ),
            ),
        ],
      ),
    );
  }
}
