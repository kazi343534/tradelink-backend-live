import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/api_service.dart';
import '../../models/marketplace_product_model.dart';
import '../../services/marketplace_service.dart';
import '../../widgets/bargain_sheet.dart';
import 'product_detail_screen.dart';
import 'direct_chat_screen.dart';
import 'conversations_screen.dart';
import 'shop_owner_bargains_screen.dart';

class MarketplaceSearchScreen extends StatefulWidget {
  const MarketplaceSearchScreen({super.key});

  @override
  State<MarketplaceSearchScreen> createState() => _MarketplaceSearchScreenState();
}

class _MarketplaceSearchScreenState extends State<MarketplaceSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<MarketplaceProductModel> _products = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _offset = 0;
  String _selectedCategory = 'All';
  String _sortBy = 'distance';

  double? _shopLat;
  double? _shopLng;
  bool _locationLoaded = false;

  final List<String> _categories = [
    'All', 'Grocery', 'Pharmacy', 'Hardware', 'Stationery',
  ];

  final Map<String, String> _sortOptions = {
    'distance': 'Nearest',
    'price': 'Lowest Price',
    'rating': 'Top Rated',
  };

  @override
  void initState() {
    super.initState();
    _loadUserLocation();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadUserLocation() async {
    // Try to load from SharedPreferences first (fast)
    final prefs = await SharedPreferences.getInstance();
    final savedLat = prefs.getDouble('user_latitude');
    final savedLng = prefs.getDouble('user_longitude');

    if (savedLat != null && savedLng != null) {
      if (mounted) {
        setState(() {
          _shopLat = savedLat;
          _shopLng = savedLng;
          _locationLoaded = true;
        });
      }
      _loadProducts();
      return;
    }

    // Try GPS
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          setState(() => _locationLoaded = true);
        }
        // Load products without location (uses default coordinates)
        _loadProducts();
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            setState(() => _locationLoaded = true);
          }
          _loadProducts();
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() => _locationLoaded = true);
        }
        _loadProducts();
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      if (mounted) {
        setState(() {
          _shopLat = position.latitude;
          _shopLng = position.longitude;
          _locationLoaded = true;
        });
      }

      // Save to SharedPreferences for future use
      await prefs.setDouble('user_latitude', position.latitude);
      await prefs.setDouble('user_longitude', position.longitude);

      _loadProducts();
    } catch (e) {
      debugPrint('[Marketplace] Error loading location: $e');
      if (mounted) {
        setState(() => _locationLoaded = true);
      }
      // Load products anyway with default coordinates
      _loadProducts();
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoading && _hasMore) {
        _loadProducts(loadMore: true);
      }
    }
  }

  Future<void> _loadProducts({bool loadMore = false}) async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      if (!loadMore) {
        _offset = 0;
        _products = [];
      }
    });

    try {
      final query = _searchController.text.trim();

      final response = await MarketplaceService.searchProducts(
        query: query.isNotEmpty ? query : null,
        shopLat: _shopLat,
        shopLng: _shopLng,
        category: _selectedCategory == 'All' ? null : _selectedCategory,
        sortBy: _sortBy,
        limit: 50,
        offset: _offset,
      );

      if (mounted) {
        setState(() {
          if (loadMore) {
            _products.addAll(response.products);
          } else {
            _products = response.products;
          }
          _hasMore = response.hasMore;
          _offset += response.products.length;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[Marketplace] Load error: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _onCategoryChanged(String category) {
    setState(() {
      _selectedCategory = category;
      _offset = 0;
      _products = [];
    });
    _loadProducts();
  }

  void _onSortChanged(String sort) {
    setState(() {
      _sortBy = sort;
      _offset = 0;
      _products = [];
    });
    _loadProducts();
  }

  void _onSearchSubmitted() {
    setState(() {
      _offset = 0;
      _products = [];
    });
    _loadProducts();
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _offset = 0;
      _products = [];
    });
    _loadProducts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Marketplace',
          style: TextStyle(color: Color(0xFF111827), fontWeight: FontWeight.w700),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF374151)),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            tooltip: 'Chats',
            icon: const Icon(Icons.chat_bubble_outline,
                color: Color(0xFF374151)),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const ConversationsScreen()),
              );
            },
          ),
          IconButton(
            tooltip: 'My Bargains',
            icon: const Icon(Icons.handshake_outlined, color: Color(0xFF374151)),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const ShopOwnerBargainsScreen()),
              );
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          _buildFilterChips(),
          Expanded(child: _buildResults()),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search products (e.g., Rice, Napa, Nails)',
          hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
          prefixIcon: const Icon(Icons.search, color: Color(0xFF9CA3AF)),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: Color(0xFF9CA3AF)),
                  onPressed: _clearSearch,
                )
              : null,
          filled: true,
          fillColor: const Color(0xFFF3F4F6),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        onSubmitted: (_) => _onSearchSubmitted(),
        onChanged: (_) => setState(() {}),
      ),
    );
  }

  Widget _buildFilterChips() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Colors.white,
      child: Column(
        children: [
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _categories.length,
              separatorBuilder: (_, _a) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final category = _categories[index];
                final isSelected = _selectedCategory == category;
                return FilterChip(
                  label: Text(
                    category,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : const Color(0xFF6B7280),
                    ),
                  ),
                  selected: isSelected,
                  selectedColor: AppColors.primaryTeal,
                  backgroundColor: const Color(0xFFF3F4F6),
                  checkmarkColor: Colors.white,
                  onSelected: (_) => _onCategoryChanged(category),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text(
                'Sort by:',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF6B7280),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 36,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _sortOptions.length,
                    separatorBuilder: (_, _a) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final entry = _sortOptions.entries.elementAt(index);
                      final isSelected = _sortBy == entry.key;
                      return ChoiceChip(
                        label: Text(
                          entry.value,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: isSelected ? AppColors.primaryTeal : const Color(0xFF6B7280),
                          ),
                        ),
                        selected: isSelected,
                        backgroundColor: const Color(0xFFF3F4F6),
                        selectedColor: AppColors.primaryTeal.withValues(alpha: 0.1),
                        onSelected: (_) => _onSortChanged(entry.key),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: isSelected ? AppColors.primaryTeal : const Color(0xFFE5E7EB),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResults() {
    if (!_locationLoaded || (_isLoading && _products.isEmpty)) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppColors.primaryTeal),
            SizedBox(height: 16),
            Text(
              'Loading nearby products...',
              style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
            ),
          ],
        ),
      );
    }

    if (_products.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.storefront_outlined, size: 48, color: Color(0xFF9CA3AF)),
              ),
              const SizedBox(height: 16),
              const Text(
                'No products available nearby',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF111827)),
              ),
              const SizedBox(height: 8),
              const Text(
                'Try adjusting your search or category filters',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  _searchController.clear();
                  setState(() {
                    _selectedCategory = 'All';
                    _sortBy = 'distance';
                    _offset = 0;
                    _products = [];
                  });
                  _loadProducts();
                },
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Reset Filters'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryTeal,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text(
            '${_products.length} product${_products.length == 1 ? '' : 's'} available',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF6B7280),
            ),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              _offset = 0;
              await _loadProducts();
            },
            color: AppColors.primaryTeal,
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              itemCount: _products.length + (_hasMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _products.length) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(color: AppColors.primaryTeal),
                    ),
                  );
                }
                return _buildProductCard(_products[index]);
              },
            ),
          ),
        ),
      ],
    );
  }

  /// Starts (or fetches) a chat thread for this product's supplier and
  /// opens the direct conversation.
  Future<void> _startChatWithSeller(MarketplaceProductModel product) async {
    final result = await ApiService.post('/chats/start', body: {
      'productId': product.stockId,
      'stockholderId': product.stockholderId,
    });
    if (!mounted) return;
    if (result != null && result['id'] != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DirectChatScreen(chatId: result['id'].toString()),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Could not start chat. Try again.'),
          backgroundColor: Colors.orange));
    }
  }

  Widget _buildProductCard(MarketplaceProductModel product) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProductDetailScreen(
              product: product,
              shopLat: _shopLat ?? 23.777176,
              shopLng: _shopLng ?? 90.399451,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E7EB)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            _buildProductImage(product),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.productName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF111827),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      product.supplierName,
                      style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                    ),
                    const SizedBox(height: 4),
                    _buildRatingRow(product),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.location_on_outlined, size: 14, color: AppColors.primaryTeal),
                        const SizedBox(width: 4),
                        Text(
                          product.distanceLabel,
                          style: TextStyle(fontSize: 12, color: AppColors.primaryTeal),
                        ),
                        const SizedBox(width: 12),
                        Icon(Icons.access_time, size: 14, color: const Color(0xFF9CA3AF)),
                        const SizedBox(width: 4),
                        Text(
                          '${product.deliveryRadiusKm} km radius',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          product.priceLabel,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF111827),
                          ),
                        ),
                        _buildStockBadge(product),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Action row: Chat | Buy Now | Negotiate
                    Row(
                      children: [
                        SizedBox(
                          width: 34,
                          height: 34,
                          child: IconButton.filledTonal(
                            tooltip: 'Chat with seller',
                            onPressed: product.inStock || true
                                ? () => _startChatWithSeller(product)
                                : null,
                            icon: const Icon(Icons.forum_outlined, size: 16),
                            style: IconButton.styleFrom(
                              backgroundColor: const Color(0xFFEEF8F6),
                              foregroundColor: AppColors.primaryTeal,
                              padding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: SizedBox(
                            height: 34,
                            child: OutlinedButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ProductDetailScreen(
                                      product: product,
                                      shopLat: _shopLat ?? 23.777176,
                                      shopLng: _shopLng ?? 90.399451,
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.shopping_cart_outlined,
                                  size: 14),
                              label: const Text('Buy Now',
                                  style: TextStyle(fontSize: 12)),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.primaryTeal,
                                side: const BorderSide(
                                    color: AppColors.primaryTeal, width: 1),
                                padding: EdgeInsets.zero,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: SizedBox(
                            height: 34,
                            child: ElevatedButton.icon(
                              onPressed: product.inStock
                                  ? () => showBargainSheet(context, product)
                                  : null,
                              icon: const Icon(Icons.handshake_outlined,
                                  size: 14),
                              label: const Text('Negotiate',
                                  style: TextStyle(fontSize: 12)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryTeal,
                                foregroundColor: Colors.white,
                                disabledBackgroundColor:
                                    const Color(0xFFD1D5DB),
                                elevation: 0,
                                padding: EdgeInsets.zero,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductImage(MarketplaceProductModel product) {
    return Container(
      width: 100,
      height: 100,
      decoration: const BoxDecoration(
        color: Color(0xFFF3F4F6),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16),
          bottomLeft: Radius.circular(16),
        ),
      ),
      child: product.imageUrl != null && product.imageUrl!.isNotEmpty
          ? ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                bottomLeft: Radius.circular(16),
              ),
              child: Image.network(
                product.imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, _a, _b) => _buildImagePlaceholder(),
              ),
            )
          : _buildImagePlaceholder(),
    );
  }

  Widget _buildImagePlaceholder() {
    return Center(
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: const Color(0xFFEEF8F6),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.inventory_2_outlined, size: 32, color: Color(0xFF0F766E)),
      ),
    );
  }

  Widget _buildRatingRow(MarketplaceProductModel product) {
    return Row(
      children: [
        ...List.generate(5, (i) {
          if (i < product.rating.floor()) {
            return const Icon(Icons.star_rounded, size: 14, color: Color(0xFFF59E0B));
          } else if (i < product.rating) {
            return const Icon(Icons.star_half_rounded, size: 14, color: Color(0xFFF59E0B));
          }
          return const Icon(Icons.star_outline_rounded, size: 14, color: Color(0xFFD1D5DB));
        }),
        const SizedBox(width: 4),
        Text(
          product.ratingLabel,
          style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
        ),
      ],
    );
  }

  Widget _buildStockBadge(MarketplaceProductModel product) {
    Color bgColor;
    Color textColor;
    String text = product.stockLabel;

    if (product.quantityAvailable <= 0) {
      bgColor = const Color(0xFFFEF2F2);
      textColor = const Color(0xFFEF4444);
    } else if (product.quantityAvailable < 5) {
      bgColor = const Color(0xFFFFFBEB);
      textColor = const Color(0xFFF59E0B);
    } else {
      bgColor = const Color(0xFFECFDF5);
      textColor = const Color(0xFF10B981);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: textColor),
      ),
    );
  }
}
