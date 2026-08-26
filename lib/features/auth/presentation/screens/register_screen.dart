import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/config/supabase_config.dart';
import '../../../../core/constants/app_categories.dart';
import '../../../../core/constants/app_colors.dart';
import 'shop_owner_home_screen.dart';
import 'stockholder_home_screen.dart';
import '../widgets/map_location_picker_dialog.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  final UserRole initialRole;

  const RegisterScreen({
    super.key,
    this.initialRole = UserRole.shopOwner,
  });

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  late UserRole _selectedRole;
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // Input Controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _businessNameController = TextEditingController();
  
  // Wholesaler / Supplier Additional Controllers
  final TextEditingController _tradeLicenseController = TextEditingController();
  final TextEditingController _minOrderController = TextEditingController();
  final TextEditingController _supplyRadiusController = TextEditingController();

  String _selectedCategory = AppCategories.grocery;
  bool _obscurePassword = true;
  LatLng _selectedLocation = const LatLng(23.8103, 90.4125);
  String _locationStatus = 'Auto-detected — tap to adjust';

  @override
  void initState() {
    super.initState();
    _selectedRole = widget.initialRole;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _businessNameController.dispose();
    _tradeLicenseController.dispose();
    _minOrderController.dispose();
    _supplyRadiusController.dispose();
    super.dispose();
  }

  String? _formatPhoneNumber(String input) {
    String digits = input.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('880')) {
      digits = '0${digits.substring(3)}';
    } else if (digits.startsWith('0')) {
      // already starts with 0
    } else {
      digits = '0$digits';
    }
    if (digits.length == 11 && digits.startsWith('01')) {
      return digits;
    }
    return null;
  }

  Future<void> _handleRegister() async {
    final name = _nameController.text.trim();
    final rawPhone = _phoneController.text.trim();
    final password = _passwordController.text.trim();
    final businessName = _businessNameController.text.trim();

    final phone = _formatPhoneNumber(rawPhone);

    if (name.isEmpty || rawPhone.isEmpty || password.isEmpty || businessName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all required fields.'),
          backgroundColor: AppColors.cancelled,
        ),
      );
      return;
    }

    if (phone == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid 11-digit Bangladeshi phone number.'),
          backgroundColor: AppColors.cancelled,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final roleStr = _selectedRole == UserRole.shopOwner ? 'shop_owner' : 'supplier';
      
      // Parse min order value
      final minOrder = double.tryParse(_minOrderController.text.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0;

      // Hash the password
      final bytes = utf8.encode(password);
      final digest = sha256.convert(bytes);
      final hashedPassword = digest.toString();

      // Insert into Supabase users table and retrieve the record
      final inserted = await SupabaseConfig.client.from(SupabaseConfig.tableUsers).insert({
        'role': roleStr,
        'full_name': name,
        'phone_number': phone,
        'password_hash': hashedPassword,
        'business_name': businessName,
        'category': _selectedCategory,
        'trade_license': _selectedRole == UserRole.supplier ? _tradeLicenseController.text.trim() : null,
        'min_order_value': _selectedRole == UserRole.supplier ? minOrder : 0.0,
        'supply_radius': _selectedRole == UserRole.supplier ? _supplyRadiusController.text.trim() : null,
        'latitude': _selectedLocation.latitude,
        'longitude': _selectedLocation.longitude,
        'address': _locationStatus,
      }).select().single();

      // Save user session in SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_id', inserted['id']?.toString() ?? '');
      await prefs.setString('user_name', inserted['full_name']?.toString() ?? name);
      await prefs.setString('user_business', inserted['business_name']?.toString() ?? businessName);
      await prefs.setString('user_role', inserted['role']?.toString() ?? roleStr);
      await prefs.setString('user_phone', inserted['phone_number']?.toString() ?? phone);
      await prefs.setString('user_category', inserted['category']?.toString() ?? _selectedCategory);
      await prefs.setString('user_address', inserted['address']?.toString() ?? _locationStatus);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Account created successfully as ${_selectedRole == UserRole.shopOwner ? "Shop Owner" : "Supplier"}!'),
          backgroundColor: AppColors.primaryTeal,
        ),
      );

      if (_selectedRole == UserRole.shopOwner) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => const ShopOwnerHomeScreen(),
          ),
          (route) => false,
        );
      } else {
        // No OTP at registration — go straight to the stockholder dashboard.
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => const StockholderHomeScreen(),
          ),
          (route) => false,
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Registration error: ${e.toString()}'),
          backgroundColor: AppColors.cancelled,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSupplier = _selectedRole == UserRole.supplier;

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 440),
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              decoration: BoxDecoration(
                color: AppColors.cardLight,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Mock Mobile Status Bar
                    const _MockStatusBar(),

                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Header Row with Back Button
                            Row(
                              children: [
                                Material(
                                  color: AppColors.toggleBackground,
                                  borderRadius: BorderRadius.circular(12),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(12),
                                    onTap: () => Navigator.pop(context),
                                    child: const Padding(
                                      padding: EdgeInsets.all(10.0),
                                      child: Icon(
                                        Icons.chevron_left_rounded,
                                        color: AppColors.textPrimary,
                                        size: 24,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                const Text(
                                  'Create account',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textPrimary,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 20),

                            // Role Switcher Segmented Control
                            _buildRoleToggle(),

                            const SizedBox(height: 20),

                            // Full Name Field
                            _buildLabel('Full name'),
                            const SizedBox(height: 8),
                            _buildTextField(
                              controller: _nameController,
                              hintText: 'Rahim Uddin',
                              keyboardType: TextInputType.name,
                            ),

                            const SizedBox(height: 16),

                            // Phone Number Field
                            _buildLabel('Phone number'),
                            const SizedBox(height: 8),
                            _buildTextField(
                              controller: _phoneController,
                              hintText: '1XXX-XXXXXX',
                              keyboardType: TextInputType.phone,
                              prefixIcon: const Padding(
                                padding: EdgeInsets.only(left: 16, right: 8),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '+880',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                            ),

                            const SizedBox(height: 16),

                            // Password Field
                            _buildLabel('Password'),
                            const SizedBox(height: 8),
                            _buildTextField(
                              controller: _passwordController,
                              hintText: 'Create a password',
                              obscureText: _obscurePassword,
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  color: AppColors.textSecondary,
                                  size: 20,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                              ),
                            ),

                            const SizedBox(height: 16),

                            // Shop Name / Warehouse Name
                            _buildLabel(
                              isSupplier ? 'Warehouse / Business name' : 'Shop name',
                            ),
                            const SizedBox(height: 8),
                            _buildTextField(
                              controller: _businessNameController,
                              hintText: isSupplier
                                  ? 'Rahim Wholesale Depot'
                                  : 'Rahim General Store',
                            ),

                            const SizedBox(height: 16),

                            // Category Dropdown
                            _buildLabel('Category'),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              decoration: BoxDecoration(
                                color: AppColors.inputBackground,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.inputBorder, width: 1),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _selectedCategory,
                                  isExpanded: true,
                                  icon: const Icon(
                                    Icons.keyboard_arrow_down_rounded,
                                    color: AppColors.textPrimary,
                                  ),
                                  style: const TextStyle(
                                    fontSize: 15,
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  onChanged: (String? newValue) {
                                    if (newValue != null) {
                                      setState(() {
                                        _selectedCategory = newValue;
                                      });
                                    }
                                  },
                                  items: AppCategories.allCategories
                                      .map<DropdownMenuItem<String>>((String category) {
                                    return DropdownMenuItem<String>(
                                      value: category,
                                      child: Text(category),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),

                            // Wholesaler / Supplier Additional Fields
                            if (isSupplier) ...[
                              const SizedBox(height: 16),
                              _buildLabel('Trade License / Business Reg. No.'),
                              const SizedBox(height: 8),
                              _buildTextField(
                                controller: _tradeLicenseController,
                                hintText: 'TRAD/DHK/2026/98765',
                              ),

                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        _buildLabel('Min Order Value (৳)'),
                                        const SizedBox(height: 8),
                                        _buildTextField(
                                          controller: _minOrderController,
                                          hintText: '5,000 ৳',
                                          keyboardType: TextInputType.number,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        _buildLabel('Supply Radius'),
                                        const SizedBox(height: 8),
                                        _buildTextField(
                                          controller: _supplyRadiusController,
                                          hintText: 'Within 15 km',
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],

                            const SizedBox(height: 16),

                            // Location Field Map Box
                            _buildLabel(
                              isSupplier ? 'Warehouse location' : 'Shop location',
                            ),
                            const SizedBox(height: 8),
                            _buildMapLocationPicker(),

                            const SizedBox(height: 24),

                            // Create Account Button
                            SizedBox(
                              height: 52,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _handleRegister,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primaryTeal,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                        height: 22,
                                        width: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                        ),
                                      )
                                    : const Text(
                                        'Create account',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
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
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Builds Field Label Text
  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
    );
  }

  /// Builds Text Field
  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    Widget? suffixIcon,
    Widget? prefixIcon,
    BoxConstraints? prefixIconConstraints,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      style: const TextStyle(
        fontSize: 15,
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(
          color: AppColors.textHint,
          fontWeight: FontWeight.normal,
        ),
        filled: true,
        fillColor: AppColors.inputBackground,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        suffixIcon: suffixIcon,
        prefixIcon: prefixIcon,
        prefixIconConstraints: prefixIconConstraints,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: AppColors.inputBorder,
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: AppColors.primaryTeal,
            width: 1.8,
          ),
        ),
      ),
    );
  }

  /// Interactive Map Location Box Widget matching design
  Widget _buildMapLocationPicker() {
    return GestureDetector(
      onTap: () async {
        final result = await showDialog<LocationResult>(
          context: context,
          builder: (context) => MapLocationPickerDialog(
            initialLocation: _selectedLocation,
          ),
        );

        if (result != null) {
          setState(() {
            _selectedLocation = result.coordinates;
            _locationStatus = result.address;
          });
        }
      },
      child: Container(
        height: 120,
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.inputBorder, width: 1),
        ),
        child: Stack(
          children: [
            // Grid Background Simulation
            CustomPaint(
              size: Size.infinite,
              painter: _GridPainter(),
            ),

            // Map Pin Icon in Center
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryTeal.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.location_on_outlined,
                      color: AppColors.primaryTeal,
                      size: 26,
                    ),
                  ),
                ],
              ),
            ),

            // Location Badge at Bottom-Left
            Positioned(
              left: 12,
              bottom: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  _locationStatus,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds Role Switcher Toggle
  Widget _buildRoleToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.toggleBackground,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: _RoleTabItem(
              title: 'Shop Owner',
              isSelected: _selectedRole == UserRole.shopOwner,
              onTap: () {
                setState(() {
                  _selectedRole = UserRole.shopOwner;
                });
              },
            ),
          ),
          Expanded(
            child: _RoleTabItem(
              title: 'Supplier',
              isSelected: _selectedRole == UserRole.supplier,
              onTap: () {
                setState(() {
                  _selectedRole = UserRole.supplier;
                });
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleTabItem extends StatelessWidget {
  final String title;
  final bool isSelected;
  final VoidCallback onTap;

  const _RoleTabItem({
    required this.title,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

/// Custom Grid Painter to simulate interactive map view background
class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFE2E8F0).withValues(alpha: 0.6)
      ..strokeWidth = 1.0;

    const step = 20.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _MockStatusBar extends StatelessWidget {
  const _MockStatusBar();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            '9:41',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          Row(
            children: const [
              Icon(Icons.signal_cellular_alt, size: 14, color: AppColors.textPrimary),
              SizedBox(width: 4),
              Text(
                'Wi-Fi 100%',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
