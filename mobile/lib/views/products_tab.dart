import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/product.dart';
import '../widgets/status_badge.dart';

class ProductsTab extends StatelessWidget {
  const ProductsTab({
    super.key,
    required this.products,
    required this.onRefresh,
    required this.onProductTap,
  });

  final List<Product> products;
  final Future<void> Function() onRefresh;
  final ValueChanged<Product> onProductTap;

  String _money(int value) => 'Bs ${NumberFormat('#,##0', 'es').format(value)}';

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: products.isEmpty
          ? const Center(
              child: Text(
                'No hay productos creados. Toca "+" para agregar uno.',
                style: TextStyle(color: Colors.grey),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: products.length,
              itemBuilder: (ctx, i) {
                final p = products[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: InkWell(
                    onTap: () => onProductTap(p),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      p.name,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    StatusBadge(
                                      text: p.availabilityLabel,
                                      status: p.availability,
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    _money(p.price),
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.6,
                                    ),
                                  ),
                                  const Icon(Icons.edit_outlined, size: 16, color: Colors.grey),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            p.facts.isNotEmpty ? p.facts : 'Sin datos de producto',
                            style: const TextStyle(fontSize: 14, color: Color(0xFF53666C)),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 12,
                            runSpacing: 4,
                            children: [
                              Text(
                                'Costo ${_money(p.cost)}',
                                style: const TextStyle(fontSize: 13, color: Color(0xFF617177)),
                              ),
                              Text(
                                'Mín. ${_money(p.minPrice)}',
                                style: const TextStyle(fontSize: 13, color: Color(0xFF617177)),
                              ),
                              Text(
                                'En mano: ${p.availableUnits}',
                                style: const TextStyle(fontSize: 13, color: Color(0xFF617177)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
