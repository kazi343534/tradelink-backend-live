import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/config/supabase_config.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/api_service.dart';
import '../../../marketplace/presentation/screens/marketplace_search_screen.dart';
import 'notifications_screen.dart';
import 'post_demand_screen.dart';
import 'stock_screen.dart';
import 'orders_screen.dart';
import 'profile_screen.dart';
import 'tradelink_assistant_screen.dart';
import '../../../marketplace/presentation/screens/conversations_screen.dart';

class ShopOwnerHomeScreen extends StatefulWidget {
  const ShopOwnerHomeScreen({super.key});

  @override
  State<ShopOwnerHomeScreen> createState() => _ShopOwnerHomeScreenState();
}

class _ShopOwnerHomeScreenState extends State<ShopOwnerHomeScreen> {
  int _currentIndex = 0;
  String _businessName = 'My Shop';
  String _initials = 'SO';
  int _unreadCount = 0;



  Future<void> _loadUserProfile() async {
    final prefs = await SharedPreferences.getInstance();
    // Graceful fallback: never show bare user IDs ("2") as names.
    String pretty(String? raw) {
      final n = (raw ?? '').trim();
      if (n.isEmpty || RegExp(r'^\d+$').hasMatch(n)) return 'My Shop';
      return n;
    }

    final name = pretty(
      prefs.getString('user_business') ?? prefs.getString('user_name'),
    );

    // Generate initials
    final words = name.trim().split(RegExp(r'\s+'));
    String inits = '';
    if (words.isNotEmpty && words[0].isNotEmpty) {
      inits += words[0][0];
    }
    if (words.length > 1 && words[1].isNotEmpty) {
      inits += words[1][0];
    } else if (words.isNotEmpty && words[0].length > 1) {
      inits += words[0][1];
    }

    if (mounted) {
      setState(() {
        _businessName = name;
        _initials = inits.toUpperCase();
      });
    }
  }

  Future<void> _fetchUnreadCount() async {
    final data = await ApiService.get('/notifications/unread-count');
    if (data != null && mounted) {
      final count = data['count'];
      setState(() {
        _unreadCount = count is int ? count : int.tryParse('$count') ?? 0;
      });
    }
  }

  late final List<Widget> _tabs;
  final GlobalKey<_ShopOwnerDashboardState> _dashboardKey = GlobalKey<_ShopOwnerDashboardState>();

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    _fetchUnreadCount();
    _tabs = [
      ShopOwnerDashboard(
        key: _dashboardKey,
        onNavigateToPost: () => setState(() => _currentIndex = 2),
      ),
      const OrdersScreen(),
      PostDemandScreen(
        isTab: true,
        onPostSuccess: () {
          setState(() => _currentIndex = 0);
          _dashboardKey.currentState?._fetchDashboardData();
        },
      ),
      ConversationsScreen(
        showBack: true,
        onBackTap: () => setState(() => _currentIndex = 0),
      ),
      const ProfileScreen(),
    ];
  }

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
              _buildHeader(),
              const Divider(height: 1, color: Color(0xFFE5E7EB)),
              Expanded(
                child: IndexedStack(index: _currentIndex, children: _tabs),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildHeader() {
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
                  _businessName,
                  style: const TextStyle(
                    fontSize: 20,
                    color: Color(0xFF111827),
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ShopOwnerNotificationsScreen(),
                ),
              );
              _fetchUnreadCount();
            },
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
                  const Icon(
                    Icons.notifications_outlined,
                    size: 20,
                    color: Color(0xFF374151),
                  ),
                  if (_unreadCount > 0)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        constraints: const BoxConstraints(
                          minWidth: 18,
                          minHeight: 18,
                        ),
                        decoration: const BoxDecoration(
                          color: Color(0xFFEF4444),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            _unreadCount > 99 ? '99+' : '$_unreadCount',
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
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
        selectedItemColor: AppColors.primaryTeal,
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
            icon: Icon(Icons.receipt_outlined),
            label: 'Orders',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_circle_outline),
            activeIcon: Icon(Icons.add_circle),
            label: 'Post',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline),
            activeIcon: Icon(Icons.chat_bubble),
            label: 'Chats',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class ShopOwnerDashboard extends StatefulWidget {
  final VoidCallback onNavigateToPost;

  const ShopOwnerDashboard({super.key, required this.onNavigateToPost});

  @override
  State<ShopOwnerDashboard> createState() => _ShopOwnerDashboardState();
}

