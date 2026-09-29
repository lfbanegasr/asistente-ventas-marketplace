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

  String _formatFriendlyDateTime(DateTime dt) {
    const weekdays = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
    const months = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];
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

  String _toIsoDate(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
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
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: readyDateCtrl,
                        decoration: InputDecoration(
                          labelText: 'Fecha posible entrega (AAAA-MM-DD)',
                          hintText: '2026-09-30',
                          prefixIcon: const Icon(Icons.calendar_today_outlined, size: 20),
                          suffixIcon: readyDateCtrl.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () => setModalState(() => readyDateCtrl.clear()),
                                )
                              : null,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      icon: const Icon(Icons.calendar_month),
                      tooltip: 'Seleccionar fecha',
                      onPressed: () async {
                        DateTime initial = DateTime.now();
                        if (readyDateCtrl.text.isNotEmpty) {
                          try { initial = DateTime.parse(readyDateCtrl.text); } catch (_) {}
                        }
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: initial,
                          firstDate: DateTime.now().subtract(const Duration(days: 30)),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                          helpText: 'FECHA ESTIMADA DE ENTREGA',
                        );
                        if (picked != null) {
                          setModalState(() => readyDateCtrl.text = _toIsoDate(picked));
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ActionChip(
                        avatar: const Icon(Icons.today, size: 15),
                        label: const Text('Hoy', style: TextStyle(fontSize: 12)),
                        onPressed: () => setModalState(() => readyDateCtrl.text = _toIsoDate(DateTime.now())),
                      ),
                      const SizedBox(width: 6),
                      ActionChip(
                        avatar: const Icon(Icons.fast_forward, size: 15),
                        label: const Text('Mañana', style: TextStyle(fontSize: 12)),
                        onPressed: () => setModalState(() => readyDateCtrl.text = _toIsoDate(DateTime.now().add(const Duration(days: 1)))),
                      ),
                      const SizedBox(width: 6),
                      ActionChip(
                        label: const Text('En 3 días', style: TextStyle(fontSize: 12)),
                        onPressed: () => setModalState(() => readyDateCtrl.text = _toIsoDate(DateTime.now().add(const Duration(days: 3)))),
                      ),
                      const SizedBox(width: 6),
                      ActionChip(
                        label: const Text('En 1 semana', style: TextStyle(fontSize: 12)),
                        onPressed: () => setModalState(() => readyDateCtrl.text = _toIsoDate(DateTime.now().add(const Duration(days: 7)))),
                      ),
                    ],
                  ),
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

  // ── Lead CRUD Modal (Interactive & Fast) ──────────────
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
    
    DateTime? selectedDateTime;
    final rawDateStr = (lead?['delivery_at'] as String?)?.trim() ?? '';
    if (rawDateStr.isNotEmpty) {
      try {
        selectedDateTime = DateTime.parse(rawDateStr);
      } catch (_) {}
    }

    bool paid = isEdit ? (lead['paid'] == 1 || lead['paid'] == true) : false;
    final notesCtrl = TextEditingController(text: lead?['notes'] ?? '');
    bool saving = false;
    String? formError;

    final placeSuggestions = ['UAGRM', 'Cine Center', 'Ventura Mall', '2do Anillo', 'A domicilio', 'Punto medio'];

    final statusList = [
      {'key': 'consulta', 'label': 'Consulta', 'icon': Icons.chat_bubble_outline, 'color': const Color(0xFF4B5563), 'bg': const Color(0xFFF3F4F6)},
      {'key': 'interesado', 'label': 'Interesado', 'icon': Icons.visibility_outlined, 'color': const Color(0xFFB45309), 'bg': const Color(0xFFFEF3C7)},
      {'key': 'confirmado', 'label': 'Confirmado', 'icon': Icons.thumb_up_alt_outlined, 'color': const Color(0xFF0F766E), 'bg': const Color(0xFFCCFBF1)},
      {'key': 'agendado', 'label': 'Agendado', 'icon': Icons.calendar_month_outlined, 'color': const Color(0xFF1D4ED8), 'bg': const Color(0xFFDBEAFE)},
      {'key': 'comprado', 'label': 'Comprado', 'icon': Icons.attach_money, 'color': const Color(0xFF047857), 'bg': const Color(0xFFD1FAE5)},
      {'key': 'entregado', 'label': 'Entregado', 'icon': Icons.check_circle_outline, 'color': const Color(0xFF15803D), 'bg': const Color(0xFFDCFCE7)},
      {'key': 'cancelado', 'label': 'Cancelado', 'icon': Icons.cancel_outlined, 'color': const Color(0xFFB91C1C), 'bg': const Color(0xFFFEE2E2)},
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (ctx, setModalState) {
          // Date & Time Picker Helpers
          Future<void> pickInteractiveDateTime() async {
            final now = DateTime.now();
            final base = selectedDateTime ?? now;
            final pickedDate = await showDatePicker(
              context: ctx,
              initialDate: base,
              firstDate: now.subtract(const Duration(days: 90)),
              lastDate: now.add(const Duration(days: 365)),
              helpText: 'SELECCIONA EL DÍA DE ENTREGA / CITA',
              confirmText: 'SIGUIENTE: HORA',
              cancelText: 'CANCELAR',
            );
            if (pickedDate == null || !ctx.mounted) return;

            final pickedTime = await showTimePicker(
              context: ctx,
              initialTime: TimeOfDay(hour: base.hour, minute: base.minute),
              helpText: 'SELECCIONA LA HORA',
              confirmText: 'CONFIRMAR',
              cancelText: 'CANCELAR',
            );
            if (pickedTime == null) return;

            setModalState(() {
              selectedDateTime = DateTime(
                pickedDate.year,
                pickedDate.month,
                pickedDate.day,
                pickedTime.hour,
                pickedTime.minute,
              );
              if (status == 'consulta' || status == 'interesado') {
                status = 'agendado';
              }
            });
          }

          Future<void> pickOnlyDate() async {
            final now = DateTime.now();
            final base = selectedDateTime ?? now;
            final pickedDate = await showDatePicker(
              context: ctx,
              initialDate: base,
              firstDate: now.subtract(const Duration(days: 90)),
              lastDate: now.add(const Duration(days: 365)),
              helpText: 'CAMBIAR DÍA',
            );
            if (pickedDate != null) {
              setModalState(() {
                final currentH = selectedDateTime?.hour ?? 16;
                final currentM = selectedDateTime?.minute ?? 0;
                selectedDateTime = DateTime(
                  pickedDate.year,
                  pickedDate.month,
                  pickedDate.day,
                  currentH,
                  currentM,
                );
              });
            }
          }

          Future<void> pickOnlyTime() async {
            final base = selectedDateTime ?? DateTime.now();
            final pickedTime = await showTimePicker(
              context: ctx,
              initialTime: TimeOfDay(hour: base.hour, minute: base.minute),
              helpText: 'CAMBIAR HORA',
            );
            if (pickedTime != null) {
              setModalState(() {
                final d = selectedDateTime ?? DateTime.now();
                selectedDateTime = DateTime(
                  d.year,
                  d.month,
                  d.day,
                  pickedTime.hour,
                  pickedTime.minute,
                );
              });
            }
          }

          void applyPreset({int hoursOffset = 0, int? targetHour, int? targetMinute, int daysOffset = 0}) {
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
            setModalState(() {
              selectedDateTime = target;
              if (status == 'consulta' || status == 'interesado') {
                status = 'agendado';
              }
            });
          }

          // Live Margin Calculation
          final int amt = int.tryParse(amountCtrl.text.trim()) ?? 0;
          final int cst = int.tryParse(costCtrl.text.trim()) ?? 0;
          final int exp = int.tryParse(expensesCtrl.text.trim()) ?? 0;
          final int liveMargin = amt - cst - exp;

          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 14,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle bar
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD2D6DC),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),

                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isEdit ? 'Actualizar consulta' : 'Nueva consulta',
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            isEdit ? 'Edita estado, montos o fecha de entrega' : 'Registra un cliente interesado',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(sheetContext),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  if (formError != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFDE8E8),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFF8B4B4)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: Color(0xFFC81E1E), size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              formError!,
                              style: const TextStyle(color: Color(0xFF9B1C1C), fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Nombre o alias
                  TextField(
                    controller: aliasCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nombre o alias del cliente *',
                      hintText: 'Ej.: Juan Carlos o Cliente FB Yesido',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Canal de contacto
                  const Text('Canal de origen', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF4B5563))),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      for (final ch in [
                        {'key': 'Marketplace', 'label': 'Marketplace', 'icon': Icons.storefront_outlined},
                        {'key': 'WhatsApp', 'label': 'WhatsApp', 'icon': Icons.chat_bubble_outline},
                        {'key': 'Otro', 'label': 'Otro', 'icon': Icons.public_outlined},
                      ]) ...[
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 3),
                            child: ChoiceChip(
                              avatar: Icon(ch['icon'] as IconData, size: 16, color: channel == ch['key'] ? Colors.white : const Color(0xFF4B5563)),
                              label: Text(ch['label'] as String, style: const TextStyle(fontSize: 12)),
                              selected: channel == ch['key'],
                              selectedColor: const Color(0xFF172A3A),
                              labelStyle: TextStyle(
                                color: channel == ch['key'] ? Colors.white : const Color(0xFF374151),
                                fontWeight: channel == ch['key'] ? FontWeight.bold : FontWeight.normal,
                              ),
                              showCheckmark: false,
                              onSelected: (selected) {
                                if (selected) setModalState(() => channel = ch['key'] as String);
                              },
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Producto
                  DropdownButtonFormField<String>(
                    initialValue: _products.any((p) => p['id'] == productId) ? productId : _products[0]['id'],
                    decoration: const InputDecoration(
                      labelText: 'Producto consultado',
                      prefixIcon: Icon(Icons.inventory_2_outlined),
                    ),
                    isExpanded: true,
                    items: _products.map((p) => DropdownMenuItem(
                      value: p['id'] as String,
                      child: Text('${p['name']} · Bs ${p['price']}', overflow: TextOverflow.ellipsis),
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
                  const SizedBox(height: 14),

                  // Estado interactivo (Chips)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Estado de la consulta', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF4B5563))),
                      Text(
                        status.toUpperCase(),
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFFDF7447)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: statusList.map((st) {
                        final isSel = status == st['key'];
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
                                setModalState(() {
                                  status = st['key'] as String;
                                  if (status == 'agendado' && selectedDateTime == null) {
                                    applyPreset(hoursOffset: 2);
                                  }
                                });
                              }
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // ── SECCIÓN PRINCIPAL: FECHA Y HORA INTERACTIVA ───────
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: selectedDateTime != null ? const Color(0xFFF7FBF9) : const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: selectedDateTime != null ? const Color(0xFF3B9B7E) : const Color(0xFFE5E7EB),
                        width: selectedDateTime != null ? 1.5 : 1,
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
                                  color: selectedDateTime != null ? const Color(0xFF1B6A53) : const Color(0xFF6B7280),
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Fecha y hora de entrega / cita',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              ],
                            ),
                            if (selectedDateTime != null)
                              IconButton(
                                icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFFC81E1E)),
                                tooltip: 'Quitar fecha',
                                constraints: const BoxConstraints(),
                                padding: EdgeInsets.zero,
                                onPressed: () => setModalState(() => selectedDateTime = null),
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        if (selectedDateTime == null) ...[
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
                                label: const Text('Elegir fecha y hora', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                onPressed: pickInteractiveDateTime,
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
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF111827)),
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
                                  onPressed: pickOnlyDate,
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
                                  onPressed: pickOnlyTime,
                                ),
                              ),
                            ],
                          ),
                        ],

                        const SizedBox(height: 10),
                        const Text(
                          '⚡ Atajos rápidos de un toque:',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF4B5563)),
                        ),
                        const SizedBox(height: 6),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              ActionChip(
                                avatar: const Icon(Icons.flash_on, size: 14, color: Color(0xFFDF7447)),
                                label: const Text('Hoy +1h', style: TextStyle(fontSize: 11)),
                                onPressed: () => applyPreset(hoursOffset: 1),
                              ),
                              const SizedBox(width: 6),
                              ActionChip(
                                avatar: const Icon(Icons.flash_on, size: 14, color: Color(0xFFDF7447)),
                                label: const Text('Hoy +2h', style: TextStyle(fontSize: 11)),
                                onPressed: () => applyPreset(hoursOffset: 2),
                              ),
                              const SizedBox(width: 6),
                              ActionChip(
                                label: const Text('Hoy 16:00', style: TextStyle(fontSize: 11)),
                                onPressed: () => applyPreset(targetHour: 16, targetMinute: 0),
                              ),
                              const SizedBox(width: 6),
                              ActionChip(
                                label: const Text('Hoy 18:30', style: TextStyle(fontSize: 11)),
                                onPressed: () => applyPreset(targetHour: 18, targetMinute: 30),
                              ),
                              const SizedBox(width: 6),
                              ActionChip(
                                label: const Text('Mañana 10:00', style: TextStyle(fontSize: 11)),
                                onPressed: () => applyPreset(daysOffset: 1, targetHour: 10, targetMinute: 0),
                              ),
                              const SizedBox(width: 6),
                              ActionChip(
                                label: const Text('Mañana 15:30', style: TextStyle(fontSize: 11)),
                                onPressed: () => applyPreset(daysOffset: 1, targetHour: 15, targetMinute: 30),
                              ),
                              const SizedBox(width: 6),
                              ActionChip(
                                label: const Text('Mañana 18:00', style: TextStyle(fontSize: 11)),
                                onPressed: () => applyPreset(daysOffset: 1, targetHour: 18, targetMinute: 0),
                              ),
                              const SizedBox(width: 6),
                              ActionChip(
                                label: const Text('En 2 días 15:00', style: TextStyle(fontSize: 11)),
                                onPressed: () => applyPreset(daysOffset: 2, targetHour: 15, targetMinute: 0),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Modalidad de entrega (ChoiceChips)
                  const Text('Modalidad de entrega', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF4B5563))),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      for (final m in [
                        {'key': 'por_definir', 'label': 'Por definir', 'icon': Icons.help_outline},
                        {'key': 'persona', 'label': 'En persona', 'icon': Icons.handshake_outlined},
                        {'key': 'yango', 'label': 'Yango / Moto', 'icon': Icons.two_wheeler_outlined},
                      ]) ...[
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 3),
                            child: ChoiceChip(
                              avatar: Icon(m['icon'] as IconData, size: 16, color: deliveryMode == m['key'] ? Colors.white : const Color(0xFF4B5563)),
                              label: Text(m['label'] as String, style: const TextStyle(fontSize: 11)),
                              selected: deliveryMode == m['key'],
                              selectedColor: const Color(0xFF172A3A),
                              labelStyle: TextStyle(
                                color: deliveryMode == m['key'] ? Colors.white : const Color(0xFF374151),
                                fontWeight: deliveryMode == m['key'] ? FontWeight.bold : FontWeight.normal,
                              ),
                              showCheckmark: false,
                              onSelected: (selected) {
                                if (selected) setModalState(() => deliveryMode = m['key'] as String);
                              },
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Lugar / Barrio con Atajos rápidos
                  TextField(
                    controller: placeCtrl,
                    decoration: InputDecoration(
                      labelText: 'Lugar / Dirección acordada',
                      hintText: 'Ej.: Cine Center, UAGRM...',
                      prefixIcon: const Icon(Icons.place_outlined),
                      suffixIcon: placeCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () => setModalState(() => placeCtrl.clear()),
                            )
                          : null,
                    ),
                    onChanged: (_) => setModalState(() {}),
                  ),
                  const SizedBox(height: 6),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: placeSuggestions.map((place) => Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ActionChip(
                          avatar: const Icon(Icons.pin_drop_outlined, size: 14, color: Color(0xFF172A3A)),
                          label: Text(place, style: const TextStyle(fontSize: 11)),
                          onPressed: () => setModalState(() => placeCtrl.text = place),
                        ),
                      )).toList(),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Montos y Margen en vivo
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: amountCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Precio (Bs) *'),
                          onChanged: (_) => setModalState(() {}),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: costCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Costo (Bs) *'),
                          onChanged: (_) => setModalState(() {}),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: expensesCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Gastos (Bs)'),
                          onChanged: (_) => setModalState(() {}),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Live Margin Card
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: liveMargin >= 0 ? const Color(0xFFEDF8F4) : const Color(0xFFFDE8E8),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: liveMargin >= 0 ? const Color(0xFFB0DFCE) : const Color(0xFFF8B4B4),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              liveMargin >= 0 ? Icons.trending_up : Icons.trending_down,
                              size: 18,
                              color: liveMargin >= 0 ? const Color(0xFF1B6A53) : const Color(0xFFC81E1E),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Margen neto: Bs $liveMargin',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: liveMargin >= 0 ? const Color(0xFF1B6A53) : const Color(0xFFC81E1E),
                              ),
                            ),
                          ],
                        ),
                        TextButton(
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          onPressed: () {
                            final prod = _products.firstWhere((p) => p['id'] == productId, orElse: () => _products.first);
                            setModalState(() {
                              amountCtrl.text = '${prod['price']}';
                              costCtrl.text = '${prod['cost']}';
                              expensesCtrl.text = '0';
                            });
                          },
                          child: const Text('Restablecer base', style: TextStyle(fontSize: 11)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Pago verificado toggle
                  Container(
                    decoration: BoxDecoration(
                      color: paid ? const Color(0xFFEDF8F4) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: paid ? const Color(0xFF74C3A8) : const Color(0xFFE5E7EB)),
                    ),
                    child: SwitchListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                      value: paid,
                      activeThumbColor: const Color(0xFF1B6A53),
                      title: Text(
                        paid ? 'Pago cobrado y verificado ✓' : 'Pago pendiente por cobrar',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: paid ? const Color(0xFF1B6A53) : const Color(0xFF374151),
                        ),
                      ),
                      subtitle: const Text('Obligatorio para finalizar entrega', style: TextStyle(fontSize: 11)),
                      onChanged: (v) => setModalState(() => paid = v),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Notas
                  TextField(
                    controller: notesCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Nota rápida o acuerdos',
                      hintText: 'Qué falta confirmar o acuerdos especiales...',
                      prefixIcon: Icon(Icons.edit_note),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Acciones inferiores
                  Row(
                    children: [
                      if (isEdit)
                        IconButton.outlined(
                          icon: const Icon(Icons.delete_outline, color: Color(0xFFC81E1E)),
                          tooltip: 'Eliminar consulta',
                          onPressed: saving ? null : () async {
                            final confirm = await showDialog<bool>(
                              context: ctx,
                              builder: (dCtx) => AlertDialog(
                                title: const Text('¿Eliminar consulta?'),
                                content: const Text('Esta consulta se eliminará definitivamente de la lista.'),
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
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF172A3A),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: saving ? null : () async {
                          final alias = aliasCtrl.text.trim();
                          final amount = int.tryParse(amountCtrl.text.trim());
                          final cost = int.tryParse(costCtrl.text.trim());
                          final expenses = int.tryParse(expensesCtrl.text.trim()) ?? 0;
                          final place = placeCtrl.text.trim();
                          final at = selectedDateTime != null ? _toIsoDateTime(selectedDateTime!) : '';

                          if (alias.isEmpty) {
                            setModalState(() => formError = 'Escribe un nombre o alias para el cliente.');
                            return;
                          }
                          if (amount == null || amount < 0 || cost == null || cost < 0 || expenses < 0) {
                            setModalState(() => formError = 'Revisa los montos ingresados (no pueden ser vacíos o negativos).');
                            return;
                          }
                          if (['agendado', 'entregado'].contains(status)) {
                            if (deliveryMode == 'por_definir' || at.isEmpty || place.isEmpty) {
                              setModalState(() => formError = 'Para agendar o entregar, indica modalidad, lugar y fecha/hora.');
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
                              _showMessage(isEdit ? 'Consulta actualizada con éxito.' : 'Consulta registrada con éxito.', success: true);
                            }
                          } catch (e) {
                            setModalState(() {
                              formError = e.toString();
                              saving = false;
                            });
                          }
                        },
                        child: Text(
                          saving ? 'Guardando…' : (isEdit ? 'Actualizar consulta' : 'Guardar consulta'),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
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

  // ── Minimalist & Comfortable Voice Assistant Modal ────────────────
  void _openVoiceAgentModal() {
    final cmdCtrl = TextEditingController();
    bool busy = false;
    bool listening = false;
    Map<String, dynamic>? lastResult;
    String? errorText;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
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

          Widget buildPill(String title, String prompt) {
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ActionChip(
                elevation: 0,
                backgroundColor: const Color(0xFFF3F5F2),
                side: const BorderSide(color: Color(0xFFE2E7E2)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                label: Text(
                  title,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF2C3E47)),
                ),
                onPressed: (busy || listening)
                    ? null
                    : () {
                        cmdCtrl.text = prompt;
                        submitCommand(prompt);
                      },
              ),
            );
          }

          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 12,
              bottom: bottomInset + 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Subtle drag handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // Minimal Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Asistente Inteligente',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF172A3A)),
                          ),
                          Text(
                            'Voz y acciones rápidas en Santa Cruz',
                            style: TextStyle(fontSize: 12, color: Color(0xFF75858A)),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20, color: Color(0xFF75858A)),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Hero Voice Orb
                  Center(
                    child: Column(
                      children: [
                        GestureDetector(
                          onTap: (busy || listening) ? null : startListening,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            width: 74,
                            height: 74,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: listening
                                    ? [const Color(0xFFDF7447), const Color(0xFFE88A64)]
                                    : [const Color(0xFF172A3A), const Color(0xFF2C4456)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: (listening ? const Color(0xFFDF7447) : const Color(0xFF172A3A)).withValues(alpha: 0.3),
                                  blurRadius: listening ? 18 : 10,
                                  spreadRadius: listening ? 3 : 1,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Icon(
                              listening ? Icons.graphic_eq : Icons.mic,
                              color: Colors.white,
                              size: 32,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          listening
                              ? 'Escuchando tu voz…'
                              : (busy ? 'Procesando tu orden…' : 'Toca el micrófono para hablar'),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: listening ? const Color(0xFFDF7447) : const Color(0xFF55656B),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Minimal Pill Input Bar
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF4F6F4),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: const Color(0xFFE0E5E0)),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: cmdCtrl,
                            decoration: const InputDecoration(
                              hintText: 'O escribe tu orden aquí...',
                              hintStyle: TextStyle(fontSize: 13, color: Color(0xFF8B989D)),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              fillColor: Colors.transparent,
                              contentPadding: EdgeInsets.symmetric(vertical: 10),
                            ),
                            onSubmitted: (busy || listening) ? null : (v) => submitCommand(v),
                          ),
                        ),
                        InkWell(
                          onTap: (busy || listening) ? null : () => submitCommand(cmdCtrl.text),
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.all(9),
                            decoration: const BoxDecoration(
                              color: Color(0xFFDF7447),
                              shape: BoxShape.circle,
                            ),
                            child: busy
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Icon(Icons.arrow_upward, size: 17, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Quick Suggestion Chips (Horizontal Minimal Scroll)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        buildPill('📦 Agendar Yango', 'Agendá para Juan Carlos del PB225 este viernes 4pm vía Yango'),
                        buildPill('🏷️ Subir precio', 'Subile 10 pesos al PB225 y anotá 4 unidades en mano'),
                        buildPill('📊 Balance de hoy', '¿Cuánto margen cobrado y ventas llevamos hoy?'),
                        buildPill('💬 Redactar', 'Redactale al cliente del PB225 que pide rebaja'),
                      ],
                    ),
                  ),

                  // Error Box
                  if (errorText != null) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF2EC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFF3CBB9)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.info_outline, color: Color(0xFFC04724), size: 18),
                              SizedBox(width: 8),
                              Text('Aviso del Asistente', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF8F351F))),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(errorText!, style: const TextStyle(color: Color(0xFF8F351F), fontSize: 13, height: 1.3)),
                        ],
                      ),
                    ),
                  ],

                  // Response Bubble (Clean, Modern Chat Style)
                  if (lastResult != null) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7FAF8),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFFDEE5E0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Row(
                                children: [
                                  Text('✦', style: TextStyle(color: Color(0xFFDF7447), fontSize: 16)),
                                  SizedBox(width: 6),
                                  Text('Respuesta', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF53646B))),
                                ],
                              ),
                              if (lastResult!['state_updated'] == true)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE2EFE7),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Text('✓ BD Actualizada', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF2C7569))),
                                ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            lastResult!['reply'] ?? '',
                            style: const TextStyle(fontSize: 15, height: 1.45, color: Color(0xFF172A3A), fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton.icon(
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  foregroundColor: const Color(0xFF172A3A),
                                ),
                                icon: const Icon(Icons.copy, size: 14),
                                label: const Text('Copiar', style: TextStyle(fontSize: 12)),
                                onPressed: () {
                                  Clipboard.setData(ClipboardData(text: lastResult!['reply'] ?? ''));
                                  _showMessage('Copiado al portapapeles', success: true);
                                },
                              ),
                            ],
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
