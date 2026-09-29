import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  // ── Product CRUD Modal ────────────────────────────────
  void _openProductForm([Map<String, dynamic>? product]) {
    final isEdit = product != null;
    final nameCtrl = TextEditingController(text: product?['name'] ?? '');
    final factsCtrl = TextEditingController(text: product?['facts'] ?? '');
    final costCtrl = TextEditingController(text: isEdit ? '${product['cost']}' : '');
    final priceCtrl = TextEditingController(text: isEdit ? '${product['price']}' : '');
    final minPriceCtrl = TextEditingController(text: isEdit ? '${product['min_price']}' : '');
    final unitsCtrl = TextEditingController(text: isEdit ? '${product['available_units']}' : '0');
    final readyDateCtrl = TextEditingController(text: product?['ready_date'] ?? '');
    String availability = product?['availability'] ?? 'por_confirmar';
    bool checked = false;
    bool saving = false;
    String? formError;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isEdit ? 'Editar producto' : 'Nuevo producto',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(sheetContext),
                    ),
                  ],
                ),
                if (formError != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: const Color(0xFFFDE8E8), borderRadius: BorderRadius.circular(8)),
                    child: Text(formError!, style: const TextStyle(color: Color(0xFFC81E1E), fontSize: 13)),
                  ),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Nombre *', hintText: 'Ej.: Yesido PB6010'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: factsCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Datos comprobados', hintText: 'Solo lo que puedas afirmar al cliente'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: costCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Costo (Bs) *'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: priceCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Precio publicado (Bs) *'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: minPriceCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Precio mín. interno *'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: unitsCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Unidades en mano *'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: availability,
                  decoration: const InputDecoration(labelText: 'Disponibilidad'),
                  items: const [
                    DropdownMenuItem(value: 'por_confirmar', child: Text('Por confirmar')),
                    DropdownMenuItem(value: 'proveedor_confirmado', child: Text('Proveedor confirmó')),
                    DropdownMenuItem(value: 'en_mano', child: Text('En mano')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setModalState(() {
                        availability = val;
                        if (val == 'en_mano') {
                          if ((int.tryParse(unitsCtrl.text) ?? 0) <= 0) unitsCtrl.text = '1';
                        } else {
                          unitsCtrl.text = '0';
                        }
                      });
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: readyDateCtrl,
                  decoration: const InputDecoration(labelText: 'Fecha posible entrega (AAAA-MM-DD)', hintText: '2026-09-30'),
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: checked,
                  title: const Text('Verifiqué esta disponibilidad ahora', style: TextStyle(fontSize: 13)),
                  onChanged: (v) => setModalState(() => checked = v ?? false),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    if (isEdit)
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Color(0xFFC81E1E)),
                        tooltip: 'Eliminar producto',
                        onPressed: saving ? null : () async {
                          final confirm = await showDialog<bool>(
                            context: ctx,
                            builder: (dCtx) => AlertDialog(
                              title: const Text('¿Eliminar producto?'),
                              content: const Text('Se eliminarán también las consultas y chats vinculados a este producto.'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('Cancelar')),
                                TextButton(
                                  onPressed: () => Navigator.pop(dCtx, true),
                                  child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            setModalState(() => saving = true);
                            try {
                              await apiClient.deleteProduct(product['id']);
                              if (sheetContext.mounted) {
                                Navigator.pop(sheetContext);
                                _refresh();
                                _showMessage('Producto eliminado.', success: true);
                              }
                            } catch (e) {
                              setModalState(() {
                                formError = e.toString();
                                saving = false;
                              });
                            }
                          }
                        },
                      ),
                    const Spacer(),
                    TextButton(
                      onPressed: saving ? null : () => Navigator.pop(sheetContext),
                      child: const Text('Cancelar'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF172A3A), foregroundColor: Colors.white),
                      onPressed: saving ? null : () async {
                        final name = nameCtrl.text.trim();
                        final cost = int.tryParse(costCtrl.text.trim());
                        final price = int.tryParse(priceCtrl.text.trim());
                        final minPrice = int.tryParse(minPriceCtrl.text.trim());
                        final units = int.tryParse(unitsCtrl.text.trim());

                        if (name.isEmpty) {
                          setModalState(() => formError = 'El nombre es obligatorio.');
                          return;
                        }
                        if (cost == null || cost < 0 || price == null || price < 0 || minPrice == null || minPrice < 0 || units == null || units < 0) {
                          setModalState(() => formError = 'Ingresa valores numéricos válidos.');
                          return;
                        }
                        if (minPrice > price) {
                          setModalState(() => formError = 'El precio mínimo no puede superar el precio publicado.');
                          return;
                        }
                        if (availability == 'en_mano' && units < 1) {
                          setModalState(() => formError = 'Si está en mano, indica al menos 1 unidad.');
                          return;
                        }
                        if (availability != 'en_mano' && units != 0) {
                          setModalState(() => formError = 'Unidades en mano debe ser 0 si no lo tienes físicamente.');
                          return;
                        }

                        setModalState(() {
                          saving = true;
                          formError = null;
                        });

                        try {
                          final data = {
                            'name': name,
                            'facts': factsCtrl.text.trim(),
                            'cost': cost,
                            'price': price,
                            'min_price': minPrice,
                            'availability': availability,
                            'available_units': units,
                            'ready_date': readyDateCtrl.text.trim(),
                            'availability_checked': checked,
                          };
                          await apiClient.saveProduct(data, id: isEdit ? product['id'] : null);
                          if (sheetContext.mounted) {
                            Navigator.pop(sheetContext);
                            _refresh();
                            _showMessage(isEdit ? 'Producto actualizado.' : 'Producto creado.', success: true);
                          }
                        } catch (e) {
                          setModalState(() {
                            formError = e.toString();
                            saving = false;
                          });
                        }
                      },
                      child: Text(saving ? 'Guardando…' : 'Guardar'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Lead CRUD Modal ───────────────────────────────────
  void _openLeadForm([Map<String, dynamic>? lead]) {
    if (lead == null && _products.isEmpty) {
      _showMessage('Primero crea un producto en la pestaña "Productos" antes de registrar consultas.');
      return;
    }
    final isEdit = lead != null;
    final aliasCtrl = TextEditingController(text: lead?['alias'] ?? '');
    String channel = lead?['channel'] ?? 'Marketplace';
    String productId = lead?['product_id'] ?? _products[0]['id'];
    String status = lead?['status'] ?? 'consulta';
    
    final selectedProduct = _products.firstWhere((p) => p['id'] == productId, orElse: () => _products.first);
    final amountCtrl = TextEditingController(text: isEdit ? '${lead['amount']}' : '${selectedProduct['price']}');
    final costCtrl = TextEditingController(text: isEdit ? '${lead['actual_cost']}' : '${selectedProduct['cost']}');
    final expensesCtrl = TextEditingController(text: isEdit ? '${lead['expenses']}' : '0');
    String deliveryMode = lead?['delivery_mode'] ?? 'por_definir';
    final placeCtrl = TextEditingController(text: lead?['delivery_place'] ?? '');
    final dateCtrl = TextEditingController(text: lead?['delivery_at'] ?? '');
    bool paid = isEdit ? (lead['paid'] == 1 || lead['paid'] == true) : false;
    final notesCtrl = TextEditingController(text: lead?['notes'] ?? '');
    bool saving = false;
    String? formError;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isEdit ? 'Actualizar consulta' : 'Nueva consulta',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(sheetContext),
                    ),
                  ],
                ),
                if (formError != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: const Color(0xFFFDE8E8), borderRadius: BorderRadius.circular(8)),
                    child: Text(formError!, style: const TextStyle(color: Color(0xFFC81E1E), fontSize: 13)),
                  ),
                TextField(
                  controller: aliasCtrl,
                  decoration: const InputDecoration(labelText: 'Nombre o alias *', hintText: 'Ej.: Cliente PB6010'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: channel,
                        decoration: const InputDecoration(labelText: 'Canal'),
                        items: const [
                          DropdownMenuItem(value: 'Marketplace', child: Text('Marketplace')),
                          DropdownMenuItem(value: 'WhatsApp', child: Text('WhatsApp')),
                          DropdownMenuItem(value: 'Otro', child: Text('Otro')),
                        ],
                        onChanged: (v) { if (v != null) setModalState(() => channel = v); },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _products.any((p) => p['id'] == productId) ? productId : _products[0]['id'],
                        decoration: const InputDecoration(labelText: 'Producto'),
                        isExpanded: true,
                        items: _products.map((p) => DropdownMenuItem(
                          value: p['id'] as String,
                          child: Text(p['name'] as String, overflow: TextOverflow.ellipsis),
                        )).toList(),
                        onChanged: (v) {
                          if (v != null) {
                            setModalState(() {
                              productId = v;
                              if (!isEdit) {
                                final prod = _products.firstWhere((p) => p['id'] == v);
                                amountCtrl.text = '${prod['price']}';
                                costCtrl.text = '${prod['cost']}';
                              }
                            });
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: status,
                  decoration: const InputDecoration(labelText: 'Estado'),
                  items: const [
                    DropdownMenuItem(value: 'consulta', child: Text('Consulta')),
                    DropdownMenuItem(value: 'interesado', child: Text('Interesado')),
                    DropdownMenuItem(value: 'confirmado', child: Text('Confirmado')),
                    DropdownMenuItem(value: 'comprado', child: Text('Comprado')),
                    DropdownMenuItem(value: 'agendado', child: Text('Agendado')),
                    DropdownMenuItem(value: 'entregado', child: Text('Entregado')),
                    DropdownMenuItem(value: 'cancelado', child: Text('Cancelado')),
                  ],
                  onChanged: (v) { if (v != null) setModalState(() => status = v); },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: amountCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Precio acordado (Bs) *'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: costCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Costo real (Bs) *'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: expensesCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Otros gastos *'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: deliveryMode,
                        decoration: const InputDecoration(labelText: 'Modalidad'),
                        items: const [
                          DropdownMenuItem(value: 'por_definir', child: Text('Por definir')),
                          DropdownMenuItem(value: 'persona', child: Text('En persona')),
                          DropdownMenuItem(value: 'yango', child: Text('Yango')),
                        ],
                        onChanged: (v) { if (v != null) setModalState(() => deliveryMode = v); },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: placeCtrl,
                        decoration: const InputDecoration(labelText: 'Lugar / barrio', hintText: 'UAGRM, Cine Center...'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: dateCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Fecha y hora (AAAA-MM-DDTHH:MM)',
                    hintText: '2026-09-30T15:30',
                  ),
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: paid,
                  title: const Text('Pago del producto verificado', style: TextStyle(fontSize: 13)),
                  onChanged: (v) => setModalState(() => paid = v ?? false),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: notesCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Nota breve', hintText: 'Qué falta confirmar'),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    if (isEdit)
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Color(0xFFC81E1E)),
                        tooltip: 'Eliminar consulta',
                        onPressed: saving ? null : () async {
                          final confirm = await showDialog<bool>(
                            context: ctx,
                            builder: (dCtx) => AlertDialog(
                              title: const Text('¿Eliminar consulta?'),
                              content: const Text('Esta consulta se eliminará definitivamente.'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('Cancelar')),
                                TextButton(
                                  onPressed: () => Navigator.pop(dCtx, true),
                                  child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            setModalState(() => saving = true);
                            try {
                              await apiClient.deleteLead(lead['id']);
                              if (sheetContext.mounted) {
                                Navigator.pop(sheetContext);
                                _refresh();
                                _showMessage('Consulta eliminada.', success: true);
                              }
                            } catch (e) {
                              setModalState(() {
                                formError = e.toString();
                                saving = false;
                              });
                            }
                          }
                        },
                      ),
                    const Spacer(),
                    TextButton(
                      onPressed: saving ? null : () => Navigator.pop(sheetContext),
                      child: const Text('Cancelar'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF172A3A), foregroundColor: Colors.white),
                      onPressed: saving ? null : () async {
                        final alias = aliasCtrl.text.trim();
                        final amount = int.tryParse(amountCtrl.text.trim());
                        final cost = int.tryParse(costCtrl.text.trim());
                        final expenses = int.tryParse(expensesCtrl.text.trim()) ?? 0;
                        final place = placeCtrl.text.trim();
                        final at = dateCtrl.text.trim();

                        if (alias.isEmpty) {
                          setModalState(() => formError = 'Escribe un nombre o alias.');
                          return;
                        }
                        if (amount == null || amount < 0 || cost == null || cost < 0 || expenses < 0) {
                          setModalState(() => formError = 'Revisa los montos ingresados.');
                          return;
                        }
                        if (['agendado', 'entregado'].contains(status)) {
                          if (deliveryMode == 'por_definir' || at.isEmpty || place.isEmpty) {
                            setModalState(() => formError = 'Para agendar o entregar, indica modalidad, lugar y fecha.');
                            return;
                          }
                        }
                        if (status == 'entregado' && !paid) {
                          setModalState(() => formError = 'Marca el pago como verificado antes de finalizar entrega.');
                          return;
                        }

                        setModalState(() {
                          saving = true;
                          formError = null;
                        });

                        try {
                          final data = {
                            'alias': alias,
                            'channel': channel,
                            'product_id': productId,
                            'status': status,
                            'amount': amount,
                            'actual_cost': cost,
                            'expenses': expenses,
                            'delivery_mode': deliveryMode,
                            'delivery_place': place,
                            'delivery_at': at,
                            'paid': paid,
                            'notes': notesCtrl.text.trim(),
                          };
                          if (isEdit) {
                            await apiClient.updateLead(lead['id'], data);
                          } else {
                            await apiClient.createLead(data);
                          }
                          if (sheetContext.mounted) {
                            Navigator.pop(sheetContext);
                            _refresh();
                            _showMessage(isEdit ? 'Consulta actualizada.' : 'Consulta registrada.', success: true);
                          }
                        } catch (e) {
                          setModalState(() {
                            formError = e.toString();
                            saving = false;
                          });
                        }
                      },
                      child: Text(saving ? 'Guardando…' : 'Guardar'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
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
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
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
                const Text('TU DÍA, CLARO', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 2, color: Color(0xFFD46E3D))),
                const SizedBox(height: 8),
                const Text('Responde, confirma\ny entrega.', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -1.2)),
                const SizedBox(height: 8),
                const Text('Registra solo las consultas que necesitan seguimiento.', style: TextStyle(color: Color(0xFFC5D1D4), fontSize: 14)),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD46E3D),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => _openLeadForm(),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('+ Nueva consulta', style: TextStyle(fontWeight: FontWeight.bold)),
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
            ...scheduled.take(5).map((l) => InkWell(
              onTap: () => _openLeadForm(l),
              borderRadius: BorderRadius.circular(12),
              child: _infoRow(
                l['alias'] as String,
                '${l['product_name']} · ${_localDate(l['delivery_at'] as String?)} · ${(l['delivery_place'] as String?) ?? 'lugar pendiente'}',
              ),
            )),
        ],
      ),
    );
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
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.8),
              ),
            ),
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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(color: Color(0xFF6D7B7F), fontSize: 12)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
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
                ? const Center(child: Text('No hay consultas con ese filtro.', style: TextStyle(color: Colors.grey)))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: filtered.length,
                    itemBuilder: (ctx, i) {
                      final l = filtered[i];
                      final status = l['status'] as String;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: InkWell(
                          onTap: () => _openLeadForm(l),
                          borderRadius: BorderRadius.circular(12),
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
                                    Row(
                                      children: [
                                        _badge(labels[status] ?? status, status),
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
                                    Text('Venta ${_money(l['amount'])}', style: const TextStyle(fontSize: 13, color: Color(0xFF617177))),
                                    Text('Margen ${_money((l['amount'] as int) - (l['actual_cost'] as int) - (l['expenses'] as int))}', style: const TextStyle(fontSize: 13, color: Color(0xFF617177))),
                                    Text(l['paid'] == 1 ? 'Pago ✓' : 'Pago pendiente', style: const TextStyle(fontSize: 13, color: Color(0xFF617177))),
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
      child: _products.isEmpty
          ? const Center(child: Text('No hay productos creados. Toca "+" para agregar uno.', style: TextStyle(color: Colors.grey)))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _products.length,
              itemBuilder: (ctx, i) {
                final p = _products[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: InkWell(
                    onTap: () => _openProductForm(p),
                    borderRadius: BorderRadius.circular(12),
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
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(_money(p['price']), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.6)),
                                  const Icon(Icons.edit_outlined, size: 16, color: Colors.grey),
                                ],
                              ),
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

  static const _speechChannel = MethodChannel('com.lfbanegasr.mesa_ventas_mobile/speech');

  // ── Voice & Two-Layer Agent Modal ─────────────────────
  void _openVoiceAgentModal() {
    final cmdCtrl = TextEditingController();
    bool busy = false;
    bool listening = false;
    Map<String, dynamic>? lastResult;
    String? errorText;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final bottomInset = MediaQuery.of(context).viewInsets.bottom;

          Future<void> submitCommand(String command) async {
            final trimmed = command.trim();
            if (trimmed.isEmpty) return;

            setModalState(() {
              busy = true;
              errorText = null;
              lastResult = null;
            });

            try {
              final response = await apiClient.sendAgentCommand(trimmed);
              setModalState(() {
                busy = false;
                lastResult = response;
              });

              if (response['state_updated'] == true) {
                _refresh();
              }
            } catch (e) {
              setModalState(() {
                busy = false;
                errorText = e.toString();
              });
            }
          }

          Future<void> startListening() async {
            setModalState(() {
              listening = true;
              errorText = null;
            });
            try {
              final text = await _speechChannel.invokeMethod<String>('startListening');
              setModalState(() => listening = false);
              if (text != null && text.trim().isNotEmpty) {
                cmdCtrl.text = text.trim();
                await submitCommand(text.trim());
              }
            } catch (err) {
              setModalState(() {
                listening = false;
                errorText = 'No se pudo activar el micrófono: $err';
              });
            }
          }

          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: bottomInset + 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF172A3A),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.mic, color: Color(0xFFFFB887), size: 24),
                          ),
                          const SizedBox(width: 12),
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Asistente por Voz',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                'Procesamiento en 2 Capas (Santa Cruz)',
                                style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                              ),
                            ],
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Native Android voice dictation trigger
                  InkWell(
                    onTap: (busy || listening) ? null : startListening,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                      decoration: BoxDecoration(
                        color: listening ? const Color(0xFFDF7447) : const Color(0xFF172A3A),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            listening ? Icons.graphic_eq : Icons.mic,
                            color: Colors.white,
                            size: 24,
                          ),
                          const SizedBox(width: 10),
                          Flexible(
                            child: Text(
                              listening
                                  ? 'Escuchando tu voz…'
                                  : '🎙️ Toca para hablar (Dictado por Voz)',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),
                  TextField(
                    controller: cmdCtrl,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: 'O escribe aquí tu orden (ej: Agendá a Juan Carlos del PB225 vía Yango...)',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFFDF7447), width: 2),
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF9FAFB),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      ActionChip(
                        avatar: const Text('📦'),
                        label: const Text('Agendar PB225 Yango'),
                        onPressed: () {
                          cmdCtrl.text = 'Agendá consulta para Juan Carlos del PB225 para este viernes a las 4 de la tarde vía Yango en el 4to anillo radial 19';
                          submitCommand(cmdCtrl.text);
                        },
                      ),
                      ActionChip(
                        avatar: const Text('🏷️'),
                        label: const Text('Subir precio PB225'),
                        onPressed: () {
                          cmdCtrl.text = 'Subile 10 pesos al PB225 y anotá 4 unidades en mano';
                          submitCommand(cmdCtrl.text);
                        },
                      ),
                      ActionChip(
                        avatar: const Text('📊'),
                        label: const Text('Margen de hoy'),
                        onPressed: () {
                          cmdCtrl.text = '¿Cuánto margen cobrado y ventas llevamos hoy en Santa Cruz?';
                          submitCommand(cmdCtrl.text);
                        },
                      ),
                      ActionChip(
                        avatar: const Text('💬'),
                        label: const Text('Redactar respuesta'),
                        onPressed: () {
                          cmdCtrl.text = 'Redactale respuesta al cliente del PB225 que pide rebaja y pregunta por envío';
                          submitCommand(cmdCtrl.text);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  ElevatedButton.icon(
                    onPressed: (busy || listening) ? null : () => submitCommand(cmdCtrl.text),
                    icon: busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
                    label: Text(busy ? 'Procesando en dos capas…' : 'Ejecutar comando'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFDF7447),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                  if (errorText != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF0E9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFF2C9B8)),
                      ),
                      child: Text(
                        '⚠️ $errorText',
                        style: const TextStyle(color: Color(0xFF8F351F), fontSize: 13),
                      ),
                    ),
                  ],
                  if (lastResult != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAF8),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFDBE3DB)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (lastResult!['interpretation'] != null) ...[
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEDF4F0),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '🧠 Capa 1: ${(lastResult!['interpretation']['ambito'] ?? 'general').toString().toUpperCase()}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF2C7569),
                                    ),
                                  ),
                                ),
                                if (lastResult!['state_updated'] == true) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEEF0F5),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      'BD Actualizada',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF65718A),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Intención: ${lastResult!['interpretation']['intencion'] ?? ''}',
                              style: const TextStyle(fontSize: 12, color: Color(0xFF55676E)),
                            ),
                            const Divider(height: 16),
                          ],
                          Text(
                            lastResult!['reply'] ?? '',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF172A3A)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
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
            icon: const Icon(Icons.mic, color: Color(0xFFDF7447)),
            onPressed: _openVoiceAgentModal,
            tooltip: 'Asistente por voz (Agente)',
          ),
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
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Inicio'),
          NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: 'Consultas'),
          NavigationDestination(icon: Icon(Icons.inventory_2_outlined), selectedIcon: Icon(Icons.inventory_2), label: 'Productos'),
          NavigationDestination(icon: Icon(Icons.chat_outlined), selectedIcon: Icon(Icons.chat), label: 'Asistente'),
        ],
      ),
    );
  }
}