class _ShopOwnerDashboardState extends State<ShopOwnerDashboard> {
  bool _isLoading = true;
  int _openDemandsCount = 0;
  int _outForDeliveryCount = 0;
  int _completedCount = 0;
  List<Map<String, dynamic>> _postedDemands = [];

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
  }

  Future<void> _fetchDashboardData() async {
    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');

      // 1. Fetch demands for this user (or all if no userId)
      var demandQuery = SupabaseConfig.client
          .from(SupabaseConfig.tableDemands)
          .select('*, users!demands_shop_owner_id_fkey(business_name)')
          .order('created_at', ascending: false);

      if (userId != null && userId.isNotEmpty) {
        demandQuery = SupabaseConfig.client
            .from(SupabaseConfig.tableDemands)
            .select()
            .eq('shop_owner_id', userId)
            .order('created_at', ascending: false);
      }

      final demands = await demandQuery;

      int openDemands = 0;
      int outForDelivery = 0;
      int completed = 0;

      for (var d in demands as List) {
        final status = d['status']?.toString().toLowerCase();
        if (status == 'pending' || status == 'open')
          openDemands++;
        else if (status == 'accepted')
          outForDelivery++;
      }

      // Completed deliveries live on ORDERS, not demands.
      // Demands never reach a 'delivered' status, so count them here.
      try {
        final ordersData = await ApiService.get('/orders/shop-owner');
        if (ordersData != null) {
          final orders = List<Map<String, dynamic>>.from(ordersData);
          completed = orders
              .where((o) =>
                  o['status']?.toString().toLowerCase() == 'delivered')
              .length;
        }
      } catch (_) {// Orders fetch failed — keep completed at 0
      }

      if (mounted) {
        setState(() {
          _postedDemands = List<Map<String, dynamic>>.from(demands);
          _openDemandsCount = openDemands;
          _outForDeliveryCount = outForDelivery;
          _completedCount = completed;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _cancelDemand(String demandId) async {
    final scaffold = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Demand'),
        content: const Text('Are you sure you want to cancel this demand?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes', style: TextStyle(color: AppColors.cancelled)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);
    final data = await ApiService.patch('/demands/$demandId/cancel');
    if (data != null && mounted) {
      scaffold.showSnackBar(
        const SnackBar(
          content: Text('Demand cancelled successfully'),
          backgroundColor: AppColors.accepted,
        ),
      );
      _fetchDashboardData();
    } else if (mounted) {
      setState(() => _isLoading = false);
      scaffold.showSnackBar(
        const SnackBar(
          content: Text('Failed to cancel demand'),
          backgroundColor: AppColors.cancelled,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _fetchDashboardData,
      color: AppColors.primaryTeal,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 24),
          // Post new demand — emerald → sky gradient
          Container(
            height: 48,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF10B981), Color(0xFF0284C7)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ElevatedButton.icon(
              onPressed: () {
                widget.onNavigateToPost();
              },
              icon: const Icon(Icons.add_rounded, size: 20),
              label: const Text(
                'Post new demand',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Ask TradeLink Assistant — white with purple accent
          SizedBox(
            height: 48,
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const TradeLinkAssistantScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.auto_awesome_rounded,
                  size: 20, color: Color(0xFF7C3AED)),
              label: const Text(
                'Ask TradeLink Assistant',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF7C3AED)),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF7C3AED),
                backgroundColor: Colors.white,
                side: const BorderSide(color: Color(0xFF7C3AED), width: 1.4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Browse Marketplace — orange → pink gradient
          Container(
            height: 48,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFF97316), Color(0xFFEC4899)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const MarketplaceSearchScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.storefront_outlined, size: 20),
              label: const Text(
                'Browse Marketplace',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              _StatCard(
                number: '$_openDemandsCount',
                label: 'Open\ndemands',
                accent: const Color(0xFF7C3AED),
                numberColor: const Color(0xFF6D28D9),
              ),
              const SizedBox(width: 12),
              _StatCard(
                number: '$_outForDeliveryCount',
                label: 'Out for\ndelivery',
                accent: const Color(0xFFF97316),
                numberColor: const Color(0xFFC2410C),
              ),
              const SizedBox(width: 12),
              _StatCard(
                number: '$_completedCount',
                label: 'Completed\n',
                accent: const Color(0xFF0284C7),
                numberColor: const Color(0xFF0F766E),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Posted demands',
                style: TextStyle(
                  fontSize: 18,
                  color: Color(0xFF111827),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: CircularProgressIndicator(color: AppColors.primaryTeal),
              ),
            )
          else if (_postedDemands.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primaryTeal.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.post_add_rounded,
                      color: AppColors.primaryTeal,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'No demands posted yet',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Tap "Post new demand" above to broadcast what you need to nearby suppliers.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            )
          else
            ..._postedDemands.map((demand) {
              final productName = demand['product_name'] ?? 'Product';
              final quantity = demand['quantity']?.toString() ?? '1';
              final unit = demand['unit'] ?? 'kg';
              final status =
                  demand['status']?.toString().toUpperCase() ?? 'PENDING';
              final createdAt = demand['created_at']?.toString() ?? '';

              Color statusColor = AppColors.pending;
              if (status == 'ACCEPTED') statusColor = AppColors.accepted;
              if (status == 'DELIVERED') statusColor = AppColors.delivered;
              if (status == 'CANCELLED') statusColor = AppColors.cancelled;

              return _DemandStatusCard(
                demandId: demand['id']?.toString() ?? '',
                title: '$productName, $quantity $unit',
                subtitle:
                    'Status: $status ${createdAt.length >= 10 ? "· ${createdAt.substring(0, 10)}" : ""}',
                status: status,
                statusColor: statusColor,
                onCancel: _cancelDemand,
              );
            }),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String number;
  final String label;
  final Color? accent;
  final Color? numberColor;

  const _StatCard({
    required this.number,
    required this.label,
    this.accent,
    this.numberColor,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFE2E8F0)),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top accent strip
            Container(height: 3, color: accent ?? const Color(0xFFE5E7EB)),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    number,
                    style: TextStyle(
                      fontSize: 26,
                      color: numberColor ?? const Color(0xFF111827),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    label.replaceAll('\n', ' '),
                    style:
                        const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DemandStatusCard extends StatelessWidget {
  final String demandId;
  final String title;
  final String subtitle;
  final String status;
  final Color statusColor;
  final Function(String) onCancel;

  const _DemandStatusCard({
    required this.demandId,
    required this.title,
    required this.subtitle,
    required this.status,
    required this.statusColor,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF111827),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
                    ),
                  ),
                  if (status == 'PENDING' || status == 'OPEN') ...[
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () => onCancel(demandId),
                      child: const Text(
                        'Cancel Demand',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.cancelled,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
          ),
        ],
      ),
    );
  }
}
