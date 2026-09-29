class SyncMutation {
  const SyncMutation({
    required this.id,
    required this.type,
    required this.targetId,
    required this.payload,
    required this.createdAt,
    this.retryCount = 0,
    this.error,
  });

  final String id;
  final String type; // 'create_lead' | 'update_lead' | 'delete_lead' | 'save_product' | 'delete_product'
  final String targetId;
  final Map<String, dynamic> payload;
  final DateTime createdAt;
  final int retryCount;
  final String? error;

  bool get isLeadMutation =>
      type == 'create_lead' || type == 'update_lead' || type == 'delete_lead';

  bool get isProductMutation =>
      type == 'save_product' || type == 'delete_product';

  factory SyncMutation.fromJson(Map<String, dynamic> json) {
    return SyncMutation(
      id: json['id'] as String,
      type: json['type'] as String,
      targetId: json['target_id'] as String,
      payload: Map<String, dynamic>.from(json['payload'] as Map),
      createdAt: DateTime.parse(json['created_at'] as String),
      retryCount: (json['retry_count'] as num?)?.toInt() ?? 0,
      error: json['error'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'target_id': targetId,
      'payload': payload,
      'created_at': createdAt.toIso8601String(),
      'retry_count': retryCount,
      if (error != null) 'error': error,
    };
  }

  SyncMutation copyWith({
    String? id,
    String? type,
    String? targetId,
    Map<String, dynamic>? payload,
    DateTime? createdAt,
    int? retryCount,
    String? error,
  }) {
    return SyncMutation(
      id: id ?? this.id,
      type: type ?? this.type,
      targetId: targetId ?? this.targetId,
      payload: payload ?? this.payload,
      createdAt: createdAt ?? this.createdAt,
      retryCount: retryCount ?? this.retryCount,
      error: error ?? this.error,
    );
  }
}
