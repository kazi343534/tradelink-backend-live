class MarketplaceProductModel {
  final String stockId;
  final String stockholderId;
  final String supplierName;
  final String? supplierPhone;
  final String? warehouseAddress;
  final double? supplierLat;
  final double? supplierLng;
  final String productName;
  final String category;
  final double pricePerUnit;
  final double quantityAvailable;
  final String unit;
  final String? imageUrl;
  final int deliveryRadiusKm;
  final double distanceKm;
  final double? priceDifference;
  final double rating;
  final int ratingCount;

  const MarketplaceProductModel({
    required this.stockId,
    required this.stockholderId,
    required this.supplierName,
    this.supplierPhone,
    this.warehouseAddress,
    this.supplierLat,
    this.supplierLng,
    required this.productName,
    required this.category,
    required this.pricePerUnit,
    required this.quantityAvailable,
    required this.unit,
    this.imageUrl,
    required this.deliveryRadiusKm,
    required this.distanceKm,
    this.priceDifference,
    this.rating = 0,
    this.ratingCount = 0,
  });

  /// Safely parse a value that may be num or String (PostgreSQL DECIMAL returns strings).
  static double _toDouble(dynamic value, [double fallback = 0.0]) {
    if (value == null) return fallback;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? fallback;
    return fallback;
  }

  static int _toInt(dynamic value, [int fallback = 0]) {
    if (value == null) return fallback;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

  factory MarketplaceProductModel.fromJson(Map<String, dynamic> json) {
    return MarketplaceProductModel(
      stockId: json['stockId'] as String? ?? json['stock_id'] as String? ?? '',
      stockholderId: json['stockholderId'] as String? ?? json['stockholder_id'] as String? ?? '',
      supplierName: json['supplierName'] as String? ?? json['supplier_name'] as String? ?? 'Unknown Supplier',
      supplierPhone: json['supplierPhone'] as String? ?? json['supplier_phone'] as String?,
      warehouseAddress: json['warehouseAddress'] as String? ?? json['warehouse_address'] as String?,
      supplierLat: _toDouble(json['supplierLat'] ?? json['supplier_lat']),
      supplierLng: _toDouble(json['supplierLng'] ?? json['supplier_lng']),
      productName: json['productName'] as String? ?? json['product_name'] as String? ?? 'Unknown Product',
      category: json['category'] as String? ?? 'General',
      pricePerUnit: _toDouble(json['pricePerUnit'] ?? json['price_per_unit']),
      quantityAvailable: _toDouble(json['quantityAvailable'] ?? json['quantity_available']),
      unit: json['unit'] as String? ?? 'pcs',
      imageUrl: (json['imageUrl'] as String? ?? json['image_url'] as String?)?.replaceFirst('http://tradelink-2.onrender.com', 'https://tradelink-2.onrender.com'),
      deliveryRadiusKm: _toInt(json['deliveryRadiusKm'] ?? json['delivery_radius_km'], 50),
      distanceKm: _toDouble(json['distanceKm'] ?? json['distance_km']),
      priceDifference: _toDouble(json['priceDifference'] ?? json['price_difference']),
      rating: _toDouble(json['rating'] ?? json['avg_rating']),
      ratingCount: _toInt(json['ratingCount'] ?? json['rating_count']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'stockId': stockId,
      'stockholderId': stockholderId,
      'supplierName': supplierName,
      'warehouseAddress': warehouseAddress,
      'supplierLat': supplierLat,
      'supplierLng': supplierLng,
      'productName': productName,
      'category': category,
      'pricePerUnit': pricePerUnit,
      'quantityAvailable': quantityAvailable,
      'unit': unit,
      'imageUrl': imageUrl,
      'deliveryRadiusKm': deliveryRadiusKm,
      'distanceKm': distanceKm,
      'priceDifference': priceDifference,
      'rating': rating,
      'ratingCount': ratingCount,
    };
  }

  String get priceLabel => '৳${pricePerUnit.toStringAsFixed(0)} / $unit';
  
  String get distanceLabel => '${distanceKm.toStringAsFixed(1)} km away';
  
  String get stockLabel {
    if (quantityAvailable <= 0) return 'Out of stock';
    if (quantityAvailable < 5) return '${quantityAvailable.toStringAsFixed(0)} left';
    return 'In stock';
  }

  bool get inStock => quantityAvailable > 0;

  String get ratingLabel {
    if (ratingCount == 0) return 'No reviews';
    return '${rating.toStringAsFixed(1)} ($ratingCount)';
  }

  String? get diffLabel {
    if (priceDifference == null || priceDifference == 0) return null;
    return '+৳${priceDifference!.toStringAsFixed(0)} vs best';
  }
}

class MarketplaceSearchResponse {
  final List<MarketplaceProductModel> products;
  final int total;
  final bool hasMore;

  const MarketplaceSearchResponse({
    required this.products,
    required this.total,
    required this.hasMore,
  });

  factory MarketplaceSearchResponse.fromJson(Map<String, dynamic> json) {
    return MarketplaceSearchResponse(
      products: (json['products'] as List<dynamic>?)
              ?.map((e) => MarketplaceProductModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      total: json['total'] as int? ?? 0,
      hasMore: json['hasMore'] as bool? ?? false,
    );
  }
}