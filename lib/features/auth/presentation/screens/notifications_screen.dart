import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/services/api_service.dart';
import 'shop_owner_home_screen.dart';
import 'stockholder_home_screen.dart';

class ShopOwnerNotificationsScreen extends StatefulWidget {
  const ShopOwnerNotificationsScreen({super.key});

  @override
  State<ShopOwnerNotificationsScreen> createState() =>
      _ShopOwnerNotificationsScreenState();
}

class _ShopOwnerNotificationsScreenState
    extends State<ShopOwnerNotificationsScreen> {
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _notifications = [];

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  /// Robust back navigation. On Flutter web a browser refresh while this
  /// screen is open makes it the root route — plain pop() then does nothing.
  /// Falls back to the correct role home screen instead of a dead button.
  Future<void> _goBack() async {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final role = prefs.getString('user_role') ?? 'shop_owner';
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => role.toLowerCase() == 'supplier'
            ? const StockholderHomeScreen()
            : const ShopOwnerHomeScreen(),
      ),
      (route) => false,
    );
  }

  Future<void> _fetchNotifications() async {
    if (mounted) setState(() { _isLoading = true; _error = null; });
    final data = await ApiService.get('/notifications');
    if (data != null && mounted) {
      setState(() {
        _notifications = List<Map<String, dynamic>>.from(data);
        _isLoading = false;
      });
    } else if (mounted) {
      setState(() {
        _error = 'Failed to load notifications.';
        _isLoading = false;
      });
    }
  }

  Future<void> _markAsRead(String notificationId) async {
    await ApiService.patch('/notifications/$notificationId/read');
  }

  void _copyOtp(String otp) {
    Clipboard.setData(ClipboardData(text: otp));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('OTP $otp copied to clipboard'),
        backgroundColor: const Color(0xFF0F5C4F),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showReviewModal(String productName, String? orderId, String? supplierId, String? inventoryId) {
    int selectedRating = 0;
    final commentController = TextEditingController();
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                const SizedBox(height: 20),
                const Text(
                  'Rate Your Experience',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'How was your order of $productName?',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (i) {
                    final starIndex = i + 1;
                    return GestureDetector(
                      onTap: () => setModalState(() => selectedRating = starIndex),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Icon(
                          starIndex <= selectedRating
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          size: 40,
                          color: starIndex <= selectedRating
                              ? const Color(0xFFF59E0B)
                              : const Color(0xFFD1D5DB),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: commentController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Add a comment (optional)',
                    hintStyle: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF9CA3AF),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Color(0xFF0F5C4F),
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF64748B),
                          side: const BorderSide(color: Color(0xFFE2E8F0)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Skip'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: (selectedRating == 0 || isSubmitting)
                            ? null
                            : () async {
                                setModalState(() => isSubmitting = true);
                                final result = await ApiService.post('/reviews', body: {
                                  'orderId': orderId,
                                  'supplierId': supplierId,
                                  'inventoryId': inventoryId,
                                  'rating': selectedRating,
                                  'comment': commentController.text.isNotEmpty
                                      ? commentController.text
                                      : null,
                                });
                                if (ctx.mounted) {
                                  Navigator.pop(ctx);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        result != null
                                            ? 'Thank you for your feedback!'
                                            : 'Failed to submit review. Please try again.',
                                      ),
                                      backgroundColor: result != null
                                          ? const Color(0xFF0F5C4F)
                                          : const Color(0xFFEF4444),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F5C4F),
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: const Color(0xFFD1D5DB),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: isSubmitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Submit Review',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: Container(
          height: 60,
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
          ),
          child: Row(
            children: [
              const SizedBox(width: 16),
              GestureDetector(
                onTap: _goBack,
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 16,
                    color: Color(0xFF64748B),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Notifications',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
              TextButton(
                onPressed: _markAllRead,
                child: const Text(
                  'Mark all read',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F5C4F),
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF0F5C4F)))
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, size: 32, color: Color(0xFFEF4444)),
                      const SizedBox(height: 12),
                      Text(_error!, style: const TextStyle(fontSize: 14, color: Color(0xFF9CA3AF))),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _fetchNotifications,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F5C4F),
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _notifications.isEmpty
                  ? const Center(
                      child: Text(
                        'No notifications yet',
                        style: TextStyle(fontSize: 14, color: Color(0xFF9CA3AF)),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _fetchNotifications,
                      color: const Color(0xFF0F5C4F),
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        itemCount: _notifications.length,
                        separatorBuilder: (_, __) => const Divider(
                          height: 1,
                          color: Color(0xFFE2E8F0),
                        ),
                        itemBuilder: (context, index) {
                          final n = _notifications[index];
                          return _buildNotificationCard(n);
                        },
                      ),
                    ),
    );
  }

  Widget _buildNotificationCard(Map<String, dynamic> n) {
    final type = n['type'] ?? '';
    final title = n['title'] ?? '';
    final subtitle = n['subtitle'] ?? '';
    final isRead = n['isRead'] ?? false;

    if (type == 'delivery_otp') {
      return _DeliveryOtpCard(
        title: title,
        subtitle: subtitle,
        isRead: isRead,
        onTap: () {
          if (!isRead) _markAsRead(n['id']);
          final otp = _extractOtp(subtitle);
          if (otp.isNotEmpty) _copyOtp(otp);
        },
      );
    } else if (type == 'order_accepted') {
      return _InfoNotificationCard(
        icon: Icons.check_circle_outline,
        iconColor: const Color(0xFF0F766E),
        iconBg: const Color(0xFFEEF8F6),
        title: title,
        subtitle: subtitle,
        isRead: isRead,
        onTap: () {
          if (!isRead) _markAsRead(n['id']);
        },
      );
    } else if (type == 'delivery_confirmed') {
      final metadata = _extractMetadata(subtitle);
      return _DeliveredCard(
        title: title,
        subtitle: subtitle,
        isRead: isRead,
        onTap: () async {
          if (!isRead) _markAsRead(n['id']);
          final productName = _extractProductName(subtitle);
          String? orderId = metadata['orderId'];
          String? supplierId = metadata['supplierId'];
          String? inventoryId = metadata['inventoryId'];

          // If metadata missing (old notifications), resolve from backend
          if ((supplierId == null || supplierId.isEmpty) && productName.isNotEmpty) {
            final resolved = await ApiService.get('/reviews/resolve-order?productName=${Uri.encodeComponent(productName)}');
            if (resolved != null) {
              orderId = resolved['orderId'];
              supplierId = resolved['supplierId'];
              inventoryId = resolved['inventoryId'];
            }
          }

          if (supplierId == null || supplierId.isEmpty) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Review not available for this order.'),
                  backgroundColor: Color(0xFF64748B),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
            return;
          }
          _showReviewModal(productName, orderId, supplierId, inventoryId);
        },
      );
    } else if (type == 'order_cancelled') {
      return _InfoNotificationCard(
        icon: Icons.cancel_outlined,
        iconColor: const Color(0xFFEF4444),
        iconBg: const Color(0xFFFEF2F2),
        title: title,
        subtitle: subtitle,
        isRead: isRead,
        onTap: () {
          if (!isRead) _markAsRead(n['id']);
        },
      );
    }

    return _InfoNotificationCard(
      icon: Icons.info_outline,
      iconColor: const Color(0xFF3B82F6),
      iconBg: const Color(0xFFEFF6FF),
      title: title,
      subtitle: subtitle,
      isRead: isRead,
      onTap: () {
        if (!isRead) _markAsRead(n['id']);
      },
    );
  }

  String _extractOtp(String text) {
    final match = RegExp(r'(\d{6})').firstMatch(text);
    return match?.group(1) ?? '';
  }

  String _extractProductName(String text) {
    final match = RegExp(r'order for (.+?)(?:\s+has|\s+is|$)').firstMatch(text);
    return match?.group(1) ?? 'your item';
  }

  Map<String, String> _extractMetadata(String text) {
    // New format: ...|||orderId|||supplierId|||inventoryId
    final match3 = RegExp(r'\|\|\|(.+?)\|\|\|(.+?)\|\|\|(.+?)$').firstMatch(text);
    if (match3 != null) {
      return {
        'orderId': match3.group(1) ?? '',
        'supplierId': match3.group(2) ?? '',
        'inventoryId': match3.group(3) ?? '',
      };
    }
    // Old format: ...|||orderId|||supplierId
    final match2 = RegExp(r'\|\|\|(.+?)\|\|\|(.+?)$').firstMatch(text);
    if (match2 != null) {
      return {'orderId': match2.group(1) ?? '', 'supplierId': match2.group(2) ?? ''};
    }
    return {};
  }

  Future<void> _markAllRead() async {
    await ApiService.patch('/notifications/mark-read');
    if (mounted) {
      setState(() {
        for (final n in _notifications) {
          n['isRead'] = true;
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All notifications marked as read'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

// ==================== Card Widgets ====================

class _DeliveryOtpCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool isRead;
  final VoidCallback onTap;

  const _DeliveryOtpCard({
    required this.title,
    required this.subtitle,
    required this.isRead,
    required this.onTap,
  });

  String _extractOtp(String text) {
    final match = RegExp(r'(\d{6})').firstMatch(text);
    return match?.group(1) ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final otp = _extractOtp(subtitle);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isRead ? Colors.white : const Color(0xFFF0FDF4),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isRead ? const Color(0xFFE2E8F0) : const Color(0xFFBBF7D0),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.local_shipping_outlined,
                    size: 18,
                    color: Color(0xFF16A34A),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Out for Delivery!',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isRead
                          ? const Color(0xFF64748B)
                          : const Color(0xFF0F172A),
                    ),
                  ),
                ),
                if (!isRead)
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFFEF4444),
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              subtitle.replaceAll(RegExp(r'OTP[:\s]*\d{6}\.?'), '').trim(),
              style: const TextStyle(
                fontSize: 12.5,
                color: Color(0xFF64748B),
              ),
            ),
            if (otp.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.vpn_key,
                          size: 16,
                          color: Color(0xFF16A34A),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Delivery OTP: $otp',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                            letterSpacing: 3,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Give this code to the delivery person to receive your items.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoNotificationCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String subtitle;
  final bool isRead;
  final VoidCallback onTap;

  const _InfoNotificationCard({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.subtitle,
    required this.isRead,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isRead ? Colors.white : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isRead ? const Color(0xFFE2E8F0) : const Color(0xFFCBD5E1),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: iconColor),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: isRead
                                ? const Color(0xFF64748B)
                                : const Color(0xFF0F172A),
                          ),
                        ),
                      ),
                      if (!isRead)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFFEF4444),
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF94A3B8),
                    ),
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

class _DeliveredCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool isRead;
  final VoidCallback onTap;

  const _DeliveredCard({
    required this.title,
    required this.subtitle,
    required this.isRead,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isRead ? Colors.white : const Color(0xFFF0FDF4),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isRead ? const Color(0xFFE2E8F0) : const Color(0xFFBBF7D0),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.check_circle_outline,
                    size: 18,
                    color: Color(0xFF16A34A),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Order Delivered',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isRead
                          ? const Color(0xFF64748B)
                          : const Color(0xFF0F172A),
                    ),
                  ),
                ),
                if (!isRead)
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFFEF4444),
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              subtitle.replaceAll(RegExp(r'\|\|\|.+$'), '').trim(),
              style: const TextStyle(
                fontSize: 12.5,
                color: Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onTap,
                icon: const Icon(Icons.star_outline, size: 16),
                label: const Text(
                  'Leave Review',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF0F5C4F),
                  side: const BorderSide(color: Color(0xFF0F5C4F)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

typedef NotificationsScreen = ShopOwnerNotificationsScreen;
