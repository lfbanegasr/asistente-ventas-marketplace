import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/product.dart';
import '../services/smart_clipboard_service.dart';
import '../utils/url_helper.dart';

class SmartClipboardSheet extends StatefulWidget {
  const SmartClipboardSheet({
    super.key,
    required this.products,
  });

  final List<Product> products;

  static Future<void> show(BuildContext context, {required List<Product> products}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SmartClipboardSheet(products: products),
    );
  }

  @override
  State<SmartClipboardSheet> createState() => _SmartClipboardSheetState();
}

class _SmartClipboardSheetState extends State<SmartClipboardSheet> {
  String _clipboardText = '';
  Product? _selectedProduct;
  late TextEditingController _replyCtrl;
  bool _loadingClipboard = true;
  String _detectedIntent = 'general';

  @override
  void initState() {
    super.initState();
    _replyCtrl = TextEditingController();
    _readClipboard();
  }

  @override
  void dispose() {
    _replyCtrl.dispose();
    super.dispose();
  }

  Future<void> _readClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    final analysis = SmartClipboardService.analyze(text, widget.products);

    setState(() {
      _clipboardText = text;
      _selectedProduct = analysis.matchedProduct ?? (widget.products.isNotEmpty ? widget.products.first : null);
      _detectedIntent = analysis.detectedIntent;
      _replyCtrl.text = analysis.suggestedReply;
      _loadingClipboard = false;
    });
  }

  void _onProductChanged(Product? newProduct) {
    if (newProduct == null) return;
    setState(() {
      _selectedProduct = newProduct;
      final analysis = SmartClipboardService.analyze(
        '$_clipboardText ${newProduct.name}',
        widget.products,
      );
      _replyCtrl.text = analysis.suggestedReply;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 14,
        bottom: bottomInset + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFD2D6DC),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF2EC),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.paste_rounded, color: Color(0xFFDF7447), size: 20),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Portapapeles Inteligente',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF172A3A)),
                      ),
                      Text(
                        'Detecta preguntas en Marketplace y sugiere respuestas',
                        style: TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),

            const SizedBox(height: 16),

            if (_loadingClipboard)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
              )
            else ...[
              // Texto copiado del cliente
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAF9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8E4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'TEXTO COPIADO DEL CLIENTE',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF6B7280)),
                        ),
                        IconButton(
                          icon: const Icon(Icons.refresh, size: 16, color: Color(0xFFDF7447)),
                          tooltip: 'Volver a leer portapapeles',
                          constraints: const BoxConstraints(),
                          padding: EdgeInsets.zero,
                          onPressed: _readClipboard,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _clipboardText.isNotEmpty ? '«$_clipboardText»' : '(No hay texto copiado en el portapapeles)',
                      style: TextStyle(
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                        color: _clipboardText.isNotEmpty ? const Color(0xFF172A3A) : const Color(0xFF9CA3AF),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // Producto Asociado
              const Text(
                'Producto detectado o seleccionado',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF4B5563)),
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: _selectedProduct?.id,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.inventory_2_outlined),
                  isDense: true,
                ),
                isExpanded: true,
                items: widget.products.map((p) => DropdownMenuItem(
                  value: p.id,
                  child: Text('${p.name} · Bs ${p.price} (${p.availabilityLabel})', overflow: TextOverflow.ellipsis),
                )).toList(),
                onChanged: (id) {
                  final p = widget.products.firstWhere((item) => item.id == id);
                  _onProductChanged(p);
                },
              ),

              if (_selectedProduct != null) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    Chip(
                      backgroundColor: const Color(0xFFEDF8F4),
                      side: const BorderSide(color: Color(0xFFB0DFCE)),
                      label: Text('Precio: Bs ${_selectedProduct!.price}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1B6A53))),
                    ),
                    Chip(
                      backgroundColor: const Color(0xFFF3F5F2),
                      side: const BorderSide(color: Color(0xFFDCE2DD)),
                      label: Text('Mínimo: Bs ${_selectedProduct!.minPrice}', style: const TextStyle(fontSize: 11, color: Color(0xFF374151))),
                    ),
                    Chip(
                      backgroundColor: const Color(0xFFF3F5F2),
                      side: const BorderSide(color: Color(0xFFDCE2DD)),
                      label: Text('Stock: ${_selectedProduct!.availableUnits} un.', style: const TextStyle(fontSize: 11, color: Color(0xFF374151))),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 14),

              // Respuesta Sugerida Editable
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Respuesta sugerida (lista para enviar)',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF4B5563)),
                  ),
                  Text(
                    'Intención: $_detectedIntent',
                    style: const TextStyle(fontSize: 10, color: Color(0xFF6B7280)),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _replyCtrl,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'Respuesta sugerida para el cliente...',
                ),
              ),

              const SizedBox(height: 16),

              // Botones de acción
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.copy, size: 16),
                      label: const Text('Copiar respuesta', style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: _replyCtrl.text));
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Respuesta copiada al portapapeles.'),
                            backgroundColor: Color(0xFF2E6847),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF25D366), // Color WhatsApp
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.chat_bubble_outline, size: 16),
                      label: const Text('Enviar a WhatsApp', style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: () {
                        UrlHelper.openWhatsAppChat(text: _replyCtrl.text);
                        Navigator.pop(context);
                      },
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
