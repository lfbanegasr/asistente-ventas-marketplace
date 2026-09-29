import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// HTTP client that talks directly to the backend API with JWT auth.
class ApiClient {
  ApiClient({required this.baseUrl});

  final String baseUrl;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  String? _token;

  Future<void> init() async {
    _token = await _storage.read(key: 'ventas_token');
  }

  bool get isLoggedIn => _token != null;

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (_token != null) 'Authorization': 'Bearer $_token',
  };

  Future<Map<String, dynamic>> login(String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'password': password}),
    );
    final data = _decode(response);
    if (response.statusCode == 200 && data['token'] != null) {
      _token = data['token'] as String;
      await _storage.write(key: 'ventas_token', value: _token);
      await _storage.write(
        key: 'ventas_token_expires',
        value: data['expiresAt'].toString(),
      );
    }
    return data;
  }

  Future<void> logout() async {
    _token = null;
    await _storage.delete(key: 'ventas_token');
    await _storage.delete(key: 'ventas_token_expires');
  }

  Future<Map<String, dynamic>> checkSession() async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/session'),
      headers: _headers,
    );
    return _decode(response);
  }

  Future<Map<String, dynamic>> getState() async {
    return _get('/api/state');
  }

  // ── Products ──────────────────────────────────────────
  Future<Map<String, dynamic>> saveProduct(
    Map<String, dynamic> data, {
    String? id,
  }) async {
    if (id != null) {
      return _patch('/api/products/$id', data);
    }
    return _post('/api/products', data);
  }

  Future<Map<String, dynamic>> deleteProduct(String id) async {
    return _delete('/api/products/$id');
  }

  // ── Leads ─────────────────────────────────────────────
  Future<Map<String, dynamic>> createLead(Map<String, dynamic> data) async {
    return _post('/api/leads', data, expectedStatus: 201);
  }

  Future<Map<String, dynamic>> updateLead(
    String id,
    Map<String, dynamic> data,
  ) async {
    return _patch('/api/leads/$id', data);
  }

  Future<Map<String, dynamic>> deleteLead(String id) async {
    return _delete('/api/leads/$id');
  }

  // ── Chats ─────────────────────────────────────────────
  Future<Map<String, dynamic>> getChats() async {
    return _get('/api/chats');
  }

  Future<Map<String, dynamic>> createChat(Map<String, dynamic> data) async {
    return _post('/api/chats', data);
  }

  Future<Map<String, dynamic>> getChat(String id) async {
    return _get('/api/chats/$id');
  }

  Future<Map<String, dynamic>> deleteChat(String id) async {
    return _delete('/api/chats/$id');
  }

  Future<Map<String, dynamic>> sendTurn(
    String chatId,
    Map<String, dynamic> data,
  ) async {
    return _post('/api/chats/$chatId/turns', data, expectedStatus: 201);
  }

  // ── AI ────────────────────────────────────────────────
  Future<Map<String, dynamic>> aiDraft(Map<String, dynamic> data) async {
    return _post('/api/ai', data);
  }

  // ── HTTP helpers ──────────────────────────────────────
  Future<Map<String, dynamic>> _get(String path) async {
    final response = await http.get(
      Uri.parse('$baseUrl$path'),
      headers: _headers,
    );
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body, {
    int expectedStatus = 200,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl$path'),
      headers: _headers,
      body: jsonEncode(body),
    );
    return _handleResponse(response, expectedStatus: expectedStatus);
  }

  Future<Map<String, dynamic>> _patch(
    String path,
    Map<String, dynamic> body,
  ) async {
    final response = await http.patch(
      Uri.parse('$baseUrl$path'),
      headers: _headers,
      body: jsonEncode(body),
    );
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> _delete(String path) async {
    final response = await http.delete(
      Uri.parse('$baseUrl$path'),
      headers: _headers,
    );
    return _handleResponse(response);
  }

  Map<String, dynamic> _decode(http.Response response) {
    try {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      return {'error': 'Respuesta inválida del servidor.'};
    }
  }

  Map<String, dynamic> _handleResponse(
    http.Response response, {
    int expectedStatus = 200,
  }) {
    final data = _decode(response);
    if (response.statusCode == 401) {
      _token = null;
      throw AuthExpiredException();
    }
    if (response.statusCode != expectedStatus &&
        !(response.statusCode == 200 && data.containsKey('duplicate'))) {
      throw ApiException(
        data['error']?.toString() ?? 'Error ${response.statusCode}',
        response.statusCode,
      );
    }
    return data;
  }
}

class AuthExpiredException implements Exception {
  @override
  String toString() => 'La sesión terminó.';
}

class ApiException implements Exception {
  ApiException(this.message, this.statusCode);
  final String message;
  final int statusCode;

  @override
  String toString() => message;
}
