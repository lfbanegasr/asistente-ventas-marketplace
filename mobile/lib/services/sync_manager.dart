import 'dart:async';
import 'package:flutter/foundation.dart';
import '../api_client.dart';
import '../models/lead.dart';
import '../models/product.dart';
import '../models/sync_mutation.dart';
import '../utils/uuid_helper.dart';
import 'offline_storage.dart';

class SyncManager extends ChangeNotifier {
  SyncManager({
    required this.apiClient,
    required this.storage,
  });

  final ApiClient apiClient;
  final OfflineStorage storage;

  bool _isSyncing = false;
  bool _isOffline = false;
  String? _lastError;

  List<Product> _products = [];
  List<Lead> _leads = [];
  bool _aiReady = false;

  bool get isSyncing => _isSyncing;
  bool get isOffline => _isOffline;
  String? get lastError => _lastError;
  int get pendingCount => storage.getMutations().length;
  bool get hasPendingMutations => pendingCount > 0;
  DateTime? get lastSyncTime => storage.getLastSyncTime();

  List<Product> get products => List.unmodifiable(_products);
  List<Lead> get leads => List.unmodifiable(_leads);
  bool get aiReady => _aiReady;

  /// Carga inicial en < 0.1s desde almacenamiento local y luego sincroniza en segundo plano.
  Future<void> init() async {
    _products = storage.getProducts();
    _leads = storage.getLeads();
    _aiReady = storage.getAiReady();
    notifyListeners();

    // Sincronización silenciosa en segundo plano
    unawaited(syncNow(silent: true));
  }

