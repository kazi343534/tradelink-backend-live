import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/api_service.dart';
import '../../models/marketplace_product_model.dart';
import 'direct_chat_screen.dart';

class ProductDetailScreen extends StatefulWidget {
  final MarketplaceProductModel product;
  final double shopLat;
  final double shopLng;

  const ProductDetailScreen({
    super.key,
    required this.product,
    required this.shopLat,
    required this.shopLng,
  });

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  final TextEditingController _quantityController = TextEditingController(text: '1');
  bool _isOrdering = false;
  List<Map<String, dynamic>> _reviews = [];
  bool _isLoadingReviews = true;

  @override
  void initState() {
    super.initState();
    _fetchProductReviews();
  }

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

  MarketplaceProductModel get product => widget.product;

  /// Confirmation gate: shows an order breakdown and only calls the API
  /// after the user explicitly taps "Confirm Order".
  Future<void> _showOrderConfirmationModal() async {
    final quantityText = _quantityController.text.trim();
    final quantity = double.tryParse(quantityText);
    if (quantity == null || quantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please enter a valid quantity'),
            backgroundColor: Colors.orange),
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final deliveryAddress =
        prefs.getString('user_address') ?? 'Selected shop location';
    if (!mounted) return;

    final unitPrice = product.pricePerUnit;
    final totalPrice = unitPrice * quantity;
    final unit = product.unit;
    final sellerName = product.supplierName;
    final sellerPhone =
        (product.supplierPhone?.isNotEmpty ?? false) ? product.supplierPhone! : 'N/A';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (modalContext) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(modalContext).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Confirm Order Details',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A)),
              ),
              const Divider(height: 24),
              _buildModalRow('Product Name', product.productName),
              _buildModalRow(
                  'Unit Price', '৳${unitPrice.toStringAsFixed(2)} / $unit'),
              _buildModalRow('Quantity', '$quantity $unit'),
              _buildModalRow('Total Price', '৳${totalPrice.toStringAsFixed(2)}',
                  isBold: true, color: const Color(0xFF0F766E)),
              const SizedBox(height: 8),
              _buildModalRow('Seller Name', sellerName),
              _buildModalRow('Phone Number', sellerPhone),
              _buildModalRow('Delivery Location', deliveryAddress),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(modalContext),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Cancel',
                          style: TextStyle(
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(modalContext);
                        _placeOrder();
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: const Color(0xFF0F4C3A),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Confirm Order',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildModalRow(String label, String value,
      {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(color: Color(0xFF64748B), fontSize: 14)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
                color: color ?? const Color(0xFF1E293B),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _fetchProductReviews() async {
    final data = await ApiService.get('/reviews/inventory/${product.stockId}/reviews');
    if (mounted) {
      setState(() {
        _reviews = data != null ? List<Map<String, dynamic>>.from(data) : [];
        _isLoadingReviews = false;
      });
    }
  }

  Widget _buildReviewsSection() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Reviews', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF111827))),
              const Spacer(),
              Text(
                product.ratingLabel,
                style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_isLoadingReviews)
            const Center(child: Padding(
              padding: EdgeInsets.all(12),
              child: CircularProgressIndicator(color: AppColors.primaryTeal, strokeWidth: 2),
            ))
          else if (_reviews.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('No reviews yet for this product.', style: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF))),
            )
          else
            ..._reviews.map(_buildReviewTile),
        ],
      ),
    );
  }

  Widget _buildReviewTile(Map<String, dynamic> review) {
    final rating = (review['rating'] as num?)?.toDouble() ?? 0;
    final comment = review['comment'] as String? ?? '';
    final reviewer = review['reviewerName'] as String? ?? 'Shop Owner';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ...List.generate(5, (i) {
                if (i < rating.floor()) {
                  return const Icon(Icons.star_rounded, size: 14, color: Color(0xFFF59E0B));
                }
                return const Icon(Icons.star_outline_rounded, size: 14, color: Color(0xFFD1D5DB));
              }),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  reviewer,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF374151)),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (comment.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(comment, style: const TextStyle(fontSize: 13, color: Color(0xFF4B5563))),
          ],
        ],
      ),
    );
  }

  Future<void> _placeOrder() async {
    final quantityText = _quantityController.text.trim();
    if (quantityText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a quantity'), backgroundColor: Colors.orange),
      );
      return;
    }

    final quantity = double.tryParse(quantityText);
    if (quantity == null || quantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid quantity'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isOrdering = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final deliveryAddress = prefs.getString('user_address') ?? '';

      final result = await ApiService.post('/orders/direct', body: {
        'stockId': product.stockId,
        'quantity': quantity,
        'deliveryAddress': deliveryAddress,
      });

      if (mounted) {
        setState(() => _isOrdering = false);
        if (result != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Order placed successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to place order'), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      debugPrint('[ProductDetail] Error placing order: $e');
      if (mounted) {
        setState(() => _isOrdering = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Chat with seller',
            icon: const Icon(Icons.forum_outlined, color: Color(0xFF374151)),
            onPressed: () async {
              final result = await ApiService.post('/chats/start', body: {
                'productId': product.stockId,
                'stockholderId': product.stockholderId,
              });
              if (!mounted) return;
              if (result != null && result['id'] != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DirectChatScreen(
                        chatId: result['id'].toString()),
                  ),
                );
              }
            },
          ),
        ],
        title: Text(
          product.productName,
          style: const TextStyle(color: Color(0xFF111827), fontWeight: FontWeight.w700, fontSize: 18),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF374151)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildProductImage(),
            _buildProductInfo(),
            _buildSupplierCard(),
            _buildDeliveryInfo(),
            _buildReviewsSection(),
            const SizedBox(height: 100),
          ],
        ),
      ),
      bottomSheet: _buildOrderSection(),
    );
  }

  Widget _buildProductImage() {
    return Container(
      width: double.infinity,
      height: 220,
      color: Colors.white,
      child: product.imageUrl != null && product.imageUrl!.isNotEmpty
          ? Image.network(
              product.imageUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _buildPlaceholderImage(),
            )
          : _buildPlaceholderImage(),
    );
  }

  Widget _buildPlaceholderImage() {
    return Container(
      color: const Color(0xFFEEF8F6),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.inventory_2_outlined, size: 64, color: Color(0xFF0F766E)),
            const SizedBox(height: 8),
            Text(
              product.productName,
              style: const TextStyle(fontSize: 16, color: Color(0xFF64748B)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductInfo() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            product.productName,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Color(0xFF111827)),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildInfoChip(Icons.category_outlined, product.category),
              const SizedBox(width: 8),
              _buildInfoChip(Icons.straighten, product.unit),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Price', style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                  Text(
                    product.priceLabel,
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: Color(0xFF111827)),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('Available', style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                  Text(
                    '${product.quantityAvailable.toStringAsFixed(0)} ${product.unit}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: product.inStock ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF6B7280)),
          const SizedBox(width: 4),
          Text(text, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
        ],
      ),
    );
  }

  Widget _buildSupplierCard() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Supplier', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF111827))),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primaryTeal.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    product.supplierName.isNotEmpty ? product.supplierName[0].toUpperCase() : '?',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.primaryTeal),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.supplierName,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF111827)),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        ...List.generate(5, (i) {
                          if (i < product.rating.floor()) {
                            return const Icon(Icons.star_rounded, size: 16, color: Color(0xFFF59E0B));
                          } else if (i < product.rating) {
                            return const Icon(Icons.star_half_rounded, size: 16, color: Color(0xFFF59E0B));
                          }
                          return const Icon(Icons.star_outline_rounded, size: 16, color: Color(0xFFD1D5DB));
                        }),
                        const SizedBox(width: 6),
                        Text(
                          product.ratingLabel,
                          style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      product.warehouseAddress ?? 'Address not available',
                      style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryInfo() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Delivery Information', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF111827))),
          const SizedBox(height: 12),
          _buildInfoRow(Icons.location_on_outlined, 'Distance', product.distanceLabel),
          const SizedBox(height: 8),
          _buildInfoRow(Icons.delivery_dining_outlined, 'Delivery Radius', '${product.deliveryRadiusKm} km'),
          const SizedBox(height: 8),
          _buildInfoRow(Icons.check_circle_outline, 'Status', product.stockLabel),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.primaryTeal),
        const SizedBox(width: 12),
        Text(label, style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280))),
        const Spacer(),
        Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF111827))),
      ],
    );
  }

  Widget _buildOrderSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: TextField(
                controller: _quantityController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Quantity',
                  hintText: '1',
                  suffixText: product.unit,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 3,
              child: SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed:
                      (_isOrdering || !product.inStock) ? null : _showOrderConfirmationModal,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryTeal,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFFD1D5DB),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isOrdering
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : Text(
                          product.inStock ? 'Place Order' : 'Out of Stock',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
