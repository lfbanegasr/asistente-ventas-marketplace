import 'package:flutter/material.dart';
import '../models/lead.dart';
import '../models/product.dart';
import '../widgets/status_selector_chips.dart';
import '../widgets/interactive_date_time_picker.dart';
import '../widgets/margin_calculator_card.dart';
import 'receipt_modal.dart';
import '../main.dart';

class LeadFormSheet extends StatefulWidget {
  const LeadFormSheet({
    super.key,
    this.lead,
    required this.products,
    required this.onSaved,
    this.onDeleted,
  });

  final Lead? lead;
  final List<Product> products;
  final Future<void> Function() onSaved;
  final Future<void> Function()? onDeleted;

  static Future<void> show(
    BuildContext context, {
    Lead? lead,
    required List<Product> products,
    required Future<void> Function() onSaved,
    Future<void> Function()? onDeleted,
  }) {
    if (lead == null && products.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Primero crea un producto en la pestaña "Productos" antes de registrar consultas.'),
        ),
      );
      return Future.value();
    }

    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => LeadFormSheet(
        lead: lead,
        products: products,
        onSaved: onSaved,
        onDeleted: onDeleted,
      ),
    );
  }

  @override
  State<LeadFormSheet> createState() => _LeadFormSheetState();
}

class _LeadFormSheetState extends State<LeadFormSheet> {
  late final bool _isEdit;
  late final TextEditingController _aliasCtrl;
  late String _channel;
  late String _productId;
  late String _status;
  late final TextEditingController _amountCtrl;
  late final TextEditingController _costCtrl;
  late final TextEditingController _expensesCtrl;
  late String _deliveryMode;
  late final TextEditingController _placeCtrl;
  DateTime? _selectedDateTime;
  late bool _paid;
  late final TextEditingController _notesCtrl;
  bool _saving = false;
  String? _formError;

  static const _placeSuggestions = [
    'UAGRM',
    'Cine Center',
    'Ventura Mall',
    '2do Anillo',
    'A domicilio',
    'Punto medio',
  ];

  @override
  void initState() {
    super.initState();
    final l = widget.lead;
    _isEdit = l != null;
    _aliasCtrl = TextEditingController(text: l?.alias ?? '');
    _channel = l?.channel ?? 'Marketplace';

    final initialProdId = l?.productId ?? (widget.products.isNotEmpty ? widget.products.first.id : '');
    final prodExists = widget.products.any((p) => p.id == initialProdId);
    _productId = prodExists ? initialProdId : (widget.products.isNotEmpty ? widget.products.first.id : '');

    _status = l?.status ?? 'consulta';

    final selectedProduct = widget.products.firstWhere(
      (p) => p.id == _productId,
      orElse: () => widget.products.first,
    );

    _amountCtrl = TextEditingController(
      text: l != null ? '${l.amount}' : '${selectedProduct.price}',
    );
    _costCtrl = TextEditingController(
      text: l != null ? '${l.actualCost}' : '${selectedProduct.cost}',
    );
    _expensesCtrl = TextEditingController(
      text: l != null ? '${l.expenses}' : '0',
    );
    _deliveryMode = l?.deliveryMode ?? 'por_definir';
    _placeCtrl = TextEditingController(text: l?.deliveryPlace ?? '');

    if (l != null && l.deliveryAt.trim().isNotEmpty) {
      try {
        _selectedDateTime = DateTime.parse(l.deliveryAt.trim());
      } catch (_) {}
    }

    _paid = l?.paid ?? false;
    _notesCtrl = TextEditingController(text: l?.notes ?? '');
  }

