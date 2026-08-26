class SupplierResult {
  final int rank;
  final String storeName;
  final String location;
  final String distance;
  final double? distanceKm;
  final double price;
  final String unit;
  final double rating;
  final int ratingCount;
  final String stockBadge;
  final bool inStock;
  final bool isBestPrice;
  final String? imageUrl;
  final String? stockId;
  final String stockholderId;
  final String productName;
  final double quantityAvailable;

  const SupplierResult({
    required this.rank,
    required this.storeName,
    required this.location,
    required this.distance,
    this.distanceKm,
    required this.price,
    required this.unit,
    required this.rating,
    required this.ratingCount,
    required this.stockBadge,
    required this.inStock,
    this.isBestPrice = false,
    this.imageUrl,
    this.stockId,
    this.stockholderId = '',
    this.productName = 'Unnamed Product',
    this.quantityAvailable = 0,
  });

  factory SupplierResult.fromJson(Map<String, dynamic> json) {
    return SupplierResult(
      rank: _toInt(json['rank']),
      storeName: json['storeName'] as String? ?? 'Unknown',
      location: json['location'] as String? ?? 'Unknown',
      distance: json['distance'] as String? ?? 'N/A',
      distanceKm: json['distanceKm'] != null
          ? _toDouble(json['distanceKm'])
          : double.tryParse(
              (json['distance']?.toString() ?? '')
                  .replaceAll(RegExp(r'[^0-9.]'), ''),
            ),
      price: _toDouble(json['price']),
      unit: json['unit'] as String? ?? 'pcs',
      rating: _toDouble(json['rating'], 5.0),
      ratingCount: _toInt(json['ratingCount']),
      stockBadge: json['stockBadge'] as String? ?? 'In stock',
      inStock: json['inStock'] as bool? ?? true,
      isBestPrice: json['isBestPrice'] as bool? ?? false,
      imageUrl: (json['imageUrl'] as String?)?.replaceFirst('http://tradelink-2.onrender.com', 'https://tradelink-2.onrender.com'),
      stockId: json['stockId'] as String?,
      stockholderId: json['stockholderId'] as String? ?? json['stockholder_id'] as String? ?? '',
      productName: (json['productName'] as String?) ??
          (json['product_name'] as String?) ??
          (json['custom_product_name'] as String?) ??
          'Unnamed Product',
      quantityAvailable: _toDouble(json['quantityAvailable']),
    );
  }

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

  String get priceLabel => '৳${price.toStringAsFixed(0)} / $unit';

  double get priceDiffFromBest => price - _bestPrice;

  static const double _bestPrice = 64;

  String get diffLabel =>
      priceDiffFromBest == 0 ? '' : '+৳${priceDiffFromBest.toStringAsFixed(0)} vs best';

  static List<SupplierResult> mockForProduct(String product) {
    return const [
      SupplierResult(
        rank: 1,
        storeName: 'Manik Wholesale',
        location: 'Mirpur-10',
        distance: '1.4 km',
        price: 64,
        unit: 'kg',
        rating: 4.8,
        ratingCount: 120,
        stockBadge: 'In stock',
        inStock: true,
        isBestPrice: true,
      ),
      SupplierResult(
        rank: 2,
        storeName: 'New Bazar Store',
        location: 'Kazipara',
        distance: '2.3 km',
        price: 67,
        unit: 'kg',
        rating: 4.6,
        ratingCount: 85,
        stockBadge: 'In stock',
        inStock: true,
      ),
      SupplierResult(
        rank: 3,
        storeName: 'Alauddin Traders',
        location: 'Shewrapara',
        distance: '3.1 km',
        price: 69,
        unit: 'kg',
        rating: 4.5,
        ratingCount: 64,
        stockBadge: '2 left',
        inStock: true,
      ),
      SupplierResult(
        rank: 4,
        storeName: 'Khan Brothers',
        location: 'Kafrul',
        distance: '3.8 km',
        price: 71,
        unit: 'kg',
        rating: 4.4,
        ratingCount: 41,
        stockBadge: 'In stock',
        inStock: true,
      ),
    ];
  }

  @override
  String toString() => 'SupplierResult($rank, $storeName, ৳$price)';
}