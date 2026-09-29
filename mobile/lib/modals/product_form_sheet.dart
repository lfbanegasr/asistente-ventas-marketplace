import 'package:flutter/material.dart';
import '../models/product.dart';
import '../main.dart';

class ProductFormSheet extends StatefulWidget {
  const ProductFormSheet({
    super.key,
    this.product,
    required this.onSaved,
    this.onDeleted,
  });

  final Product? product;
  final Future<void> Function() onSaved;
  final Future<void> Function()? onDeleted;

  static Future<void> show(
    BuildContext context, {
    Product? product,
    required Future<void> Function() onSaved,
    Future<void> Function()? onDeleted,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => ProductFormSheet(
        product: product,
        onSaved: onSaved,
        onDeleted: onDeleted,
      ),
    );
  }

  @override
  State<ProductFormSheet> createState() => _ProductFormSheetState();
}

class _ProductFormSheetState extends State<ProductFormSheet> {
  late final bool _isEdit;
  late final TextEditingController _nameCtrl;
  late final TextEditingController _factsCtrl;
  late final TextEditingController _costCtrl;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _minPriceCtrl;
  late final TextEditingController _unitsCtrl;
  late final TextEditingController _readyDateCtrl;
  late String _availability;
  bool _checked = false;
  bool _saving = false;
  String? _formError;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _isEdit = p != null;
    _nameCtrl = TextEditingController(text: p?.name ?? '');
    _factsCtrl = TextEditingController(text: p?.facts ?? '');
    _costCtrl = TextEditingController(text: p != null ? '${p.cost}' : '');
    _priceCtrl = TextEditingController(text: p != null ? '${p.price}' : '');
    _minPriceCtrl = TextEditingController(text: p != null ? '${p.minPrice}' : '');
    _unitsCtrl = TextEditingController(text: p != null ? '${p.availableUnits}' : '0');
    _readyDateCtrl = TextEditingController(text: p?.readyDate ?? '');
    _availability = p?.availability ?? 'por_confirmar';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _factsCtrl.dispose();
    _costCtrl.dispose();
    _priceCtrl.dispose();
    _minPriceCtrl.dispose();
    _unitsCtrl.dispose();
    _readyDateCtrl.dispose();
    super.dispose();
  }

  String _toIsoDate(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  Future<void> _handleDelete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: const Text('¿Eliminar producto?'),
        content: const Text(
          'Se eliminarán también las consultas y chats vinculados a este producto.',
        ),
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
        await syncManager.deleteProduct(widget.product!.id);
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
    final name = _nameCtrl.text.trim();
    final cost = int.tryParse(_costCtrl.text.trim());
    final price = int.tryParse(_priceCtrl.text.trim());
    final minPrice = int.tryParse(_minPriceCtrl.text.trim());
    final units = int.tryParse(_unitsCtrl.text.trim());

    if (name.isEmpty) {
      setState(() => _formError = 'El nombre es obligatorio.');
      return;
    }
    if (cost == null || cost < 0 || price == null || price < 0 ||
        minPrice == null || minPrice < 0 || units == null || units < 0) {
      setState(() => _formError = 'Ingresa valores numéricos válidos.');
      return;
    }
    if (minPrice > price) {
      setState(() => _formError = 'El precio mínimo no puede superar el precio publicado.');
      return;
    }
    if (_availability == 'en_mano' && units < 1) {
      setState(() => _formError = 'Si está en mano, indica al menos 1 unidad.');
      return;
    }
    if (_availability != 'en_mano' && units != 0) {
      setState(() => _formError = 'Unidades en mano debe ser 0 si no lo tienes físicamente.');
      return;
    }

    setState(() {
      _saving = true;
      _formError = null;
    });

    try {
      final data = {
        'name': name,
        'facts': _factsCtrl.text.trim(),
        'cost': cost,
        'price': price,
        'min_price': minPrice,
        'availability': _availability,
        'available_units': units,
        'ready_date': _readyDateCtrl.text.trim(),
        'availability_checked': _checked,
      };

      await syncManager.saveProduct(data, id: _isEdit ? widget.product!.id : null);
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

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
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
                  _isEdit ? 'Editar producto' : 'Nuevo producto',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            if (_formError != null)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFDE8E8),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _formError!,
                  style: const TextStyle(color: Color(0xFFC81E1E), fontSize: 13),
                ),
              ),
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Nombre *',
                hintText: 'Ej.: Yesido PB6010',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _factsCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Datos comprobados',
                hintText: 'Solo lo que puedas afirmar al cliente',
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _costCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Costo (Bs) *'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _priceCtrl,
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
                    controller: _minPriceCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Precio mín. interno *'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _unitsCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Unidades en mano *'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _availability,
              decoration: const InputDecoration(labelText: 'Disponibilidad'),
              items: const [
                DropdownMenuItem(value: 'por_confirmar', child: Text('Por confirmar')),
                DropdownMenuItem(value: 'proveedor_confirmado', child: Text('Proveedor confirmó')),
                DropdownMenuItem(value: 'en_mano', child: Text('En mano')),
              ],
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _availability = val;
                    if (val == 'en_mano') {
                      if ((int.tryParse(_unitsCtrl.text) ?? 0) <= 0) _unitsCtrl.text = '1';
                    } else {
                      _unitsCtrl.text = '0';
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
                    controller: _readyDateCtrl,
                    decoration: InputDecoration(
                      labelText: 'Fecha posible entrega (AAAA-MM-DD)',
                      hintText: '2026-09-30',
                      prefixIcon: const Icon(Icons.calendar_today_outlined, size: 20),
                      suffixIcon: _readyDateCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () => setState(() => _readyDateCtrl.clear()),
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
                    if (_readyDateCtrl.text.isNotEmpty) {
                      try {
                        initial = DateTime.parse(_readyDateCtrl.text);
                      } catch (_) {}
                    }
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: initial,
                      firstDate: DateTime.now().subtract(const Duration(days: 30)),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                      helpText: 'FECHA ESTIMADA DE ENTREGA',
                    );
                    if (picked != null) {
                      setState(() => _readyDateCtrl.text = _toIsoDate(picked));
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
                    onPressed: () => setState(() => _readyDateCtrl.text = _toIsoDate(DateTime.now())),
                  ),
                  const SizedBox(width: 6),
                  ActionChip(
                    avatar: const Icon(Icons.fast_forward, size: 15),
                    label: const Text('Mañana', style: TextStyle(fontSize: 12)),
                    onPressed: () => setState(() => _readyDateCtrl.text = _toIsoDate(DateTime.now().add(const Duration(days: 1)))),
                  ),
                  const SizedBox(width: 6),
                  ActionChip(
                    label: const Text('En 3 días', style: TextStyle(fontSize: 12)),
                    onPressed: () => setState(() => _readyDateCtrl.text = _toIsoDate(DateTime.now().add(const Duration(days: 3)))),
                  ),
                  const SizedBox(width: 6),
                  ActionChip(
                    label: const Text('En 1 semana', style: TextStyle(fontSize: 12)),
                    onPressed: () => setState(() => _readyDateCtrl.text = _toIsoDate(DateTime.now().add(const Duration(days: 7)))),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _checked,
              title: const Text('Verifiqué esta disponibilidad ahora', style: TextStyle(fontSize: 13)),
              onChanged: (v) => setState(() => _checked = v ?? false),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                if (_isEdit)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Color(0xFFC81E1E)),
                    tooltip: 'Eliminar producto',
                    onPressed: _saving ? null : _handleDelete,
                  ),
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
                  ),
                  onPressed: _saving ? null : _handleSave,
                  child: Text(_saving ? 'Guardando…' : 'Guardar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
