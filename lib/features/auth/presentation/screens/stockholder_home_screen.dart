import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/services/api_service.dart';
import 'incoming_order_screen.dart';
import 'notifications_screen.dart';
import 'stock_screen.dart';
import 'profile_screen.dart';
import 'pending_orders_screen.dart';
import '../../../marketplace/presentation/screens/supplier_negotiation_inbox.dart';
import '../../../marketplace/presentation/screens/conversations_screen.dart';

class StockholderHomeScreen extends StatefulWidget {
  const StockholderHomeScreen({super.key});

  @override
  State<StockholderHomeScreen> createState() => _StockholderHomeScreenState();
}

class _StockholderHomeScreenState extends State<StockholderHomeScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFE6F4F1), Color(0xFFF3F0FF)],
            ),
          ),
          child: Column(
          children: [
            _StockholderHeader(),
            const Divider(height: 1, color: Color(0xFFE5E7EB)),
            Expanded(
              child: IndexedStack(
                index: _currentIndex,
                children: [
                  const _StockholderDashboard(),
                  const StockScreen(),
                  const PendingOrdersScreen(embedded: true),
                  ConversationsScreen(
                    showBack: true,
                    onBackTap: () => setState(() => _currentIndex = 0),
                  ),
                  const ProfileScreen(),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        selectedItemColor: const Color(0xFF0F5C4F),
        unselectedItemColor: const Color(0xFF9CA3AF),
        showSelectedLabels: true,
        showUnselectedLabels: true,
        selectedFontSize: 12,
        unselectedFontSize: 12,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory_outlined),
            label: 'Stock',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_outlined),
            label: 'Orders',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline),
            activeIcon: Icon(Icons.chat_bubble),
            label: 'Chats',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class _StockholderHeader extends StatefulWidget {
  @override
  State<_StockholderHeader> createState() => _StockholderHeaderState();
}

class _StockholderHeaderState extends State<_StockholderHeader> {
  String _businessName = '';
  String _initials = 'S';

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    // Graceful fallback: never show bare user IDs ("2") as names.
    String pretty(String? raw) {
      final n = (raw ?? '').trim();
      if (n.isEmpty || RegExp(r'^\d+$').hasMatch(n)) return 'My Store';
      return n;
    }

    final name = pretty(
      prefs.getString('user_business') ?? prefs.getString('user_name'),
    );
    setState(() {
      _businessName = name;
      if (name.isNotEmpty) {
        final words = name.trim().split(RegExp(r'\s+'));
        _initials = words.length >= 2
            ? '${words[0][0]}${words[1][0]}'.toUpperCase()
            : name.substring(0, name.length.clamp(0, 2)).toUpperCase();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFF5252), Color(0xFFFF1744)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Text(
                _initials,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Good morning',
                  style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
                ),
                const SizedBox(height: 4),
                Text(
                  _businessName.isNotEmpty ? _businessName : 'Supplier',
                  style: const TextStyle(
                    fontSize: 20,
                    color: Color(0xFF111827),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const SupplierNegotiationInbox()),
              );
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFEEF0F3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.handshake_outlined,
                  size: 20, color: Color(0xFF374151)),
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const NotificationsScreen()),
              );
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFEEF0F3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Icon(Icons.notifications_outlined, size: 20, color: Color(0xFF374151)),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFFEF4444),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StockholderDashboard extends StatefulWidget {
  const _StockholderDashboard();

  @override
  State<_StockholderDashboard> createState() => _StockholderDashboardState();
}

class _StockholderDashboardState extends State<_StockholderDashboard> {
  bool _isLoading = true;
  int _newDemandsCount = 0;
  int _pendingOrdersCount = 0;
  int _stockItemsCount = 0;
  List<Map<String, dynamic>> _demands = [];

  @override
  void initState() {
    super.initState();
    _fetchHomeStats();
  }

  Future<void> _fetchHomeStats() async {
    final data = await ApiService.get('/suppliers/home-stats');
    if (data != null && mounted) {
      final demandsList = (data['nearbyDemands'] as List?)
              ?.map((e) => Map<String, dynamic>.from(e))
              .toList() ??
          [];
      setState(() {
        _newDemandsCount = data['newDemandsCount'] ?? 0;
        _pendingOrdersCount = data['pendingOrdersCount'] ?? 0;
        _stockItemsCount = data['stockItemsCount'] ?? 0;
        _demands = demandsList;
        _isLoading = false;
      });
    } else if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _acceptDemand(String demandId, String productName) async {
    final result = await ApiService.post('/demands/$demandId/accept');
    if (result != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Accepted: $productName'),
          backgroundColor: const Color(0xFF0F5C4F),
          behavior: SnackBarBehavior.floating,
        ),
      );
      _fetchHomeStats();
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const PendingOrdersScreen()),
        );
      }
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to accept demand. Try again.'),
          backgroundColor: Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _declineDemand(String demandId, String productName) async {
    final result = await ApiService.post('/demands/$demandId/decline');
    if (result != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Declined: $productName'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      _fetchHomeStats();
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to decline demand. Try again.'),
          backgroundColor: Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF0F5C4F)));
    }

    return RefreshIndicator(
      onRefresh: _fetchHomeStats,
      color: const Color(0xFF0F5C4F),
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: [
          const SizedBox(height: 24),
          Row(
            children: [
              _buildStatCard('$_newDemandsCount', 'New demands'),
              const SizedBox(width: 12),
              _buildStatCard('$_pendingOrdersCount', 'Pending orders', onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const PendingOrdersScreen()),
                );
              }),
              const SizedBox(width: 12),
              _buildStatCard('$_stockItemsCount', 'Stock items'),
            ],
          ),
          const SizedBox(height: 24),
          _buildSectionHeader('Nearby demands', '$_newDemandsCount new'),
          const SizedBox(height: 8),
          if (_demands.isEmpty)
            Container(
              margin: const EdgeInsets.symmetric(vertical: 24),
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: const Center(
                child: Text(
                  'No pending demands nearby',
                  style: TextStyle(fontSize: 14, color: Color(0xFF9CA3AF)),
                ),
              ),
            )
          else
            ..._demands.map((demand) => DemandCard(
                  demandId: demand['id'] ?? '',
                  productName: demand['productName'] ?? demand['product_name'] ?? 'Unknown',
                  category: demand['category'] ?? '',
                  quantity: demand['quantity'] ?? 0,
                  unit: demand['unit'] ?? '',
                  targetPrice: demand['targetPrice'],
                  deliveryAddress: demand['deliveryAddress'],
                  latitude: demand['latitude'],
                  longitude: demand['longitude'],
                  supplierMatchCount: (demand['supplierMatchCount'] as num?)?.toInt() ?? 0,
                  shopOwnerName: demand['shopOwnerName'] ?? 'Shop Owner',
                  shopOwnerPhone: demand['shopOwnerPhone'] ?? '',
                  notes: demand['notes'] ?? '',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => IncomingOrderScreen(
                          demandId: demand['id'] ?? '',
                          productName: demand['productName'] ?? demand['product_name'] ?? '',
                          quantity: (demand['quantity'] ?? 0).toString(),
                          unit: demand['unit'] ?? '',
                          category: demand['category'] ?? '',
                          notes: demand['notes'] ?? '',
                        ),
                      ),
                    );
                  },
                  onAccept: () => _acceptDemand(
                    demand['id'] ?? '',
                    demand['productName'] ?? demand['product_name'] ?? '',
                  ),
                  onDecline: () => _declineDemand(
                    demand['id'] ?? '',
                    demand['productName'] ?? demand['product_name'] ?? '',
                  ),
                )),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildStatCard(String number, String label, {VoidCallback? onTap}) {
    final card = Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            number,
            style: const TextStyle(
              fontSize: 26,
              color: Color(0xFF111827),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
          ),
        ],
      ),
    );

    return Expanded(
      child: onTap != null
          ? GestureDetector(onTap: onTap, child: card)
          : card,
    );
  }

  Widget _buildSectionHeader(String title, String badgeLabel) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            color: Color(0xFF111827),
            fontWeight: FontWeight.w700,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFFDECEC),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            badgeLabel,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFFDC2626),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class DemandCard extends StatefulWidget {
  final String demandId;
  final String productName;
  final String category;
  final num quantity;
  final String unit;
  final dynamic targetPrice;
  final dynamic deliveryAddress;
  final dynamic latitude;
  final dynamic longitude;
  final int supplierMatchCount;
  final String shopOwnerName;
  final String shopOwnerPhone;
  final String notes;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final VoidCallback? onTap;

  const DemandCard({
    super.key,
    required this.demandId,
    required this.productName,
    required this.category,
    required this.quantity,
    required this.unit,
    this.targetPrice,
    this.deliveryAddress,
    this.latitude,
    this.longitude,
    this.supplierMatchCount = 0,
    required this.shopOwnerName,
    required this.shopOwnerPhone,
    this.notes = '',
    required this.onAccept,
    required this.onDecline,
    this.onTap,
  });

  @override
  State<DemandCard> createState() => _DemandCardState();
}