  /// Ejecuta sincronización bidireccional (procesa mutaciones y descarga estado fresco)
  Future<void> syncNow({bool silent = false}) async {
    if (_isSyncing) return;
    if (!apiClient.isLoggedIn) return;

    _isSyncing = true;
    _lastError = null;
    notifyListeners();

    try {
      // 1. Vaciar cola de mutaciones acumuladas
      await _flushMutationQueue();

      // 2. Descargar estado remoto actualizado
      final data = await apiClient.getState();
      final rawProducts = List<Map<String, dynamic>>.from(data['products'] ?? []);
      final rawLeads = List<Map<String, dynamic>>.from(data['leads'] ?? []);

      _products = rawProducts.map(Product.fromJson).toList();
      _leads = rawLeads.map(Lead.fromJson).toList();
      _aiReady = data['ai_ready'] == true;

      await storage.saveProducts(_products);
      await storage.saveLeads(_leads);
      await storage.saveAiReady(_aiReady);
      await storage.saveLastSyncTime(DateTime.now());

      _isOffline = false;
    } on AuthExpiredException {
      rethrow;
    } catch (e) {
      _isOffline = true;
      _lastError = e.toString();
      if (kDebugMode) {
        print('[SyncManager] Error de sincronización (modo offline activo): $e');
      }
      if (!silent) rethrow;
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  Future<void> _flushMutationQueue() async {
    final queue = storage.getMutations();
    if (queue.isEmpty) return;

    for (final mutation in queue) {
      try {
        switch (mutation.type) {
          case 'create_lead':
            final payload = Map<String, dynamic>.from(mutation.payload);
            final result = await apiClient.createLead(payload);
            final realId = result['id'] as String?;
            if (realId != null && realId != mutation.targetId) {
              await storage.reconcileLeadId(mutation.targetId, realId);
            }
            break;

          case 'update_lead':
            await apiClient.updateLead(mutation.targetId, mutation.payload);
            break;

          case 'delete_lead':
            // Si era un ID temporal que nunca llegó al backend, ignorar
            if (!mutation.targetId.startsWith('temp_')) {
              await apiClient.deleteLead(mutation.targetId);
            }
            break;

          case 'save_product':
            final prodId = mutation.targetId.startsWith('temp_') ? null : mutation.targetId;
            await apiClient.saveProduct(mutation.payload, id: prodId);
            break;

          case 'delete_product':
            if (!mutation.targetId.startsWith('temp_')) {
              await apiClient.deleteProduct(mutation.targetId);
            }
            break;
        }

        // Si se ejecutó correctamente, eliminar de la cola
        await storage.removeMutation(mutation.id);
      } catch (err) {
        // Si el servidor indica que ya existía (idempotencia) o fue borrado, descartar
        final msg = err.toString().toLowerCase();
        if (msg.contains('duplicate') || msg.contains('no encontrada') || msg.contains('404')) {
          await storage.removeMutation(mutation.id);
        } else {
          // Error de red, detener vaciado y reintentar en el próximo sync
          rethrow;
        }
      }
    }
  }

  // ── Mutaciones Optimistas de Leads (Cero Latencia en UI) ──
  Future<void> createLead(Map<String, dynamic> data) async {
    final requestId = (data['request_id'] as String?)?.isNotEmpty == true
        ? data['request_id'] as String
        : UuidHelper.generate();

    final tempId = 'temp_lead_${UuidHelper.generate()}';
    final payload = Map<String, dynamic>.from(data)..['request_id'] = requestId;

    // Buscar nombre de producto para enriquecer el modelo local
    final prodId = data['product_id'] as String? ?? '';
    final prod = _products.firstWhere(
      (p) => p.id == prodId,
      orElse: () => _products.isNotEmpty
          ? _products.first
          : const Product(id: '', name: '', cost: 0, price: 0, minPrice: 0),
    );

    final newLead = Lead(
      id: tempId,
      requestId: requestId,
      channel: data['channel'] as String? ?? 'Marketplace',
      productId: prodId,
      productName: prod.name,
      alias: data['alias'] as String? ?? '',
      status: data['status'] as String? ?? 'consulta',
      amount: (data['amount'] as num?)?.toInt() ?? prod.price,
      actualCost: (data['actual_cost'] as num?)?.toInt() ?? prod.cost,
      expenses: (data['expenses'] as num?)?.toInt() ?? 0,
      deliveryMode: data['delivery_mode'] as String? ?? 'por_definir',
      deliveryPlace: data['delivery_place'] as String? ?? '',
      deliveryAt: data['delivery_at'] as String? ?? '',
      paid: data['paid'] == 1 || data['paid'] == true,
      notes: data['notes'] as String? ?? '',
      createdAt: DateTime.now().toIso8601String(),
    );

    // 1. Guardar en memoria y almacenamiento local
    _leads.insert(0, newLead);
    await storage.saveOrUpdateLeadLocally(newLead);

    // 2. Encolar mutación
    final mutation = SyncMutation(
      id: UuidHelper.generate(),
      type: 'create_lead',
      targetId: tempId,
      payload: payload,
      createdAt: DateTime.now(),
    );
    await storage.addMutation(mutation);
    notifyListeners();

    // 3. Sincronizar en segundo plano si hay red
    unawaited(syncNow(silent: true));
  }

  Future<void> updateLead(String id, Map<String, dynamic> data) async {
    final idx = _leads.indexWhere((l) => l.id == id);
    if (idx >= 0) {
      final old = _leads[idx];
      final updated = old.copyWith(
        alias: data['alias'] as String? ?? old.alias,
        channel: data['channel'] as String? ?? old.channel,
        productId: data['product_id'] as String? ?? old.productId,
        status: data['status'] as String? ?? old.status,
        amount: (data['amount'] as num?)?.toInt() ?? old.amount,
        actualCost: (data['actual_cost'] as num?)?.toInt() ?? old.actualCost,
        expenses: (data['expenses'] as num?)?.toInt() ?? old.expenses,
        deliveryMode: data['delivery_mode'] as String? ?? old.deliveryMode,
        deliveryPlace: data['delivery_place'] as String? ?? old.deliveryPlace,
        deliveryAt: data['delivery_at'] as String? ?? old.deliveryAt,
        paid: data['paid'] == 1 || data['paid'] == true,
        notes: data['notes'] as String? ?? old.notes,
        updatedAt: DateTime.now().toIso8601String(),
      );
      _leads[idx] = updated;
      await storage.saveOrUpdateLeadLocally(updated);
    }

    final mutation = SyncMutation(
      id: UuidHelper.generate(),
      type: 'update_lead',
      targetId: id,
      payload: data,
      createdAt: DateTime.now(),
    );
    await storage.addMutation(mutation);
    notifyListeners();

    unawaited(syncNow(silent: true));
  }

  Future<void> deleteLead(String id) async {
    _leads.removeWhere((l) => l.id == id);
    await storage.removeLeadLocally(id);

    final mutation = SyncMutation(
      id: UuidHelper.generate(),
      type: 'delete_lead',
      targetId: id,
      payload: {},
      createdAt: DateTime.now(),
    );
    await storage.addMutation(mutation);
    notifyListeners();

    unawaited(syncNow(silent: true));
  }

  // ── Mutaciones Optimistas de Productos ───────────────────
  Future<void> saveProduct(Map<String, dynamic> data, {String? id}) async {
    final isEdit = id != null;
    final targetId = id ?? 'temp_prod_${UuidHelper.generate()}';

    final product = Product(
      id: targetId,
      name: data['name'] as String? ?? '',
      facts: data['facts'] as String? ?? '',
      cost: (data['cost'] as num?)?.toInt() ?? 0,
      price: (data['price'] as num?)?.toInt() ?? 0,
      minPrice: (data['min_price'] as num?)?.toInt() ?? 0,
      availability: data['availability'] as String? ?? 'por_confirmar',
      availableUnits: (data['available_units'] as num?)?.toInt() ?? 0,
      readyDate: data['ready_date'] as String? ?? '',
      isActive: data['is_active'] != false,
    );

    if (isEdit) {
      final idx = _products.indexWhere((p) => p.id == id);
      if (idx >= 0) {
        _products[idx] = product;
      }
    } else {
      _products.insert(0, product);
    }

    await storage.saveOrUpdateProductLocally(product);

    final mutation = SyncMutation(
      id: UuidHelper.generate(),
      type: 'save_product',
      targetId: targetId,
      payload: data,
      createdAt: DateTime.now(),
    );
    await storage.addMutation(mutation);
    notifyListeners();

    unawaited(syncNow(silent: true));
  }

  Future<void> deleteProduct(String id) async {
    _products.removeWhere((p) => p.id == id);
    await storage.removeProductLocally(id);

    final mutation = SyncMutation(
      id: UuidHelper.generate(),
      type: 'delete_product',
      targetId: id,
      payload: {},
      createdAt: DateTime.now(),
    );
    await storage.addMutation(mutation);
    notifyListeners();

    unawaited(syncNow(silent: true));
  }
}
