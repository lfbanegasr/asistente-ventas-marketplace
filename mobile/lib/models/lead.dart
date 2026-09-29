class Lead {
  const Lead({
    required this.id,
    this.requestId,
    this.channel = 'Marketplace',
    required this.productId,
    this.productName = '',
    required this.alias,
    this.status = 'consulta',
    required this.amount,
    required this.actualCost,
    this.expenses = 0,
    this.deliveryMode = 'por_definir',
    this.deliveryPlace = '',
    this.deliveryAt = '',
    this.paid = false,
    this.notes = '',
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String? requestId;
  final String channel;
  final String productId;
  final String productName;
  final String alias;
  final String status;
  final int amount;
  final int actualCost;
  final int expenses;
  final String deliveryMode;
  final String deliveryPlace;
  final String deliveryAt;
  final bool paid;
  final String notes;
  final String? createdAt;
  final String? updatedAt;

  int get netMargin => amount - actualCost - expenses;

  bool get isDelivered => status == 'entregado';
  bool get isCancelled => status == 'cancelado';
  bool get isOpen => !isDelivered && !isCancelled;
  bool get isConfirmed => ['confirmado', 'comprado', 'agendado'].contains(status);

  bool get hasDeliveryDate => deliveryAt.trim().isNotEmpty;

  DateTime? get parsedDeliveryDate {
    if (!hasDeliveryDate) return null;
    try {
      return DateTime.parse(deliveryAt.length > 10 ? deliveryAt : '${deliveryAt}T12:00:00');
    } catch (_) {
      return null;
    }
  }

  bool isScheduledForDate(DateTime date) {
    final dt = parsedDeliveryDate;
    if (dt == null) return false;
    return dt.year == date.year && dt.month == date.month && dt.day == date.day;
  }

  bool get isScheduledToday {
    return isScheduledForDate(DateTime.now());
  }

  String get statusLabel {
    switch (status) {
      case 'consulta':
        return 'Consulta';
      case 'interesado':
        return 'Interesado';
      case 'confirmado':
        return 'Confirmado';
      case 'comprado':
        return 'Comprado';
      case 'agendado':
        return 'Agendado';
      case 'entregado':
        return 'Entregado';
      case 'cancelado':
        return 'Cancelado';
      default:
        return status;
    }
  }

  String get deliveryModeLabel {
    switch (deliveryMode) {
      case 'persona':
        return 'En persona';
      case 'yango':
        return 'Yango / Moto';
      case 'por_definir':
      default:
        return 'Por definir';
    }
  }

  factory Lead.fromJson(Map<String, dynamic> json) {
    return Lead(
      id: json['id'] as String? ?? '',
      requestId: json['request_id'] as String?,
      channel: json['channel'] as String? ?? 'Marketplace',
      productId: json['product_id'] as String? ?? '',
      productName: json['product_name'] as String? ?? '',
      alias: json['alias'] as String? ?? '',
      status: json['status'] as String? ?? 'consulta',
      amount: (json['amount'] as num?)?.toInt() ?? 0,
      actualCost: (json['actual_cost'] as num?)?.toInt() ?? 0,
      expenses: (json['expenses'] as num?)?.toInt() ?? 0,
      deliveryMode: json['delivery_mode'] as String? ?? 'por_definir',
      deliveryPlace: json['delivery_place'] as String? ?? '',
      deliveryAt: json['delivery_at'] as String? ?? '',
      paid: json['paid'] == 1 || json['paid'] == true,
      notes: json['notes'] as String? ?? '',
      createdAt: json['created_at'] as String?,
      updatedAt: json['updated_at'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      if (requestId != null) 'request_id': requestId,
      'channel': channel,
      'product_id': productId,
      'product_name': productName,
      'alias': alias,
      'status': status,
      'amount': amount,
      'actual_cost': actualCost,
      'expenses': expenses,
      'delivery_mode': deliveryMode,
      'delivery_place': deliveryPlace,
      'delivery_at': deliveryAt,
      'paid': paid ? 1 : 0,
      'notes': notes,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    };
  }

  Lead copyWith({
    String? id,
    String? requestId,
    String? channel,
    String? productId,
    String? productName,
    String? alias,
    String? status,
    int? amount,
    int? actualCost,
    int? expenses,
    String? deliveryMode,
    String? deliveryPlace,
    String? deliveryAt,
    bool? paid,
    String? notes,
    String? createdAt,
    String? updatedAt,
  }) {
    return Lead(
      id: id ?? this.id,
      requestId: requestId ?? this.requestId,
      channel: channel ?? this.channel,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      alias: alias ?? this.alias,
      status: status ?? this.status,
      amount: amount ?? this.amount,
      actualCost: actualCost ?? this.actualCost,
      expenses: expenses ?? this.expenses,
      deliveryMode: deliveryMode ?? this.deliveryMode,
      deliveryPlace: deliveryPlace ?? this.deliveryPlace,
      deliveryAt: deliveryAt ?? this.deliveryAt,
      paid: paid ?? this.paid,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
