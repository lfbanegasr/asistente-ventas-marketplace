import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../main.dart';

class VoiceAgentSheet extends StatefulWidget {
  const VoiceAgentSheet({
    super.key,
    required this.onStateUpdated,
  });

  final Future<void> Function() onStateUpdated;

  static Future<void> show(
    BuildContext context, {
    required Future<void> Function() onStateUpdated,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => VoiceAgentSheet(onStateUpdated: onStateUpdated),
    );
  }

  @override
  State<VoiceAgentSheet> createState() => _VoiceAgentSheetState();
}

class _VoiceAgentSheetState extends State<VoiceAgentSheet> {
  static const _speechChannel = MethodChannel('com.lfbanegasr.mesa_ventas_mobile/speech');

  final _cmdCtrl = TextEditingController();
  bool _busy = false;
  bool _listening = false;
  Map<String, dynamic>? _lastResult;
  String? _errorText;

  @override
  void dispose() {
    _cmdCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitCommand(String command) async {
    final trimmed = command.trim();
    if (trimmed.isEmpty) return;

    setState(() {
      _busy = true;
      _errorText = null;
      _lastResult = null;
    });

    try {
      final response = await apiClient.sendAgentCommand(trimmed);
      if (mounted) {
        setState(() {
          _busy = false;
          _lastResult = response;
        });

        if (response['state_updated'] == true) {
          await widget.onStateUpdated();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _errorText = e.toString();
        });
      }
    }
  }

  Future<void> _startListening() async {
    setState(() {
      _listening = true;
      _errorText = null;
    });
    try {
      final text = await _speechChannel.invokeMethod<String>('startListening');
      if (mounted) {
        setState(() => _listening = false);
        if (text != null && text.trim().isNotEmpty) {
          _cmdCtrl.text = text.trim();
          await _submitCommand(text.trim());
        }
      }
    } catch (err) {
      if (mounted) {
        setState(() {
          _listening = false;
          _errorText = 'No se pudo activar el micrófono: $err';
        });
      }
    }
  }

  Widget _buildPill(String title, String prompt) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionChip(
        elevation: 0,
        backgroundColor: const Color(0xFFF3F5F2),
        side: const BorderSide(color: Color(0xFFE2E7E2)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        label: Text(
          title,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF2C3E50)),
        ),
        onPressed: _busy
            ? null
            : () {
                _cmdCtrl.text = prompt;
                _submitCommand(prompt);
              },
      ),
    );
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
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFD6DBD8),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header Minimalista
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE9F3EE),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.auto_awesome, color: Color(0xFF2A7263), size: 18),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Asistente por Voz',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF172A3A)),
                      ),
                      Text(
                        'Habla o escribe para agendar, actualizar o consultar',
                        style: TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20, color: Color(0xFF6B7280)),
                  onPressed: () => Navigator.pop(context),
                  constraints: const BoxConstraints(),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Input Bar con Microfono Integrado
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF7F9F7),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _listening ? const Color(0xFFDF7447) : const Color(0xFFDCE2DD),
                  width: _listening ? 1.5 : 1,
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Grabar por voz',
                    icon: Icon(
                      _listening ? Icons.mic : Icons.mic_none,
                      color: _listening ? const Color(0xFFDF7447) : const Color(0xFF172A3A),
                      size: 22,
                    ),
                    onPressed: _busy ? null : _startListening,
                  ),
                  Expanded(
                    child: TextField(
                      controller: _cmdCtrl,
                      textInputAction: TextInputAction.send,
                      onSubmitted: _submitCommand,
                      decoration: InputDecoration(
                        hintText: _listening ? 'Escuchando tu voz...' : 'Ej.: Agendá entrega para Juan Carlos...',
                        hintStyle: TextStyle(
                          fontSize: 13,
                          color: _listening ? const Color(0xFFDF7447) : const Color(0xFF8C9B9E),
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: _busy ? null : () => _submitCommand(_cmdCtrl.text),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Color(0xFF172A3A),
                        shape: BoxShape.circle,
                      ),
                      child: _busy
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

            // Quick Suggestion Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildPill('📦 Agendar Yango', 'Agendá para Juan Carlos del PB225 este viernes 4pm vía Yango'),
                  _buildPill('🏷️ Subir precio', 'Subile 10 pesos al PB225 y anotá 4 unidades en mano'),
                  _buildPill('📊 Balance de hoy', '¿Cuánto margen cobrado y ventas llevamos hoy?'),
                  _buildPill('💬 Redactar', 'Redactale al cliente del PB225 que pide rebaja'),
                ],
              ),
            ),

            // Error Box
            if (_errorText != null) ...[
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
                    const Row(
                      children: [
                        Icon(Icons.info_outline, color: Color(0xFFC04724), size: 18),
                        SizedBox(width: 8),
                        Text(
                          'Aviso del Asistente',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF8F351F)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _errorText!,
                      style: const TextStyle(color: Color(0xFF8F351F), fontSize: 13, height: 1.3),
                    ),
                  ],
                ),
              ),
            ],

            // Response Bubble
            if (_lastResult != null) ...[
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
                            Text(
                              'Respuesta',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF53646B)),
                            ),
                          ],
                        ),
                        if (_lastResult!['state_updated'] == true)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE2EFE7),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              '✓ BD Actualizada',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF2C7569)),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _lastResult!['reply'] ?? '',
                      style: const TextStyle(
                        fontSize: 15,
                        height: 1.45,
                        color: Color(0xFF172A3A),
                        fontWeight: FontWeight.w500,
                      ),
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
                            Clipboard.setData(ClipboardData(text: _lastResult!['reply'] ?? ''));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Copiado al portapapeles'),
                                backgroundColor: Color(0xFF2E6847),
                              ),
                            );
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
  }
}
