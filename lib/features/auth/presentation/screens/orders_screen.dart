import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/api_service.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _orders = [];

  @override
  void initState() {
    super.initState();
    _fetchOrders();
  }

  Future<void> _fetchOrders() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');
      if (userId == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final data = await ApiService.get('/orders/shop-owner');

      if (mounted) {
        if (data != null) {
          setState(() {
            _orders = List<Map<String, dynamic>>.from(data ?? []);
            _isLoading = false;
          });
        } else {
          setState(() => _isLoading = false);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to fetch orders: $e'), backgroundColor: AppColors.cancelled),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'My Orders',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
            ),
            if (!_isLoading)
              Text(
                '${_orders.length} order${_orders.length == 1 ? '' : 's'}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF64748B),
                ),
              ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF0F5C4F)))
          : RefreshIndicator(
              onRefresh: _fetchOrders,
              color: const Color(0xFF0F5C4F),
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                children: [
                  if (_orders.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.inputBorder),
                      ),
                      child: const Center(
                        child: Text('No orders yet', style: TextStyle(fontSize: 14, color: Color(0xFF9CA3AF))),
                      ),
                    )
                  else
                    ..._orders.map((order) => _ShopOwnerOrderCard(
                          orderId: order['orderId'] ?? '',
                          supplierName: order['supplierName'] ?? 'Supplier',
                          productName: order['productName'] ?? 'Unknown',
                          quantity: order['quantity'] ?? 0,
                          unit: order['unit'] ?? '',
                          totalAmount: order['totalAmount'] ?? 0,
                          status: order['status'] ?? 'pending',
                          deliveryOtp: order['deliveryOtp'],
                          deliveryAddress: order['deliveryAddress'],
                          orderTime: order['orderTime'] ?? '',
                        )),
                ],
              ),
            ),
    );
  }
}

class _ShopOwnerOrderCard extends StatelessWidget {
  final String orderId;
  final String supplierName;
  final String productName;
  final dynamic quantity;
  final String unit;
  final dynamic totalAmount;
  final String status;
  final String? deliveryOtp;
  final String? deliveryAddress;
  final String orderTime;

  const _ShopOwnerOrderCard({
    required this.orderId,
    required this.supplierName,
    required this.productName,
    required this.quantity,
    required this.unit,
    required this.totalAmount,
    required this.status,
    this.deliveryOtp,
    this.deliveryAddress,
    required this.orderTime,
  });

  Color get _statusColor {
    switch (status) {
      case 'accepted':
        return const Color(0xFFF59E0B);
      case 'out_for_delivery':
        return const Color(0xFF3B82F6);
      case 'in_transit':
        return const Color(0xFF3B82F6);
      case 'delivered':
        return const Color(0xFF10B981);
      case 'cancelled':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF6B7280);
    }
  }

  String get _statusLabel {
    switch (status) {
      case 'accepted':
        return 'Accepted';
      case 'out_for_delivery':
        return 'Out for Delivery';
      case 'in_transit':
        return 'In Transit';
      case 'delivered':
        return 'Delivered';
      case 'cancelled':
        return 'Cancelled';
      default:
        return 'Pending';
    }
  }

  String _formatTime(String isoTime) {
    if (isoTime.isEmpty) return '';
    try {
      final dt = DateTime.parse(isoTime);
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      return '${diff.inDays}d ago';
    } catch (_) {
      return isoTime;
    }
  }

  String get _qtyLabel {
    if (quantity is num) {
      final q = quantity as num;
      return q == q.roundToDouble() ? q.toInt().toString() : q.toStringAsFixed(1);
    }
    return '$quantity';
  }

  String get _totalLabel {
    if (totalAmount is num) return '৳${(totalAmount as num).toStringAsFixed(2)}';
    return '৳$totalAmount';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.inputBorder),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  '$productName ($_qtyLabel $unit)',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _statusLabel,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _statusColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'From: $supplierName',
            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 4),
          Text(
            'Total: $_totalLabel',
            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 4),
          Text(
            'Ordered: ${_formatTime(orderTime)}',
            style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
          ),
          if (deliveryAddress != null && deliveryAddress!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Delivery: $deliveryAddress',
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
          ],

          // OTP section for out_for_delivery status
          if (status == 'out_for_delivery' || status == 'in_transit') ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Column(
                children: [
                  const Icon(Icons.local_shipping_outlined, size: 20, color: Color(0xFFD97706)),
                  const SizedBox(height: 6),
                  const Text(
                    'Delivery is on the way!',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF92400E),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (deliveryOtp != null && deliveryOtp!.isNotEmpty) ...[
                    const Text(
                      'Your delivery OTP:',
                      style: TextStyle(fontSize: 11, color: Color(0xFF92400E)),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFF59E0B)),
                      ),
                      child: Text(
                        deliveryOtp!,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 6,
                          color: Color(0xFFD97706),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFF59E0B)),
                      ),
                      child: Column(
                        children: [
                          QrImageView(
                            data: deliveryOtp!,
                            size: 140,
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF0F172A),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Show this QR code to the delivery person to confirm delivery.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 11, color: Color(0xFF92400E)),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    const Text(
                      'OTP will appear here once the supplier marks out for delivery.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11, color: Color(0xFF92400E)),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
