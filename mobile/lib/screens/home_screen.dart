import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import '../main.dart';
import '../api_client.dart';
import 'login_screen.dart';
import 'chat_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _leads = [];
  bool _aiReady = false;
  bool _loading = true;
  String? _error;
  String _searchQuery = '';
  String _statusFilter = '';

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await apiClient.getState();
      setState(() {
        _products = List<Map<String, dynamic>>.from(data['products'] ?? []);
        _leads = List<Map<String, dynamic>>.from(data['leads'] ?? []);
        _aiReady = data['ai_ready'] == true;
        _loading = false;
      });
    } on AuthExpiredException {
      _goToLogin();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _goToLogin() {
    apiClient.logout();
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  void _showMessage(String message, {bool success = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: success ? const Color(0xFF2E6847) : null,
      ),
    );
  }

  String _money(dynamic value) => 'Bs ${NumberFormat('#,##0', 'es').format(value ?? 0)}';
  String _localDate(String? value) {
    if (value == null || value.isEmpty) return 'Sin fecha';
    try {
      final dt = DateTime.parse(value.length > 10 ? value : '${value}T12:00:00');
      return DateFormat(value.length > 10 ? 'd MMM yyyy HH:mm' : 'd MMM yyyy', 'es').format(dt);
    } catch (_) {
      return value;
    }
  }

  // ── Dashboard ─────────────────────────────────────────
  Widget _buildDashboard() {
    final open = _leads.where((l) => !['entregado', 'cancelado'].contains(l['status'])).toList();
    final confirmed = _leads.where((l) => ['confirmado', 'comprado', 'agendado'].contains(l['status'])).toList();
    final delivered = _leads.where((l) => l['status'] == 'entregado').toList();
    final margin = delivered.where((l) => l['paid'] == 1).fold<int>(0, (sum, l) => sum + (l['amount'] as int) - (l['actual_cost'] as int) - (l['expenses'] as int));

    final scheduled = _leads.where((l) => (l['delivery_at'] ?? '').isNotEmpty && !['entregado', 'cancelado'].contains(l['status'])).toList()
      ..sort((a, b) => (a['delivery_at'] as String).compareTo(b['delivery_at'] as String));

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
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
                Text('TU DÍA, CLARO', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 2, color: const Color(0xFFD46E3D))),
                const SizedBox(height: 8),
                const Text('Responde, confirma\ny entrega.', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -1.2)),
                const SizedBox(height: 8),
                Text('Registra solo las consultas que necesitan seguimiento.', style: TextStyle(color: const Color(0xFFC5D1D4), fontSize: 14)),
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
            childAspectRatio: 2.2,
            children: [
              _metricCard('Consultas activas', '${open.length}'),
              _metricCard('Confirmados', '${confirmed.length}'),
              _metricCard('Entregados', '${delivered.length}'),
              _metricCard('Margen cobrado', _money(margin)),
            ],
          ),
          const SizedBox(height: 16),

          // Upcoming deliveries
          _sectionTitle('Próximas entregas'),
          if (scheduled.isEmpty)
            _emptyCard('Aún no hay entregas agendadas.')
          else
            ...scheduled.take(5).map((l) => _infoRow(
              l['alias'] as String,
              '${l['product_name']} · ${_localDate(l['delivery_at'] as String?)} · ${(l['delivery_place'] as String?) ?? 'lugar pendiente'}',
            )),
        ],
      ),
    );
  }

  Widget _metricCard(String label, String value) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF68787B))),
            const SizedBox(height: 6),
            Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.8)),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
    );
  }

  Widget _emptyCard(String text) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9F5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(text, style: const TextStyle(color: Color(0xFF66777C), fontSize: 14)),
    );
  }

  Widget _infoRow(String title, String subtitle) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE7EAE7)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(color: Color(0xFF6D7B7F), fontSize: 12)),
        ],
      ),
    );
  }

  // ── Leads list ────────────────────────────────────────
  Widget _buildLeads() {
    final labels = {'consulta': 'Consulta', 'interesado': 'Interesado', 'confirmado': 'Confirmado', 'comprado': 'Comprado', 'agendado': 'Agendado', 'entregado': 'Entregado', 'cancelado': 'Cancelado'};
    final filtered = _leads.where((l) {
      if (_statusFilter.isNotEmpty && l['status'] != _statusFilter) return false;
      if (_searchQuery.isNotEmpty && !'${l['alias']} ${l['product_name']}'.toLowerCase().contains(_searchQuery.toLowerCase())) return false;
      return true;
    }).toList();

    return RefreshIndicator(
      onRefresh: _refresh,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(hintText: 'Buscar...', prefixIcon: Icon(Icons.search), isDense: true),
                    onChanged: (v) => setState(() => _searchQuery = v),
                  ),
                ),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: _statusFilter.isEmpty ? null : _statusFilter,
                  hint: const Text('Estado', style: TextStyle(fontSize: 13)),
                  items: [
                    const DropdownMenuItem(value: '', child: Text('Todos')),
                    ...labels.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))),
                  ],
                  onChanged: (v) => setState(() => _statusFilter = v ?? ''),
                ),
              ],
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? Center(child: Text('No hay consultas con ese filtro.', style: TextStyle(color: Colors.grey)))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: filtered.length,
                    itemBuilder: (ctx, i) {
                      final l = filtered[i];
                      final status = l['status'] as String;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text(l['alias'] as String, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                                    Text('${l['product_name']} · ${l['channel']}', style: const TextStyle(fontSize: 12, color: Color(0xFF68787B))),
                                  ])),
                                  _badge(labels[status] ?? status, status),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 12,
                                runSpacing: 4,
                                children: [
                                  Text('Venta ${_money(l['amount'])}', style: const TextStyle(fontSize: 13, color: Color(0xFF617177))),
                                  Text('Margen ${_money((l['amount'] as int) - (l['actual_cost'] as int) - (l['expenses'] as int))}', style: const TextStyle(fontSize: 13, color: Color(0xFF617177))),
                                  Text(l['paid'] == 1 ? 'Pago ✓' : 'Pago pendiente', style: const TextStyle(fontSize: 13, color: Color(0xFF617177))),
                                ],
                              ),
                            ],
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

  Widget _badge(String text, String status) {
    Color bg, fg;
    if (status == 'entregado') {
      bg = const Color(0xFFEEF0F5); fg = const Color(0xFF65718A);
    } else if (['consulta', 'interesado'].contains(status)) {
      bg = const Color(0xFFFFF3E6); fg = const Color(0xFFA65C2B);
    } else {
      bg = const Color(0xFFEDF4F0); fg = const Color(0xFF2C7569);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(50)),
      child: Text(text, style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w800)),
    );
  }

  // ── Products list ─────────────────────────────────────
  Widget _buildProducts() {
    final availabilityLabels = {'por_confirmar': 'Por confirmar', 'proveedor_confirmado': 'Proveedor confirmó', 'en_mano': 'En mano'};
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _products.length,
        itemBuilder: (ctx, i) {
          final p = _products[i];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(p['name'] as String, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        _badge(availabilityLabels[p['availability']] ?? '', p['availability'] == 'por_confirmar' ? 'consulta' : 'confirmado'),
                      ])),
                      Text(_money(p['price']), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.6)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    (p['facts'] as String?)?.isNotEmpty == true ? p['facts'] as String : 'Sin datos de producto',
                    style: const TextStyle(fontSize: 14, color: Color(0xFF53666C)),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 12,
                    runSpacing: 4,
                    children: [
                      Text('Costo ${_money(p['cost'])}', style: const TextStyle(fontSize: 13, color: Color(0xFF617177))),
                      Text('Mín. ${_money(p['min_price'])}', style: const TextStyle(fontSize: 13, color: Color(0xFF617177))),
                      Text('En mano: ${p['available_units']}', style: const TextStyle(fontSize: 13, color: Color(0xFF617177))),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── CSV export ────────────────────────────────────────
  void _exportCsv() {
    final cols = ['alias','channel','product_name','status','amount','actual_cost','expenses','delivery_mode','delivery_place','delivery_at','paid','notes','created_at'];
    String quote(dynamic v) => '"${(v ?? '').toString().replaceAll('"', '""')}"';
    final csv = '\ufeff${[cols.join(','), ..._leads.map((l) => cols.map((k) => quote(l[k])).join(','))].join('\r\n')}';
    final fileName = 'ventas-${DateFormat('yyyy-MM-dd').format(DateTime.now())}.csv';

    SharePlus.instance.share(ShareParams(
      files: [XFile.fromData(utf8.encode(csv), mimeType: 'text/csv')],
      fileNameOverrides: [fileName],
      title: 'Copia privada de ventas',
    ));
    _showMessage('CSV preparado para compartir', success: true);
  }

  @override
  Widget build(BuildContext context) {
    final titles = ['Inicio', 'Consultas', 'Productos', 'Asistente'];

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(titles[_currentIndex]),
            if (_currentIndex == 3)
              Text(
                _aiReady ? 'IA Gemini activa' : 'Modo respuesta base',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.normal, color: Color(0xFF6B7280)),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
            tooltip: 'Actualizar',
          ),
          if (_currentIndex == 1)
            IconButton(
              icon: const Icon(Icons.download),
              onPressed: _exportCsv,
              tooltip: 'Exportar CSV',
            ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'logout') _goToLogin();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'logout', child: Text('Cerrar sesión')),
            ],
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      ElevatedButton(onPressed: _refresh, child: const Text('Reintentar')),
                    ],
                  ),
                )
              : IndexedStack(
                  index: _currentIndex,
                  children: [
                    _buildDashboard(),
                    _buildLeads(),
                    _buildProducts(),
                    ChatScreen(products: _products),
                  ],
                ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Inicio'),
          NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: 'Consultas'),
          NavigationDestination(icon: Icon(Icons.inventory_2_outlined), selectedIcon: Icon(Icons.inventory_2), label: 'Productos'),
          NavigationDestination(icon: Icon(Icons.chat_outlined), selectedIcon: Icon(Icons.chat), label: 'Asistente'),
        ],
      ),
    );
  }
}