  @override
  void dispose() {
    _aliasCtrl.dispose();
    _amountCtrl.dispose();
    _costCtrl.dispose();
    _expensesCtrl.dispose();
    _placeCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  String _toIsoDateTime(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$y-$m-${d}T$h:$min';
  }

  Future<void> _handleDelete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: const Text('¿Eliminar consulta?'),
        content: const Text('Esta consulta se eliminará definitivamente de la lista.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dCtx, true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      setState(() => _saving = true);
      try {
        await syncManager.deleteLead(widget.lead!.id);
        if (mounted) {
          Navigator.pop(context);
          if (widget.onDeleted != null) {
            await widget.onDeleted!();
          } else {
            await widget.onSaved();
          }
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _formError = e.toString();
            _saving = false;
          });
        }
      }
    }
  }

  Future<void> _handleSave() async {
    final alias = _aliasCtrl.text.trim();
    final amount = int.tryParse(_amountCtrl.text.trim());
    final cost = int.tryParse(_costCtrl.text.trim());
    final expenses = int.tryParse(_expensesCtrl.text.trim()) ?? 0;
    final place = _placeCtrl.text.trim();
    final at = _selectedDateTime != null ? _toIsoDateTime(_selectedDateTime!) : '';

    if (alias.isEmpty) {
      setState(() => _formError = 'Escribe un nombre o alias para el cliente.');
      return;
    }
    if (amount == null || amount < 0 || cost == null || cost < 0 || expenses < 0) {
      setState(() => _formError = 'Revisa los montos ingresados (no pueden ser vacíos o negativos).');
      return;
    }
    if (['agendado', 'entregado'].contains(_status)) {
      if (_deliveryMode == 'por_definir' || at.isEmpty || place.isEmpty) {
        setState(() => _formError = 'Para agendar o entregar, indica modalidad, lugar y fecha/hora.');
        return;
      }
    }
    if (_status == 'entregado' && !_paid) {
      setState(() => _formError = 'Marca el pago como verificado antes de finalizar entrega.');
      return;
    }

    setState(() {
      _saving = true;
      _formError = null;
    });

    try {
      final data = {
        'alias': alias,
        'channel': _channel,
        'product_id': _productId,
        'status': _status,
        'amount': amount,
        'actual_cost': cost,
        'expenses': expenses,
        'delivery_mode': _deliveryMode,
        'delivery_place': place,
        'delivery_at': at,
        'paid': _paid,
        'notes': _notesCtrl.text.trim(),
      };

      if (_isEdit) {
        await syncManager.updateLead(widget.lead!.id, data);
      } else {
        await syncManager.createLead(data);
      }

      if (mounted) {
        Navigator.pop(context);
        await widget.onSaved();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _formError = e.toString();
          _saving = false;
        });
      }
    }
  }

  void _resetBaseProductPrices() {
    final prod = widget.products.firstWhere(
      (p) => p.id == _productId,
      orElse: () => widget.products.first,
    );
    setState(() {
      _amountCtrl.text = '${prod.price}';
      _costCtrl.text = '${prod.cost}';
      _expensesCtrl.text = '0';
    });
  }

  @override
  Widget build(BuildContext context) {
    final int amt = int.tryParse(_amountCtrl.text.trim()) ?? 0;
    final int cst = int.tryParse(_costCtrl.text.trim()) ?? 0;
    final int exp = int.tryParse(_expensesCtrl.text.trim()) ?? 0;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 14,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
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
                      _isEdit ? 'Actualizar consulta' : 'Nueva consulta',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      _isEdit ? 'Edita estado, montos o fecha de entrega' : 'Registra un cliente interesado',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (_formError != null)
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
                        _formError!,
                        style: const TextStyle(
                          color: Color(0xFF9B1C1C),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Nombre o alias
            TextField(
              controller: _aliasCtrl,
              decoration: const InputDecoration(
                labelText: 'Nombre o alias del cliente *',
                hintText: 'Ej.: Juan Carlos o Cliente FB Yesido',
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 14),

            // Canal de origen
            const Text(
              'Canal de origen',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF4B5563)),
            ),
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
                        avatar: Icon(
                          ch['icon'] as IconData,
                          size: 16,
                          color: _channel == ch['key'] ? Colors.white : const Color(0xFF4B5563),
                        ),
                        label: Text(ch['label'] as String, style: const TextStyle(fontSize: 12)),
                        selected: _channel == ch['key'],
                        selectedColor: const Color(0xFF172A3A),
                        labelStyle: TextStyle(
                          color: _channel == ch['key'] ? Colors.white : const Color(0xFF374151),
                          fontWeight: _channel == ch['key'] ? FontWeight.bold : FontWeight.normal,
                        ),
                        showCheckmark: false,
                        onSelected: (selected) {
                          if (selected) setState(() => _channel = ch['key'] as String);
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
              initialValue: widget.products.any((p) => p.id == _productId)
                  ? _productId
                  : widget.products.first.id,
              decoration: const InputDecoration(
                labelText: 'Producto consultado',
                prefixIcon: Icon(Icons.inventory_2_outlined),
              ),
              isExpanded: true,
              items: widget.products.map((p) => DropdownMenuItem(
                value: p.id,
                child: Text('${p.name} · Bs ${p.price}', overflow: TextOverflow.ellipsis),
              )).toList(),
              onChanged: (v) {
                if (v != null) {
                  setState(() {
                    _productId = v;
                    if (!_isEdit) {
                      final prod = widget.products.firstWhere((p) => p.id == v);
                      _amountCtrl.text = '${prod.price}';
                      _costCtrl.text = '${prod.cost}';
                    }
                  });
                }
              },
            ),
            const SizedBox(height: 14),

            // Estado interactivo (StatusSelectorChips)
            StatusSelectorChips(
              selectedStatus: _status,
              onStatusSelected: (newStatus) {
                setState(() {
                  _status = newStatus;
                  if (_status == 'agendado' && _selectedDateTime == null) {
                    _selectedDateTime = DateTime.now().add(const Duration(hours: 2));
                  }
                });
              },
            ),
            const SizedBox(height: 14),

            // Selector Fecha y Hora Interactivo (InteractiveDateTimePicker)
            InteractiveDateTimePicker(
              selectedDateTime: _selectedDateTime,
              onDateTimeChanged: (newDt) {
                setState(() {
                  _selectedDateTime = newDt;
                  if (newDt != null && (_status == 'consulta' || _status == 'interesado')) {
                    _status = 'agendado';
                  }
                });
              },
            ),
            const SizedBox(height: 14),

            // Modalidad de entrega
            const Text(
              'Modalidad de entrega',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF4B5563)),
            ),
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
                        avatar: Icon(
                          m['icon'] as IconData,
                          size: 16,
                          color: _deliveryMode == m['key'] ? Colors.white : const Color(0xFF4B5563),
                        ),
                        label: Text(m['label'] as String, style: const TextStyle(fontSize: 11)),
                        selected: _deliveryMode == m['key'],
                        selectedColor: const Color(0xFF172A3A),
                        labelStyle: TextStyle(
                          color: _deliveryMode == m['key'] ? Colors.white : const Color(0xFF374151),
                          fontWeight: _deliveryMode == m['key'] ? FontWeight.bold : FontWeight.normal,
                        ),
                        showCheckmark: false,
                        onSelected: (selected) {
                          if (selected) setState(() => _deliveryMode = m['key'] as String);
                        },
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 14),

            // Lugar acordado con atajos
            TextField(
              controller: _placeCtrl,
              decoration: InputDecoration(
                labelText: 'Lugar / Dirección acordada',
                hintText: 'Ej.: Cine Center, UAGRM...',
                prefixIcon: const Icon(Icons.place_outlined),
                suffixIcon: _placeCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () => setState(() => _placeCtrl.clear()),
                      )
                    : null,
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 6),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _placeSuggestions.map((place) => Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ActionChip(
                    avatar: const Icon(Icons.pin_drop_outlined, size: 14, color: Color(0xFF172A3A)),
                    label: Text(place, style: const TextStyle(fontSize: 11)),
                    onPressed: () => setState(() => _placeCtrl.text = place),
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
                    controller: _amountCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Precio (Bs) *'),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _costCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Costo (Bs) *'),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _expensesCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Gastos (Bs)'),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Tarjeta de Margen en Vivo
            MarginCalculatorCard(
              amount: amt,
              cost: cst,
              expenses: exp,
              onResetBase: _resetBaseProductPrices,
            ),
            const SizedBox(height: 12),

            // Pago verificado toggle
            Container(
              decoration: BoxDecoration(
                color: _paid ? const Color(0xFFEDF8F4) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _paid ? const Color(0xFF74C3A8) : const Color(0xFFE5E7EB),
                ),
              ),
              child: SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                value: _paid,
                activeThumbColor: const Color(0xFF1B6A53),
                title: Text(
                  _paid ? 'Pago cobrado y verificado ✓' : 'Pago pendiente por cobrar',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: _paid ? const Color(0xFF1B6A53) : const Color(0xFF374151),
                  ),
                ),
                subtitle: const Text('Obligatorio para finalizar entrega', style: TextStyle(fontSize: 11)),
                onChanged: (v) => setState(() => _paid = v),
              ),
            ),
            const SizedBox(height: 12),

            // Notas
            TextField(
              controller: _notesCtrl,
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
                if (_isEdit) ...[
                  IconButton.outlined(
                    icon: const Icon(Icons.delete_outline, color: Color(0xFFC81E1E)),
                    tooltip: 'Eliminar consulta',
                    onPressed: _saving ? null : _handleDelete,
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    icon: const Icon(Icons.receipt_long, color: Color(0xFF172A3A)),
                    tooltip: 'Compartir comprobante',
                    onPressed: () => ReceiptModal.show(context, lead: widget.lead!),
                  ),
                ],
                const Spacer(),
                TextButton(
                  onPressed: _saving ? null : () => Navigator.pop(context),
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
                  onPressed: _saving ? null : _handleSave,
                  child: Text(
                    _saving ? 'Guardando…' : (_isEdit ? 'Actualizar consulta' : 'Guardar consulta'),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
