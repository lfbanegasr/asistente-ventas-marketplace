class Product {
  const Product({
    required this.id,
    required this.name,
    this.facts = '',
    required this.cost,
    required this.price,
    required this.minPrice,
    this.availability = 'por_confirmar',
    this.availableUnits = 0,
    this.readyDate = '',
    this.isActive = true,
    this.availabilityCheckedAt,
  });

  final String id;
  final String name;
  final String facts;
  final int cost;
  final int price;
  final int minPrice;
  final String availability;
  final int availableUnits;
  final String readyDate;
  final bool isActive;
  final String? availabilityCheckedAt;

  bool get isInHand => availability == 'en_mano';
  bool get isSupplierConfirmed => availability == 'proveedor_confirmado';
  bool get isPendingConfirmation => availability == 'por_confirmar';

  String get availabilityLabel {
    switch (availability) {
      case 'en_mano':
        return 'En mano';
      case 'proveedor_confirmado':
        return 'Proveedor confirmó';
      case 'por_confirmar':
      default:
        return 'Por confirmar';
    }
  }

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      facts: json['facts'] as String? ?? '',
      cost: (json['cost'] as num?)?.toInt() ?? 0,
      price: (json['price'] as num?)?.toInt() ?? 0,
      minPrice: (json['min_price'] as num?)?.toInt() ?? 0,
      availability: json['availability'] as String? ?? 'por_confirmar',
      availableUnits: (json['available_units'] as num?)?.toInt() ?? 0,
      readyDate: json['ready_date'] as String? ?? '',
      isActive: json['is_active'] == null || json['is_active'] == true || json['is_active'] == 1,
      availabilityCheckedAt: json['availability_checked_at'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'facts': facts,
      'cost': cost,
      'price': price,
      'min_price': minPrice,
      'availability': availability,
      'available_units': availableUnits,
      'ready_date': readyDate,
      'is_active': isActive,
      if (availabilityCheckedAt != null) 'availability_checked_at': availabilityCheckedAt,
    };
  }

  Product copyWith({
    String? id,
    String? name,
    String? facts,
    int? cost,
    int? price,
    int? minPrice,
    String? availability,
    int? availableUnits,
    String? readyDate,
    bool? isActive,
    String? availabilityCheckedAt,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      facts: facts ?? this.facts,
      cost: cost ?? this.cost,
      price: price ?? this.price,
      minPrice: minPrice ?? this.minPrice,
      availability: availability ?? this.availability,
      availableUnits: availableUnits ?? this.availableUnits,
      readyDate: readyDate ?? this.readyDate,
      isActive: isActive ?? this.isActive,
      availabilityCheckedAt: availabilityCheckedAt ?? this.availabilityCheckedAt,
    );
  }
}
