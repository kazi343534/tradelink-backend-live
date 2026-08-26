import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/config/supabase_config.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/api_service.dart';
import 'login_screen.dart';
import 'profile_settings_screen.dart';
import 'orders_screen.dart';
import 'settings_screen.dart';

/// Modern profile screen that adapts to Shop Owner vs Supplier.
///
/// The "Switch Mode" tile flips a LOCAL presentation override so users can
/// preview the other workspace; it never mutates the server-side role.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const Color _brand = Color(0xFF0F766E);
  static const Color _brandLight = Color(0xFF2DD4BF);
  static const Color _bgTop = Color(0xFFFFF7ED);
  static const Color _textDark = Color(0xFF0F172A);
  static const Color _textMuted = Color(0xFF64748B);
  static const Color _border = Color(0xFFE2E8F0);

  bool _isLoading = true;
  String _actualRole = 'shop_owner'; // from server/prefs
  String _fullName = '';
  String _businessName = '';
  String _phone = '';
  String _address = '';
  String _category = '';
  String _tradeLicense = '';
  String _minOrderValue = '';
  String _supplyRadius = '';

  @override
  void initState() {
    super.initState();
    _loadEverything();
  }

  Future<void> _loadEverything() async {
    await _loadProfile();
  }

  Future<void> _loadProfile() async {
    final data = await ApiService.get('/profile');
    if (!mounted) return;
    if (data != null) {
      final m = Map<String, dynamic>.from(data);
      // Null-safe string helper — never render "null"
      String s(String k) => m[k]?.toString() ?? '';
      setState(() {
        _actualRole = s('role').isNotEmpty ? s('role') : _actualRole;
        _fullName = s('fullName');
        _businessName = s('businessName');
        _phone = s('phoneNumber');
        _address = s('address');
        _category = s('category');
        _tradeLicense = s('tradeLicense');
        _minOrderValue = s('minOrderValue');
        _supplyRadius = s('supplyRadius');
        _isLoading = false;
      });
    } else if (mounted) {
      await _loadFromPrefs();
    }
  }

  bool get _isSupplier => _actualRole == 'supplier';

  /// Offline fallback when /profile is unreachable.
  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    String pretty(String? raw, String fb) {
      final n = (raw ?? '').trim();
      if (n.isEmpty || RegExp(r'^\d+$').hasMatch(n)) return fb;
      return n;
    }

    if (!mounted) return;
    setState(() {
      _actualRole = prefs.getString('user_role') ?? _actualRole;
      _fullName = pretty(prefs.getString('user_name'), '');
      _businessName = pretty(prefs.getString('user_business'), 'My Shop');
      _phone = prefs.getString('user_phone') ?? '';
      _address = prefs.getString('user_address') ?? '';
      _category = prefs.getString('user_category') ?? '';
      _tradeLicense = prefs.getString('user_trade_license') ?? '';
      _minOrderValue = prefs.getString('user_min_order') ?? '';
      _supplyRadius = prefs.getString('user_supply_radius') ?? '';
      _isLoading = false;
    });
  }

  String get _displayName {
    final n = _businessName.trim().isNotEmpty
        ? _businessName
        : _fullName.trim();
    if (n.isEmpty || RegExp(r'^\d+$').hasMatch(n)) {
      return _isSupplier ? 'My Store' : 'My Shop';
    }
    return n;
  }

  String get _avatarInitials {
    final parts = _displayName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.elementAt(1)[0]}'.toUpperCase();
    }
    return parts.first.substring(0, parts.first.length.clamp(1, 2)).toUpperCase();
  }

  String get _locationLabel {
    final a = _address.trim();
    if (a.isEmpty || a.toLowerCase().startsWith('selected location')) {
      return 'Dhaka, Bangladesh';
    }
    return a.split(',').take(2).join(',').trim();
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
        contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        title: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.logout_rounded,
                  color: Colors.red, size: 22),
            ),
            const SizedBox(width: 12),
            const Text('Log out', style: TextStyle(fontSize: 18)),
          ],
        ),
        content: const Text(
          'Are you sure you want to log out?',
          style: TextStyle(color: _textMuted, height: 1.4),
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _textMuted,
                    side: const BorderSide(color: _border),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Cancel',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Log out',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await SupabaseConfig.client.auth.signOut();
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
            child: CircularProgressIndicator(color: AppColors.primaryTeal)),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_bgTop, Colors.white],
            stops: [0.0, 0.45],
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              _buildHeader(),
              _buildProfileCard(),
              const SizedBox(height: 16),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _buildSettingsList(),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // ── Top header ──
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: SizedBox(
        height: 44,
        child: Stack(
          alignment: Alignment.center,
          children: [
            const Text('Profile',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: _textDark)),
            Align(
              alignment: Alignment.centerRight,
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: IconButton(
                  tooltip: 'Notifications',
                  icon: const Icon(Icons.notifications_none_rounded,
                      size: 22, color: Color(0xFF374151)),
                  onPressed: () {}, // notifications live in their own tab/screen
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Floating profile card ──
  Widget _buildProfileCard() {
    return Column(
      children: [
        const SizedBox(height: 8),
        Container(
          width: 104,
          height: 104,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_brand, _brandLight],
            ),
            boxShadow: [
              BoxShadow(
                color: _brand.withValues(alpha: 0.25),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          padding: const EdgeInsets.all(4),
          child: CircleAvatar(
            backgroundColor: Colors.white,
            child: CircleAvatar(
              radius: 44,
              backgroundColor: _brand,
              child: Text(_avatarInitials,
                  style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      color: Colors.white)),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(_displayName,
            style: const TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w800,
                color: _textDark)),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.location_on_rounded,
                size: 15, color: _brand),
            const SizedBox(width: 4),
            Flexible(
              child: Text(_locationLabel,
                  style: const TextStyle(
                      fontSize: 13.5, color: _textMuted),
                  overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: _isSupplier
                ? const Color(0xFFEEF8F6)
                : const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            _isSupplier ? 'SUPPLIER' : 'SHOP OWNER',
            style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
                color: _isSupplier ? _brand : const Color(0xFF2563EB)),
          ),
        ),
      ],
    );
  }

  // ── Settings list ──
  Widget _buildSettingsList() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _tile(Icons.person_outline_rounded, 'Profile Settings',
              subtitle: 'Name, phone, business details',
              onTap: _openSettings),
          _divider(),
          _tile(Icons.location_on_outlined, 'Location & Delivery Address',
              subtitle: _address.isEmpty ? 'Not set' : _address,
              onTap: _openSettings),
          _divider(),
          if (!_isSupplier)
            _tile(Icons.receipt_long_outlined, 'Order History',
                onTap: () => _push(const OrdersScreen()))
          else ...[

            _tile(Icons.account_balance_wallet_outlined,
                'Manage Withdrawals / Earnings',
                onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content:
                            Text('Withdrawals coming soon — earnings ledger in progress.'),
                        behavior: SnackBarBehavior.floating))),
          ],
          _divider(),
          _tile(Icons.settings_outlined, 'Account Settings & Security',
              onTap: () => _push(const SettingsScreen())),
          _divider(),
          _tile(Icons.logout_rounded, 'Log Out',
              iconColor: Colors.red,
              textColor: Colors.red,
              showChevron: false,
              onTap: _logout),
        ],
      ),
    );
  }

  Widget _divider() =>
      const Divider(height: 1, indent: 66, color: Color(0xFFF1F5F9));

  Widget _tile(IconData icon, String title,
      {String? subtitle,
      VoidCallback? onTap,
      Color iconColor = _brand,
      Color textColor = _textDark,
      bool showChevron = true}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 20, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: textColor)),
                  if (subtitle != null &&
                      subtitle.isNotEmpty &&
                      subtitle.length < 60)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 11.5, color: _textMuted)),
                    ),
                ],
              ),
            ),
            if (showChevron)
              const Icon(Icons.chevron_right_rounded,
                  size: 22, color: Color(0xFF94A3B8)),
          ],
        ),
      ),
    );
  }

  Map<String, dynamic> _userPayload() => {
        'fullName': _fullName,
        'businessName': _businessName,
        'phoneNumber': _phone,
        'address': _address,
        'role': _actualRole,
        'category': _category,
        'tradeLicense': _tradeLicense,
        'minOrderValue': _minOrderValue,
        'supplyRadius': _supplyRadius,
      };

  Future<void> _openSettings() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ProfileSettingsScreen(initialData: _userPayload()),
      ),
    );
    if (mounted) {
      setState(() => _isLoading = true);
      await _loadProfile();
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _push(Widget screen) async {
    await Navigator.push(
        context, MaterialPageRoute(builder: (_) => screen));
  }
}