class _DemandCardState extends State<DemandCard> {
  String? _resolvedAddress;
  bool _resolving = false;

  double? get _lat => widget.latitude is num
      ? (widget.latitude as num).toDouble()
      : double.tryParse(widget.latitude?.toString() ?? '');
  double? get _lng => widget.longitude is num
      ? (widget.longitude as num).toDouble()
      : double.tryParse(widget.longitude?.toString() ?? '');

  bool get _hasPin => _lat != null && _lng != null;

  String get _addressText {
    final addr = (widget.deliveryAddress ?? '').toString().trim();
    if (addr.isNotEmpty) return addr;
    if (_resolvedAddress != null) return _resolvedAddress!;
    return '';
  }

  @override
  void initState() {
    super.initState();
    // Reverse-geocode when no textual address exists but a pin does.
    if ((widget.deliveryAddress ?? '').toString().trim().isEmpty && _hasPin) {
      _reverseGeocode();
    }
  }

  Future<void> _reverseGeocode() async {
    if (_resolving) return;
    _resolving = true;
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&zoom=16&lat=$_lat&lon=$_lng',
      );
      final res = await http
          .get(uri, headers: {'User-Agent': 'TradeLinkApp/1.0'})
          .timeout(const Duration(seconds: 8));
      if (res.statusCode == 200 && mounted) {
        final body = jsonDecode(res.body);
        final name = body['display_name']?.toString();
        if (name != null && name.isNotEmpty) {
          setState(() => _resolvedAddress = name);
        }
      }
    } catch (_) {
      // Silent — fall back to coordinate display
    } finally {
      _resolving = false;
    }
  }

  void _openMapSheet() {
    if (!_hasPin) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DemandLocationSheet(
        productName: widget.productName,
        addressText: _addressText.isNotEmpty
            ? _addressText
            : '$_lat, $_lng',
        lat: _lat!,
        lng: _lng!,
      ),
    );
  }

  String get _targetPriceLabel {
    if (widget.targetPrice == null) return 'No budget set';
    final t = widget.targetPrice is num
        ? (widget.targetPrice as num).toDouble()
        : double.tryParse(widget.targetPrice.toString());
    if (t == null) return 'No budget set';
    return '৳${t == t.roundToDouble() ? t.toInt().toString() : t.toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Material(
          color: Colors.white,
          child: InkWell(
            onTap: widget.onTap,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header: product name + category badge
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          widget.productName,
                          style: const TextStyle(
                            fontSize: 17,
                            color: Color(0xFF111827),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (widget.category.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEEF8F6),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                                color: const Color(0xFF0F766E), width: 0.8),
                          ),
                          child: Text(
                            widget.category,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF0F766E),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // How many suppliers currently match this demand
                  if (widget.supplierMatchCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEF8F6),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                            color: const Color(0xFF0F766E), width: 0.8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.group_outlined,
                              size: 13, color: Color(0xFF0F766E)),
                          const SizedBox(width: 5),
                          Text(
                            '${widget.supplierMatchCount} ${widget.supplierMatchCount == 1 ? 'supplier' : 'suppliers'} match',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF0F766E),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 10),
                  // Quantity + unit and offered price
                  Row(
                    children: [
                      const Icon(Icons.inventory_2_outlined,
                          size: 15, color: Color(0xFF6B7280)),
                      const SizedBox(width: 6),
                      Text(
                        '${widget.quantity} ${widget.unit}',
                        style: const TextStyle(
                            fontSize: 14, color: Color(0xFF374151)),
                      ),
                      const Spacer(),
                      const Icon(Icons.payments_outlined,
                          size: 15, color: Color(0xFF6B7280)),
                      const SizedBox(width: 4),
                      Text(
                        _targetPriceLabel,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: widget.targetPrice != null
                              ? const Color(0xFF0F5C4F)
                              : const Color(0xFF9CA3AF),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Shop owner details
                  Row(
                    children: [
                      const Icon(Icons.storefront_outlined,
                          size: 15, color: Color(0xFF6B7280)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          widget.shopOwnerName,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF374151),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (widget.shopOwnerPhone.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        const Icon(Icons.phone_outlined,
                            size: 13, color: Color(0xFF6B7280)),
                        const SizedBox(width: 4),
                        Text(
                          widget.shopOwnerPhone,
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF6B7280)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Delivery location — tap to open map
                  InkWell(
                    onTap: _hasPin ? _openMapSheet : null,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _hasPin
                                ? Icons.location_on_rounded
                                : Icons.location_off_outlined,
                            size: 15,
                            color: _hasPin
                                ? const Color(0xFF0F766E)
                                : const Color(0xFF9CA3AF),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              _addressLabel(),
                              style: TextStyle(
                                fontSize: 12.5,
                                color: _hasPin
                                    ? const Color(0xFF374151)
                                    : const Color(0xFF9CA3AF),
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (_hasPin) ...[
                            const SizedBox(width: 4),
                            const Icon(Icons.map_outlined,
                                size: 15, color: Color(0xFF0F766E)),
                            const SizedBox(width: 4),
                            const Text(
                              'Map',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF0F766E),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  // Notes quote box
                  if (widget.notes.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border(
                          left: BorderSide(
                              color: const Color(0xFF0F766E), width: 3),
                        ),
                      ),
                      child: Text(
                        widget.notes,
                        style: const TextStyle(
                            fontSize: 13, color: Color(0xFF4B5563)),
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _buildActionButton(
                          label: 'Decline',
                          backgroundColor: const Color(0xFFEAECF5),
                          textColor: const Color(0xFF374151),
                          onPressed: widget.onDecline,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildActionButton(
                          label: 'Accept',
                          backgroundColor: const Color(0xFF0F5C4F),
                          textColor: Colors.white,
                          onPressed: widget.onAccept,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _addressLabel() {
    final text = _addressText;
    if (text.isNotEmpty) return text;
    if (_hasPin) return 'Location pin set ($_lat, $_lng)';
    return 'No delivery address';
  }

  Widget _buildActionButton({
    required String label,
    required Color backgroundColor,
    required Color textColor,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      height: 44,
      child: Material(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: textColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ==================== Demand Location Sheet ====================

class _DemandLocationSheet extends StatelessWidget {
  final String productName;
  final String addressText;
  final double lat;
  final double lng;

  const _DemandLocationSheet({
    required this.productName,
    required this.addressText,
    required this.lat,
    required this.lng,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.65,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Delivery location — $productName',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        addressText,
                        style: const TextStyle(
                            fontSize: 12.5, color: Color(0xFF64748B)),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded,
                      color: Color(0xFF64748B)),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Expanded(
            child: FlutterMap(
              options: MapOptions(
                initialCenter: LatLng(lat, lng),
                initialZoom: 15.5,
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.tradelink',
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: LatLng(lat, lng),
                      width: 44,
                      height: 44,
                      child: const Icon(Icons.location_on_rounded,
                          size: 40, color: Color(0xFF0F766E)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
