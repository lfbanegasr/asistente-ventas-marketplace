import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/product.dart';
import '../models/lead.dart';
import '../models/sync_mutation.dart';

class OfflineStorage {
  OfflineStorage(this._prefs);

  final SharedPreferences _prefs;

  static const String _keyProducts = 'offline_products';
  static const String _keyLeads = 'offline_leads';
  static const String _keyAiReady = 'offline_ai_ready';
  static const String _keyMutations = 'offline_mutations_queue';
  static const String _keyLastSync = 'offline_last_sync';

  static Future<OfflineStorage> create() async {
    final prefs = await SharedPreferences.getInstance();
    return OfflineStorage(prefs);
  }

  // ── Products ──────────────────────────────────────────
  List<Product> getProducts() {
    final raw = _prefs.getString(_keyProducts);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list.map((e) => Product.fromJson(Map<String, dynamic>.from(e as Map))).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveProducts(List<Product> products) async {
    final raw = jsonEncode(products.map((p) => p.toJson()).toList());
    await _prefs.setString(_keyProducts, raw);
  }

  Future<void> saveOrUpdateProductLocally(Product product) async {
    final current = getProducts();
    final idx = current.indexWhere((p) => p.id == product.id);
    if (idx >= 0) {
      current[idx] = product;
    } else {
      current.insert(0, product);
    }
    await saveProducts(current);
  }

  Future<void> removeProductLocally(String id) async {
    final current = getProducts()..removeWhere((p) => p.id == id);
    await saveProducts(current);
  }

  // ── Leads ─────────────────────────────────────────────
  List<Lead> getLeads() {
    final raw = _prefs.getString(_keyLeads);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list.map((e) => Lead.fromJson(Map<String, dynamic>.from(e as Map))).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveLeads(List<Lead> leads) async {
    final raw = jsonEncode(leads.map((l) => l.toJson()).toList());
    await _prefs.setString(_keyLeads, raw);
  }

  Future<void> saveOrUpdateLeadLocally(Lead lead) async {
    final current = getLeads();
    final idx = current.indexWhere((l) => l.id == lead.id);
    if (idx >= 0) {
      current[idx] = lead;
    } else {
      current.insert(0, lead);
    }
    await saveLeads(current);
  }

  Future<void> removeLeadLocally(String id) async {
    final current = getLeads()..removeWhere((l) => l.id == id);
    await saveLeads(current);
  }

  Future<void> reconcileLeadId(String tempId, String realId) async {
    final current = getLeads();
    bool modified = false;
    for (int i = 0; i < current.length; i++) {
      if (current[i].id == tempId) {
        current[i] = current[i].copyWith(id: realId);
        modified = true;
      }
    }
    if (modified) {
      await saveLeads(current);
    }

    // Actualizar también en mutaciones pendientes posteriores
    final mutations = getMutations();
    bool mutationsModified = false;
    for (int i = 0; i < mutations.length; i++) {
      if (mutations[i].targetId == tempId) {
        mutations[i] = mutations[i].copyWith(targetId: realId);
        mutationsModified = true;
      }
    }
    if (mutationsModified) {
      await saveMutations(mutations);
    }
  }

  // ── AI Ready ──────────────────────────────────────────
  bool getAiReady() {
    return _prefs.getBool(_keyAiReady) ?? false;
  }

  Future<void> saveAiReady(bool ready) async {
    await _prefs.setBool(_keyAiReady, ready);
  }

  // ── Sync Queue (Mutations) ────────────────────────────
  List<SyncMutation> getMutations() {
    final raw = _prefs.getString(_keyMutations);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list.map((e) => SyncMutation.fromJson(Map<String, dynamic>.from(e as Map))).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveMutations(List<SyncMutation> mutations) async {
    final raw = jsonEncode(mutations.map((m) => m.toJson()).toList());
    await _prefs.setString(_keyMutations, raw);
  }

  Future<void> addMutation(SyncMutation mutation) async {
    final current = getMutations()..add(mutation);
    await saveMutations(current);
  }

  Future<void> removeMutation(String mutationId) async {
    final current = getMutations()..removeWhere((m) => m.id == mutationId);
    await saveMutations(current);
  }

  // ── Last Sync ─────────────────────────────────────────
  DateTime? getLastSyncTime() {
    final raw = _prefs.getString(_keyLastSync);
    if (raw == null || raw.isEmpty) return null;
    try {
      return DateTime.parse(raw);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveLastSyncTime(DateTime time) async {
    await _prefs.setString(_keyLastSync, time.toIso8601String());
  }

  Future<void> clearAll() async {
    await _prefs.remove(_keyProducts);
    await _prefs.remove(_keyLeads);
    await _prefs.remove(_keyAiReady);
    await _prefs.remove(_keyMutations);
    await _prefs.remove(_keyLastSync);
  }
}
