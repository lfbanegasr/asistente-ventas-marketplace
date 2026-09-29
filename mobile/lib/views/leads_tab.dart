import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/lead.dart';
import '../widgets/status_badge.dart';

class LeadsTab extends StatefulWidget {
  const LeadsTab({
    super.key,
    required this.leads,
    required this.onRefresh,
    required this.onLeadTap,
  });

  final List<Lead> leads;
  final Future<void> Function() onRefresh;
  final ValueChanged<Lead> onLeadTap;

  @override
  State<LeadsTab> createState() => _LeadsTabState();
}

class _LeadsTabState extends State<LeadsTab> {
  String _searchQuery = '';
  String _statusFilter = '';

  static const _labels = {
    'consulta': 'Consulta',
    'interesado': 'Interesado',
    'confirmado': 'Confirmado',
    'comprado': 'Comprado',
    'agendado': 'Agendado',
    'entregado': 'Entregado',
    'cancelado': 'Cancelado',
  };

  String _money(int value) => 'Bs ${NumberFormat('#,##0', 'es').format(value)}';

  @override
  Widget build(BuildContext context) {
    final filtered = widget.leads.where((l) {
      if (_statusFilter.isNotEmpty && l.status != _statusFilter) return false;
      if (_searchQuery.isNotEmpty &&
          !'${l.alias} ${l.productName}'.toLowerCase().contains(_searchQuery.toLowerCase())) {
        return false;
      }
      return true;
    }).toList();

    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: 'Buscar...',
                      prefixIcon: Icon(Icons.search),
                      isDense: true,
                    ),
                    onChanged: (v) => setState(() => _searchQuery = v),
                  ),
                ),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: _statusFilter.isEmpty ? null : _statusFilter,
                  hint: const Text('Estado', style: TextStyle(fontSize: 13)),
                  items: [
                    const DropdownMenuItem(value: '', child: Text('Todos')),
                    ..._labels.entries.map(
                      (e) => DropdownMenuItem(value: e.key, child: Text(e.value)),
                    ),
                  ],
                  onChanged: (v) => setState(() => _statusFilter = v ?? ''),
                ),
              ],
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? const Center(
                    child: Text(
                      'No hay consultas con ese filtro.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: filtered.length,
                    itemBuilder: (ctx, i) {
                      final l = filtered[i];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: InkWell(
                          onTap: () => widget.onLeadTap(l),
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
                                            l.alias,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          Text(
                                            '${l.productName} · ${l.channel}',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Color(0xFF68787B),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        StatusBadge(
                                          text: l.statusLabel,
                                          status: l.status,
                                        ),
                                        const SizedBox(width: 4),
                                        const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 12,
                                  runSpacing: 4,
                                  children: [
                                    Text(
                                      'Venta ${_money(l.amount)}',
                                      style: const TextStyle(fontSize: 13, color: Color(0xFF617177)),
                                    ),
                                    Text(
                                      'Margen ${_money(l.netMargin)}',
                                      style: const TextStyle(fontSize: 13, color: Color(0xFF617177)),
                                    ),
                                    Text(
                                      l.paid ? 'Pago ✓' : 'Pago pendiente',
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
          ),
        ],
      ),
    );
  }
}
