import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/services/api_service.dart';
import 'track_rider_screen.dart';
import '../../../../core/config/api_config.dart';

const Color _primaryTeal = Color(0xFF0E7966);
const Color _softSlateBg = Color(0xFFF8FAFC);
const Color _darkText = Color(0xFF0F172A);
const Color _mutedLabel = Color(0xFF64748B);
const Color _borderGray = Color(0xFFE2E8F0);
const Color _lightGrayBox = Color(0xFFF1F5F9);

class PendingOrdersScreen extends StatefulWidget {
  final bool embedded;
  const PendingOrdersScreen({super.key, this.embedded = false});

  @override
  State<PendingOrdersScreen> createState() => _PendingOrdersScreenState();
}

class _PendingOrdersScreenState extends State<PendingOrdersScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _orders = [];
  bool _isActionInProgress = false;

  bool _isLoadingCompleted = true;
  String? _errorCompleted;
  List<Map<String, dynamic>> _completedOrders = [];

  late final TabController _tabController;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchPendingOrders();
    _fetchCompletedOrders();
    _startPolling();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _pollTimer?.cancel();
    super.dispose();
  }

  void _startPolling() {
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) {
        _fetchPendingOrders(showLoading: false);
        _fetchCompletedOrders(showLoading: false);
      }
    });
  }

  Future<void> _fetchPendingOrders({bool showLoading = true}) async {
    if (showLoading && mounted) setState(() { _isLoading = true; _error = null; });
    final data = await ApiService.get('/orders/pending');
    if (data != null && mounted) {
      setState(() {
        _orders = List<Map<String, dynamic>>.from(data);
        _isLoading = false;
      });
    } else if (mounted && showLoading) {
      setState(() {
        _error = 'Failed to load orders. Pull to refresh.';
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchCompletedOrders({bool showLoading = true}) async {
    if (showLoading && mounted) setState(() { _isLoadingCompleted = true; _errorCompleted = null; });
    final data = await ApiService.get('/orders/completed');
    if (data != null && mounted) {
      setState(() {
        _completedOrders = List<Map<String, dynamic>>.from(data);
        _isLoadingCompleted = false;
      });
    } else if (mounted && showLoading) {
      setState(() {
        _errorCompleted = 'Failed to load completed orders. Pull to refresh.';
        _isLoadingCompleted = false;
      });
    }
  }

  Future<void> _acceptOrder(String orderId) async {
    if (_isActionInProgress) return;
    setState(() => _isActionInProgress = true);
    final result = await _postAction('/orders/$orderId/accept');
    if (mounted) {
      setState(() => _isActionInProgress = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result ?? 'Failed to accept order'),
          backgroundColor: result != null ? const Color(0xFF10B981) : const Color(0xFFEF4444),
        ),
      );
      _fetchPendingOrders();
    }
  }

  Future<void> _declineOrder(String orderId) async {
    if (_isActionInProgress) return;
    setState(() => _isActionInProgress = true);
    final result = await _postAction('/orders/$orderId/decline');
    if (mounted) {
      setState(() => _isActionInProgress = false);
      final isError = result == null || result.startsWith('Invalid') || result.startsWith('Network') || result.startsWith('Failed');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result ?? 'Action failed'),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
      _fetchPendingOrders();
    }
  }

  Future<void> _markOutOfDelivery(String orderId) async {
    if (_isActionInProgress) return;
    setState(() => _isActionInProgress = true);
    final result = await _postAction('/orders/$orderId/out-for-delivery');
    if (mounted) {
      setState(() => _isActionInProgress = false);
      final isError = result == null || result.startsWith('Invalid') || result.startsWith('Network') || result.startsWith('Failed');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result ?? 'Action failed'),
          backgroundColor: isError ? const Color(0xFFEF4444) : const Color(0xFF3B82F6),
        ),
      );
      _fetchPendingOrders();
    }
  }


  Future<void> _requestRider(String orderId) async {
    if (_isActionInProgress) return;
    setState(() => _isActionInProgress = true);
    final result = await _patchAction('/orders/$orderId/request-rider');
    if (mounted) {
      setState(() => _isActionInProgress = false);
      final isError = result == null || result.startsWith('Invalid') || result.startsWith('Network') || result.startsWith('Failed');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isError ? (result ?? 'Failed to request rider') : 'Looking for nearby riders...'),
          backgroundColor: isError ? const Color(0xFFEF4444) : const Color(0xFF10B981),
        ),
      );
      _fetchPendingOrders();
    }
  }

  Future<void> _cancelRiderRequest(String orderId) async {
    if (_isActionInProgress) return;
    setState(() => _isActionInProgress = true);
    final result = await _patchAction('/orders/$orderId/cancel-rider-request');
    if (mounted) {
      setState(() => _isActionInProgress = false);
      final isError = result == null || result.startsWith('Invalid') || result.startsWith('Network') || result.startsWith('Failed');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isError ? (result ?? 'Failed to cancel') : 'Rider request cancelled'),
          backgroundColor: isError ? const Color(0xFFEF4444) : const Color(0xFF10B981),
        ),
      );
      _fetchPendingOrders();
    }
  }

  Future<void> _verifyDelivery(String orderId) async {
    final otpController = TextEditingController();

    final otp = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Confirm Delivery'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Ask the shop owner for the 6-digit OTP they received.',
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: otpController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, letterSpacing: 8, fontWeight: FontWeight.w700),
              decoration: InputDecoration(
                hintText: '------',
                counterText: '',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF0F5C4F), width: 1.5),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, otpController.text),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F5C4F),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Confirm Delivery'),
          ),
        ],
      ),
    );

    if (otp == null || otp.length != 6) return;

    if (_isActionInProgress) return;
    setState(() => _isActionInProgress = true);

    final result = await _postActionWithBody('/orders/$orderId/verify-delivery', {'otp': otp});
    if (mounted) {
      setState(() => _isActionInProgress = false);
      final isError = result == null || result.startsWith('Invalid') || result.startsWith('Network') || result.startsWith('Failed');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result ?? 'Verification failed'),
          backgroundColor: isError ? const Color(0xFFEF4444) : const Color(0xFF10B981),
        ),
      );
      _fetchPendingOrders();
      if (!isError) _fetchCompletedOrders();
    }
  }

  Future<String?> _postActionWithBody(String path, Map<String, dynamic> body) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id') ?? '';
      final role = prefs.getString('user_role') ?? 'supplier';
      final uri = Uri.parse('${ApiConfig.baseUrl}$path');

      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'X-User-Id': '$userId::$role',
        },
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 15));

      final resBody = jsonDecode(response.body);
      if (response.statusCode == 200 && resBody['success'] == true) {
        return resBody['data']?['message'] ?? resBody['message'] ?? 'Action completed';
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<String?> _postAction(String path) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id') ?? '';
      final role = prefs.getString('user_role') ?? 'supplier';
      final uri = Uri.parse('${ApiConfig.baseUrl}$path');

      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'X-User-Id': '$userId::$role',
        },
      ).timeout(const Duration(seconds: 15));

      final body = jsonDecode(response.body);
      if (response.statusCode == 200 && body['success'] == true) {
        return body['data']?['message'] ?? body['message'] ?? 'Action completed';
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<String?> _patchAction(String path) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id') ?? '';
      final role = prefs.getString('user_role') ?? 'supplier';
      final uri = Uri.parse('${ApiConfig.baseUrl}$path');

      final response = await http.patch(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'X-User-Id': '$userId::$role',
        },
      ).timeout(const Duration(seconds: 15));

      final body = jsonDecode(response.body);
      if (response.statusCode == 200 && body['success'] == true) {
        return body['data']?['message'] ?? body['message'] ?? 'Action completed';
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: _softSlateBg,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: Colors.white,
          scrolledUnderElevation: 0,
          elevation: 0,
          shadowColor: Colors.black.withValues(alpha: 0.04),
          titleSpacing: 0,
          title: Row(
            children: [
              if (!widget.embedded) ...[
                const SizedBox(width: 16),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: _lightGrayBox,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _borderGray.withValues(alpha: 0.6),
                        width: 1,
                      ),
                    ),
                    child: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 15,
                      color: _mutedLabel,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
              ] else
                const SizedBox(width: 20),
              const Text(
                'Orders',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: _darkText,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(52),
            child: Container(
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: _borderGray.withValues(alpha: 0.6)),
                ),
              ),
              child: TabBar(
                controller: _tabController,
                labelColor: _primaryTeal,
                unselectedLabelColor: _mutedLabel,
                indicatorColor: _primaryTeal,
                indicatorSize: TabBarIndicatorSize.label,
                labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                unselectedLabelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                dividerColor: Colors.transparent,
                indicatorWeight: 3,
                indicatorPadding: const EdgeInsets.only(bottom: 1),
                tabs: [
                  Tab(child: _buildTabLabel('Active', _orders.length, true)),
                  const Tab(text: 'Completed'),
                ],
              ),
            ),
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildActiveTab(),
            _buildCompletedTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildTabLabel(String label, int count, bool isActive) {
    if (!isActive || count == 0) return Text(label);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: isActive ? _primaryTeal.withValues(alpha: 0.1) : _lightGrayBox,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: isActive ? _primaryTeal : _mutedLabel,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActiveTab() {
    return _isLoading
        ? const Center(child: CircularProgressIndicator(color: _primaryTeal))
        : _error != null
            ? _buildErrorState(_error!, _fetchPendingOrders)
            : RefreshIndicator(
                onRefresh: _fetchPendingOrders,
                color: _primaryTeal,
                child: _orders.isEmpty
                    ? _buildEmptyState(
                        icon: Icons.inbox_outlined,
                        title: 'No active orders',
                        subtitle: 'When you receive orders, they will appear here.',
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                        itemCount: _orders.length,
                        itemBuilder: (context, index) {
                          final order = _orders[index];
                          final qty = order['quantity'];
                          final displayQty = qty is num ? qty.toInt().toString() : qty?.toString() ?? '0';
                          return _SupplierOrderCard(
                            orderId: order['orderId'] ?? '',
                            productName: order['productName'] ?? 'Unknown',
                            quantity: displayQty,
                            unit: order['unit'] ?? '',
                            totalAmount: order['totalAmount'] ?? 0,
                            orderStatus: order['orderStatus'] ?? 'pending',
                            orderTime: order['orderTime'] ?? '',
                            shopOwnerName: order['shopOwnerName'] ?? 'Shop Owner',
                            shopOwnerPhone: order['shopOwnerPhone'] ?? '',
                            deliveryLocation: order['deliveryLocation'],
                            deliveryOtp: order['deliveryOtp'],
                            deliveryManId: order['deliveryManId'],
                            isActionInProgress: _isActionInProgress,
                            onAccept: () => _acceptOrder(order['orderId'] ?? ''),
                            onDecline: () => _declineOrder(order['orderId'] ?? ''),
                            onOutForDelivery: () => _markOutOfDelivery(order['orderId'] ?? ''),
                            onAssignDelivery: () => _requestRider(order['orderId'] ?? ''),
                            onCancelRiderRequest: () => _cancelRiderRequest(order['orderId'] ?? ''),
                            onTrackRider: order['delivery_man_id'] != null 
                              ? () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => TrackRiderScreen(
                                        deliveryManId: order['delivery_man_id'],
                                        orderId: order['orderId'] ?? '',
                                      ),
                                    ),
                                  );
                                }
                              : null,
                          );
                        },
                      ),
              );
  }

  Widget _buildCompletedTab() {
    Widget body;
    if (_isLoadingCompleted) {
      body = const Center(child: CircularProgressIndicator(color: _primaryTeal));
    } else if (_errorCompleted != null) {
      body = _buildErrorState(_errorCompleted!, _fetchCompletedOrders);
    } else if (_completedOrders.isEmpty) {
      body = _buildEmptyState(
        icon: Icons.check_circle_outline_rounded,
        title: 'No completed orders yet',
        subtitle: 'Completed deliveries will be shown here.',
        iconColor: const Color(0xFF10B981),
      );
    } else {
      body = RefreshIndicator(
        onRefresh: _fetchCompletedOrders,
        color: _primaryTeal,
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
          itemCount: _completedOrders.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final order = _completedOrders[index];
            final qty = order['quantity'];
            final displayQty = qty is num ? qty.toInt().toString() : qty?.toString() ?? '0';
            return _CompletedOrderCard(
              productName: order['productName'] ?? 'Unknown',
              quantity: displayQty,
              unit: order['unit'] ?? '',
              totalAmount: order['totalAmount'] ?? 0,
              deliveredAt: order['deliveredAt'] ?? '',
              shopOwnerName: order['shopOwnerName'] ?? 'Shop Owner',
              shopOwnerPhone: order['shopOwnerPhone'] ?? '',
              givenRating: order['givenRating'],
              givenComment: order['givenComment'],
            );
          },
        ),
      );
    }
    return body;
  }

  Widget _buildErrorState(String message, VoidCallback onRetry) {
    return ListView(
      children: [
        const SizedBox(height: 80),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 32),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFBFB),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFFECACA)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFEF4444).withValues(alpha: 0.06),
                offset: const Offset(0, 4),
                blurRadius: 16,
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.error_outline_rounded, size: 28, color: Color(0xFFEF4444)),
              ),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: Color(0xFF9CA3AF), height: 1.4),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryTeal,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    Color iconColor = const Color(0xFF64748B),
  }) {
    return ListView(
      children: [
        const SizedBox(height: 80),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 32),
          padding: const EdgeInsets.all(36),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _borderGray.withValues(alpha: 0.8)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                offset: const Offset(0, 4),
                blurRadius: 16,
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 30, color: iconColor),
              ),
              const SizedBox(height: 20),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: _darkText,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: _mutedLabel,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SupplierOrderCard extends StatelessWidget {
  final String orderId;
  final String productName;
  final String quantity;
  final String unit;
  final dynamic totalAmount;
  final String orderStatus;
  final String orderTime;
  final String shopOwnerName;
  final String shopOwnerPhone;
  final String? deliveryLocation;
  final String? deliveryOtp;
  final String? deliveryManId;
  final bool isActionInProgress;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final VoidCallback onOutForDelivery;
  final VoidCallback? onAssignDelivery;
  final VoidCallback? onCancelRiderRequest;
  final VoidCallback? onTrackRider;

  const _SupplierOrderCard({
    required this.orderId,
    required this.productName,
    required this.quantity,
    required this.unit,
    required this.totalAmount,
    required this.orderStatus,
    required this.orderTime,
    required this.shopOwnerName,
    required this.shopOwnerPhone,
    this.deliveryLocation,
    this.deliveryOtp,
    this.deliveryManId,
    this.isActionInProgress = false,
    required this.onAccept,
    required this.onDecline,
    required this.onOutForDelivery,
    this.onAssignDelivery,
    this.onCancelRiderRequest,
    this.onTrackRider,
  });

  Color get _statusColor {
    switch (orderStatus) {
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
      case 'searching_for_rider':
        return const Color(0xFFD97706);
      default:
        return const Color(0xFF6B7280);
    }
  }

  IconData get _statusIcon {
    switch (orderStatus) {
      case 'accepted':
        return Icons.check_circle_outline_rounded;
      case 'out_for_delivery':
        return Icons.local_shipping_outlined;
      case 'in_transit':
        return Icons.route_rounded;
      case 'delivered':
        return Icons.done_all_rounded;
      case 'cancelled':
        return Icons.cancel_outlined;
      case 'searching_for_rider':
        return Icons.search_rounded;
      default:
        return Icons.schedule_rounded;
    }
  }

  String get _statusLabel {
    switch (orderStatus) {
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
      case 'searching_for_rider':
        return 'Searching Rider';
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

  Widget _buildActionButton({required String label, required IconData icon, required Color color, required Color textColor, VoidCallback? onPressed}) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: textColor,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(vertical: 10),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderGray.withValues(alpha: 0.8)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            offset: const Offset(0, 2),
            blurRadius: 12,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(_statusIcon, size: 20, color: _statusColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    productName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: _darkText,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _statusColor.withValues(alpha: 0.15),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: _statusColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _statusLabel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _softSlateBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _InfoRow(label: 'Quantity', value: '$quantity $unit'),
                  const _Divider(),
                  _InfoRow(label: 'Total', value: '৳${(totalAmount is num ? totalAmount.toDouble() : 0).toStringAsFixed(0)}'),
                  const _Divider(),
                  _InfoRow(label: 'Shop Owner', value: shopOwnerName),
                  const _Divider(),
                  _InfoRow(label: 'Phone', value: shopOwnerPhone),
                  if (deliveryLocation != null && deliveryLocation!.isNotEmpty) ...[
                    const _Divider(),
                    _InfoRow(label: 'Delivery', value: deliveryLocation!),
                  ],
                  const _Divider(),
                  _InfoRow(
                    label: 'Ordered',
                    value: _formatTime(orderTime),
                    valueColor: const Color(0xFF64748B),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),
            if (orderStatus == 'pending') ...[
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 44,
                      child: OutlinedButton(
                        onPressed: isActionInProgress ? null : onDecline,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFEF4444),
                          backgroundColor: const Color(0xFFFFFBFB),
                          side: const BorderSide(color: Color(0xFFFECACA), width: 1.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('Decline', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: SizedBox(
                      height: 44,
                      child: ElevatedButton(
                        onPressed: isActionInProgress ? null : onAccept,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('Accept', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ),
                ],
              ),
            ] else if (orderStatus == 'accepted') ...[
              if (deliveryManId != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFA7F3D0)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle, size: 18, color: Color(0xFF10B981)),
                      SizedBox(width: 8),
                      Text(
                        'Rider Assigned',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF059669),
                        ),
                      ),
                    ],
                  ),
                ),
                if (onTrackRider != null) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton.icon(
                      onPressed: isActionInProgress ? null : onTrackRider,
                      icon: const Icon(Icons.location_on, size: 18),
                      label: const Text('Track Rider'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo.shade600,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ] else ...[
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton.icon(
                    onPressed: isActionInProgress ? null : onAssignDelivery,
                    icon: const Icon(Icons.electric_bike_rounded, size: 18),
                    label: const Text('Request Rider'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.shade700,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ] else if (orderStatus == 'searching_for_rider') ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFFDE68A),
                    width: 1,
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFFD97706))),
                    SizedBox(width: 10),
                    Text(
                      'Looking for nearby riders...',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFD97706),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: OutlinedButton.icon(
                  onPressed: isActionInProgress ? null : onCancelRiderRequest,
                  icon: const Icon(Icons.cancel_outlined, size: 18),
                  label: const Text('Cancel Rider Request'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFEF4444),
                    side: const BorderSide(color: Color(0xFFFECACA), width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ] else if (orderStatus == 'out_for_delivery') ...[
              if (onTrackRider != null)
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton.icon(
                    onPressed: isActionInProgress ? null : onTrackRider,
                    icon: const Icon(Icons.location_on, size: 18),
                    label: const Text('Track Rider'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo.shade600,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: _mutedLabel)),
          Flexible(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: valueColor ?? _darkText,
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return const Divider(height: 1, color: _borderGray);
  }
}

// ==================== Completed Order Card ====================

class _CompletedOrderCard extends StatelessWidget {
  final String productName;
  final String quantity;
  final String unit;
  final num totalAmount;
  final String deliveredAt;
  final String shopOwnerName;
  final String shopOwnerPhone;
  final dynamic givenRating;
  final String? givenComment;

  const _CompletedOrderCard({
    required this.productName,
    required this.quantity,
    required this.unit,
    required this.totalAmount,
    required this.deliveredAt,
    required this.shopOwnerName,
    required this.shopOwnerPhone,
    this.givenRating,
    this.givenComment,
  });

  String get _deliveredLabel {
    try {
      final dt = DateTime.parse(deliveredAt);
      final local = dt.toLocal();
      return '${local.day}/${local.month}/${local.year}';
    } catch (_) {
      return '';
    }
  }

  int get _rating {
    if (givenRating is num) return givenRating.toInt();
    return int.tryParse(givenRating?.toString() ?? '') ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderGray.withValues(alpha: 0.8)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            offset: const Offset(0, 2),
            blurRadius: 12,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5).withValues(alpha: 0.5),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              border: Border(
                bottom: BorderSide(color: _borderGray.withValues(alpha: 0.5)),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_rounded, size: 18, color: Color(0xFF10B981)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    productName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: _darkText,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFF10B981).withValues(alpha: 0.15),
                      width: 1,
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.done_rounded, size: 12, color: Color(0xFF059669)),
                      SizedBox(width: 4),
                      Text(
                        'Delivered',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF059669),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.shopping_bag_outlined, size: 15, color: _mutedLabel),
                    const SizedBox(width: 8),
                    Text(
                      '$quantity $unit',
                      style: const TextStyle(fontSize: 13, color: _mutedLabel),
                    ),
                    const SizedBox(width: 12),
                    const Icon(Icons.verified_outlined, size: 14, color: Color(0xFF10B981)),
                    const SizedBox(width: 4),
                    Text(
                      _deliveredLabel,
                      style: const TextStyle(fontSize: 12, color: _mutedLabel),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _softSlateBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.storefront_outlined, size: 16, color: _mutedLabel),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          shopOwnerName,
                          style: const TextStyle(fontSize: 13, color: Color(0xFF374151), fontWeight: FontWeight.w600),
                        ),
                      ),
                      Text(
                        '৳${_fmtAmount(totalAmount)}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: _primaryTeal,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_rating > 0 || (givenComment ?? '').isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBF0),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0xFFFDE68A).withValues(alpha: 0.5),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            ...List.generate(5, (i) {
                              return Icon(
                                i < _rating ? Icons.star_rounded : Icons.star_outline_rounded,
                                size: 16,
                                color: i < _rating ? const Color(0xFFF59E0B) : const Color(0xFFD1D5DB),
                              );
                            }),
                            const SizedBox(width: 8),
                            Text(
                              'Customer review',
                              style: TextStyle(fontSize: 11, color: _mutedLabel.withValues(alpha: 0.8)),
                            ),
                          ],
                        ),
                        if ((givenComment ?? '').isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            givenComment!,
                            style: const TextStyle(fontSize: 13, color: Color(0xFF374151), height: 1.4),
                          ),
                        ],
                      ],
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(Icons.rate_review_outlined, size: 14, color: _mutedLabel.withValues(alpha: 0.6)),
                      const SizedBox(width: 6),
                      Text(
                        'No review left yet',
                        style: TextStyle(
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          color: _mutedLabel.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _fmtAmount(num amount) {
    final d = amount.toDouble();
    return d == d.roundToDouble() ? d.toInt().toString() : d.toStringAsFixed(2);
  }
}
