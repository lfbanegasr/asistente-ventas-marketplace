import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../main.dart';
import '../api_client.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.products});
  final List<Map<String, dynamic>> products;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  List<Map<String, dynamic>> _threads = [];
  String? _activeThreadId;
  String? _activeProductName;
  String _activeTitle = 'Nueva conversación';
  List<Map<String, dynamic>> _turns = [];
  String? _selectedProductId;
  final _inputController = TextEditingController();
  bool _sending = false;
  String? _error;
  String? _pendingRequestId;
  String? _pendingText;

  @override
  void initState() {
    super.initState();
    _loadThreads();
    if (widget.products.isNotEmpty) {
      _selectedProductId = widget.products.first['id'] as String;
    }
  }

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  Future<void> _loadThreads() async {
    try {
      final data = await apiClient.getChats();
      setState(() => _threads = List<Map<String, dynamic>>.from(data['threads'] ?? []));
    } catch (_) {}
  }

  Future<void> _openThread(String id) async {
    try {
      final data = await apiClient.getChat(id);
      final thread = data['thread'] as Map<String, dynamic>;
      setState(() {
        _activeThreadId = id;
        _activeTitle = thread['title'] as String? ?? 'Chat';
        _activeProductName = thread['product_name'] as String?;
        _selectedProductId = thread['product_id'] as String?;
        _turns = List<Map<String, dynamic>>.from(data['turns'] ?? []);
        _error = null;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  void _newChat() {
    setState(() {
      _activeThreadId = null;
      _activeTitle = 'Nueva conversación';
      _activeProductName = null;
      _turns = [];
      _error = null;
      _pendingRequestId = null;
      _pendingText = null;
      _inputController.clear();
      if (widget.products.isNotEmpty) {
        _selectedProductId = widget.products.first['id'] as String;
      }
    });
  }

  Future<void> _send() async {
    final message = _inputController.text.trim();
    if (message.isEmpty || _sending) return;
    if (_selectedProductId == null) {
      setState(() => _error = 'Elige un producto.');
      return;
    }

    // Idempotent request ID
    if (_pendingText != message) {
      _pendingRequestId = _generateUuid();
      _pendingText = message;
    }

    setState(() {
      _sending = true;
      _error = null;
    });

    try {
      // Create thread if needed
      if (_activeThreadId == null) {
        final threadId = _generateUuid();
        await apiClient.createChat({'id': threadId, 'product_id': _selectedProductId});
        _activeThreadId = threadId;
      }

      final result = await apiClient.sendTurn(_activeThreadId!, {
        'request_id': _pendingRequestId,
        'message': message,
      });

      final turn = result['turn'] as Map<String, dynamic>;
      setState(() {
        _turns.add(turn);
        _inputController.clear();
        _pendingRequestId = null;
        _pendingText = null;
        if (result.containsKey('warning')) {
          _error = result['warning'] as String?;
        }
      });

      await _loadThreads();
      // Update title
      final thread = _threads.firstWhere((t) => t['id'] == _activeThreadId, orElse: () => <String, dynamic>{});
      if (thread.isNotEmpty) {
        setState(() {
          _activeTitle = thread['title'] as String? ?? _activeTitle;
          _activeProductName = thread['product_name'] as String?;
        });
      }
    } on AuthExpiredException {
      setState(() => _error = 'La sesión terminó.');
    } catch (e) {
      setState(() => _error = 'No se envió: $e');
    } finally {
      setState(() => _sending = false);
    }
  }

  Future<void> _deleteThread() async {
    if (_activeThreadId == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Eliminar conversación?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await apiClient.deleteChat(_activeThreadId!);
      _newChat();
      await _loadThreads();
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  String _generateUuid() {
    final rand = DateTime.now().microsecondsSinceEpoch;
    final chars = '0123456789abcdef';
    String gen(int len) => List.generate(len, (i) => chars[(rand + i * 37) % 16]).join();
    return '${gen(8)}-${gen(4)}-4${gen(3)}-a${gen(3)}-${gen(12)}';
  }

  static const _speechChannel = MethodChannel('com.lfbanegasr.mesa_ventas_mobile/speech');

  Future<void> _startVoiceInput() async {
    try {
      final text = await _speechChannel.invokeMethod<String>('startListening');
      if (text != null && text.trim().isNotEmpty) {
        _inputController.text = text.trim();
        _send();
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Thread list (horizontal scroll)
        SizedBox(
          height: 80,
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 12),
                child: IconButton.filledTonal(
                  onPressed: _newChat,
                  icon: const Icon(Icons.add),
                  tooltip: 'Nuevo chat',
                ),
              ),
              Expanded(
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  itemCount: _threads.length,
                  itemBuilder: (ctx, i) {
                    final t = _threads[i];
                    final isActive = t['id'] == _activeThreadId;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
                      child: ActionChip(
                        backgroundColor: isActive ? const Color(0xFFE9EFEA) : null,
                        label: SizedBox(
                          width: 120,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(t['title'] as String? ?? 'Chat', overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                              Text(t['product_name'] as String? ?? '', overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, color: Color(0xFF697B80))),
                            ],
                          ),
                        ),
                        onPressed: () => _openThread(t['id'] as String),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),

        // Chat header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFE9EDE8)))),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_activeTitle, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis),
                    if (_activeProductName != null)
                      Text(_activeProductName!, style: const TextStyle(fontSize: 12, color: Color(0xFF6A7A7F))),
                  ],
                ),
              ),
              if (_activeThreadId != null)
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20),
                  onPressed: _deleteThread,
                  tooltip: 'Eliminar',
                ),
            ],
          ),
        ),

        // Messages
        Expanded(
          child: _turns.isEmpty && _activeThreadId == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 48, height: 48,
                          decoration: BoxDecoration(color: const Color(0xFFFBE9DC), borderRadius: BorderRadius.circular(16)),
                          alignment: Alignment.center,
                          child: const Text('✦', style: TextStyle(fontSize: 27, color: Color(0xFFC86F42))),
                        ),
                        const SizedBox(height: 12),
                        const Text('¿Qué necesitas responder?', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        const Text('Pega una consulta o pregúntame cómo negociar.', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF66787D), fontSize: 14)),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _turns.length,
                  itemBuilder: (ctx, i) {
                    final turn = _turns[i];
                    return Column(
                      children: [
                        _chatBubble(turn['user_text'] as String, true),
                        _chatBubble(turn['assistant_text'] as String, false, source: turn['source'] as String?),
                      ],
                    );
                  },
                ),
        ),

        // Error
        if (_error != null)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF0E9),
              border: Border.all(color: const Color(0xFFF2C9B8)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(_error!, style: const TextStyle(color: Color(0xFF8F351F), fontSize: 13)),
          ),

        // Minimalist Composer
        Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFE9EDE8)))),
          child: Column(
            children: [
              if (_activeThreadId == null && widget.products.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedProductId,
                    decoration: const InputDecoration(labelText: 'Producto', isDense: true),
                    items: widget.products.map((p) => DropdownMenuItem(value: p['id'] as String, child: Text(p['name'] as String))).toList(),
                    onChanged: (v) => setState(() => _selectedProductId = v),
                  ),
                ),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F6F4),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: const Color(0xFFE2E7E2)),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.mic, color: Color(0xFFDF7447), size: 22),
                      onPressed: _sending ? null : _startVoiceInput,
                      tooltip: 'Dictar por voz',
                    ),
                    Expanded(
                      child: TextField(
                        controller: _inputController,
                        maxLines: null,
                        maxLength: 1200,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _send(),
                        decoration: const InputDecoration(
                          hintText: 'Pregunta o redacta una respuesta...',
                          hintStyle: TextStyle(fontSize: 14, color: Color(0xFF8B989D)),
                          counterText: '',
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          fillColor: Colors.transparent,
                          contentPadding: EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: _sending ? null : _send,
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.all(9),
                        decoration: const BoxDecoration(
                          color: Color(0xFFDF7447),
                          shape: BoxShape.circle,
                        ),
                        child: _sending
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.arrow_upward, size: 17, color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 4),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _chatBubble(String text, bool isUser, {String? source}) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
        child: Column(
          crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isUser ? const Color(0xFF172A3A) : const Color(0xFFF1F4EF),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(17),
                  topRight: const Radius.circular(17),
                  bottomLeft: Radius.circular(isUser ? 17 : 5),
                  bottomRight: Radius.circular(isUser ? 5 : 17),
                ),
              ),
              child: Text(
                text,
                style: TextStyle(
                  color: isUser ? Colors.white : const Color(0xFF233840),
                  fontSize: 14,
                  height: 1.55,
                ),
              ),
            ),
            if (!isUser) ...[
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(source == 'base' ? 'Respuesta base' : 'Gemini', style: const TextStyle(fontSize: 11, color: Color(0xFF7A8888))),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: text));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Texto copiado. Revísalo antes de enviarlo.')),
                      );
                    },
                    child: const Text('Copiar', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFFA3522D))),
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
