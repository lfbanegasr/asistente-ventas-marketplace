import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';

import '../main.dart';
import '../api_client.dart';
import '../models/lead.dart';
import '../models/product.dart';
import '../models/dashboard_metrics.dart';
import '../modals/lead_form_sheet.dart';
import '../modals/product_form_sheet.dart';
import '../modals/voice_agent_sheet.dart';
import '../modals/smart_clipboard_sheet.dart';
import '../views/dashboard_tab.dart';
import '../views/leads_tab.dart';
import '../views/products_tab.dart';
import 'login_screen.dart';
import 'chat_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  List<Product> _products = [];
  List<Lead> _leads = [];
  bool _aiReady = false;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadFromSyncManager();
    syncManager.addListener(_onSyncUpdate);
  }

  @override
  void dispose() {
    syncManager.removeListener(_onSyncUpdate);
    super.dispose();
  }

  void _loadFromSyncManager() {
    setState(() {
      _products = syncManager.products;
      _leads = syncManager.leads;
      _aiReady = syncManager.aiReady;
      _loading = _products.isEmpty && _leads.isEmpty && syncManager.isSyncing;
    });
  }

  void _onSyncUpdate() {
    if (!mounted) return;
    setState(() {
      _products = syncManager.products;
      _leads = syncManager.leads;
      _aiReady = syncManager.aiReady;
      _loading = false;
    });
  }

  Future<void> _refresh() async {
    try {
      await syncManager.syncNow();
      _showMessage('Datos actualizados con la nube.', success: true);
    } on AuthExpiredException {
      _goToLogin();
    } catch (_) {
      _showMessage('Sin conexión. Mostrando datos locales.');
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

  void _openProductForm([Product? product]) {
    ProductFormSheet.show(
      context,
      product: product,
      onSaved: () async {
        _showMessage(
          product != null ? 'Producto actualizado.' : 'Producto creado.',
          success: true,
        );
      },
      onDeleted: () async {
        _showMessage('Producto eliminado.', success: true);
      },
    );
  }

  void _openLeadForm([Lead? lead]) {
    LeadFormSheet.show(
      context,
      lead: lead,
      products: _products,
      onSaved: () async {
        _showMessage(
          lead != null ? 'Consulta actualizada con éxito.' : 'Consulta registrada con éxito.',
          success: true,
        );
      },
      onDeleted: () async {
        _showMessage('Consulta eliminada.', success: true);
      },
    );
  }

  void _openVoiceAgent() {
    VoiceAgentSheet.show(
      context,
      onStateUpdated: _refresh,
    );
  }

  void _exportCsv() {
    final cols = [
      'alias',
      'channel',
      'product_name',
      'status',
      'amount',
      'actual_cost',
      'expenses',
      'delivery_mode',
      'delivery_place',
      'delivery_at',
      'paid',
      'notes',
      'created_at',
    ];
    String quote(dynamic v) => '"${(v ?? '').toString().replaceAll('"', '""')}"';
    final csv = '\ufeff${[
      cols.join(','),
      ..._leads.map((l) {
        final map = l.toJson();
        return cols.map((k) => quote(map[k])).join(',');
      })
    ].join('\r\n')}';

    final fileName = 'ventas-${DateFormat('yyyy-MM-dd').format(DateTime.now())}.csv';

    SharePlus.instance.share(ShareParams(
      files: [XFile.fromData(utf8.encode(csv), mimeType: 'text/csv')],
      fileNameOverrides: [fileName],
      title: 'Copia privada de ventas',
    ));
    _showMessage('CSV preparado para compartir', success: true);
  }

  Widget _buildSyncBanner() {
    if (syncManager.hasPendingMutations) {
      return Container(
        color: const Color(0xFFFEF3C7),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            const Icon(Icons.sync_problem, size: 16, color: Color(0xFFB45309)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${syncManager.pendingCount} cambio(s) pendiente(s) por subir',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF92400E),
                ),
              ),
            ),
            TextButton(
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: syncManager.isSyncing ? null : () => syncManager.syncNow(),
              child: syncManager.isSyncing
                  ? const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text(
                      'Subir ahora',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFB45309),
                      ),
                    ),
            ),
          ],
        ),
      );
    }
    if (syncManager.isOffline) {
      return Container(
        color: const Color(0xFFEFF6FF),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: const Row(
          children: [
            Icon(Icons.wifi_off, size: 15, color: Color(0xFF1E40AF)),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Modo sin conexión · Operando con caché local',
                style: TextStyle(fontSize: 12, color: Color(0xFF1E3A8A)),
              ),
            ),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    const titles = ['Inicio', 'Consultas', 'Productos', 'Asistente'];
    final metrics = DashboardMetrics.fromLeads(_leads);

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
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.normal,
                  color: Color(0xFF6B7280),
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.paste_rounded, color: Color(0xFFDF7447)),
            onPressed: () => SmartClipboardSheet.show(context, products: _products),
            tooltip: 'Portapapeles Inteligente (Respuestas rápidas)',
          ),
          IconButton(
            icon: const Icon(Icons.mic, color: Color(0xFFDF7447)),
            onPressed: _openVoiceAgent,
            tooltip: 'Asistente por voz (Agente)',
          ),
          IconButton(
            icon: syncManager.isSyncing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.refresh),
            onPressed: syncManager.isSyncing ? null : _refresh,
            tooltip: 'Sincronizar',
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
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'logout', child: Text('Cerrar sesión')),
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
                      ElevatedButton(
                        onPressed: _refresh,
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    _buildSyncBanner(),
                    Expanded(
                      child: IndexedStack(
                        index: _currentIndex,
                        children: [
                          DashboardTab(
                            metrics: metrics,
                            onRefresh: _refresh,
                            onNewLeadTap: () => _openLeadForm(),
                            onLeadTap: (lead) => _openLeadForm(lead),
                          ),
                          LeadsTab(
                            leads: _leads,
                            onRefresh: _refresh,
                            onLeadTap: (lead) => _openLeadForm(lead),
                          ),
                          ProductsTab(
                            products: _products,
                            onRefresh: _refresh,
                            onProductTap: (product) => _openProductForm(product),
                          ),
                          ChatScreen(
                            products: _products.map((p) => p.toJson()).toList(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
      floatingActionButton: _currentIndex == 3
          ? null
          : FloatingActionButton.extended(
              onPressed: () {
                if (_currentIndex == 2) {
                  _openProductForm();
                } else {
                  _openLeadForm();
                }
              },
              icon: const Icon(Icons.add),
              label: Text(_currentIndex == 2 ? 'Nuevo producto' : 'Nueva consulta'),
              backgroundColor: const Color(0xFF172A3A),
              foregroundColor: Colors.white,
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Inicio',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'Consultas',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2),
            label: 'Productos',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_outlined),
            selectedIcon: Icon(Icons.chat),
            label: 'Asistente',
          ),
        ],
      ),
    );
  }
}
