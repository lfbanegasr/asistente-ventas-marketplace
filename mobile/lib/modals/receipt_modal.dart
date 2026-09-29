import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';
import '../models/lead.dart';
import '../widgets/sales_receipt_card.dart';

class ReceiptModal extends StatefulWidget {
  const ReceiptModal({super.key, required this.lead});

  final Lead lead;

  static Future<void> show(BuildContext context, {required Lead lead}) {
    return showDialog(
      context: context,
      builder: (_) => ReceiptModal(lead: lead),
    );
  }

  @override
  State<ReceiptModal> createState() => _ReceiptModalState();
}

class _ReceiptModalState extends State<ReceiptModal> {
  final GlobalKey _boundaryKey = GlobalKey();
  bool _generating = false;

  Future<void> _shareReceiptImage() async {
    setState(() => _generating = true);
    try {
      final boundary = _boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        throw Exception('No se pudo renderizar la tarjeta en memoria.');
      }

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        throw Exception('Error al codificar imagen PNG.');
      }

      final pngBytes = byteData.buffer.asUint8List();
      final code = widget.lead.id.length >= 8 ? widget.lead.id.substring(0, 8).toUpperCase() : widget.lead.id;
      final fileName = 'recibo-$code.png';

      final shareText = '¡Hola ${widget.lead.alias}! Aquí tienes el comprobante de tu pedido en Mesa de Ventas. ¿Todo confirmado?';

      await SharePlus.instance.share(ShareParams(
        files: [XFile.fromData(pngBytes, mimeType: 'image/png', name: fileName)],
        fileNameOverrides: [fileName],
        text: shareText,
        title: 'Comprobante de Pedido #$code',
      ));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al compartir comprobante: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Tarjeta que será capturada como imagen
            RepaintBoundary(
              key: _boundaryKey,
              child: SalesReceiptCard(lead: widget.lead),
            ),

            const SizedBox(height: 18),

            // Botones de Acción
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: Color(0xFFCED8D2)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.close, size: 18, color: Color(0xFF172A3A)),
                  label: const Text('Cerrar', style: TextStyle(color: Color(0xFF172A3A))),
                  onPressed: () => Navigator.pop(context),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366), // Color WhatsApp
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: _generating
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.share, size: 18),
                  label: Text(
                    _generating ? 'Generando…' : 'Compartir en WhatsApp',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  onPressed: _generating ? null : _shareReceiptImage,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
