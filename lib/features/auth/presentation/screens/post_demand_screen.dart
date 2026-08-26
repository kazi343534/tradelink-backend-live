import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../../../../core/config/supabase_config.dart';

const Color _pdPrimaryTeal = Color(0xFF0F766E);
const Color _pdActiveCardTeal = Color(0xFFEEF8F6);
const Color _pdScreenBg = Color(0xFFF8FAFC);
const Color _pdDarkText = Color(0xFF0F172A);
const Color _pdMutedText = Color(0xFF64748B);
const Color _pdLabelText = Color(0xFF334155);
const Color _pdBorderGray = Color(0xFFE2E8F0);
const Color _pdLightGrayBox = Color(0xFFF1F5F9);

class PostDemandScreen extends StatefulWidget {
  final bool isTab;
  final VoidCallback? onPostSuccess;

  const PostDemandScreen({super.key, this.isTab = false, this.onPostSuccess});

  @override
  State<PostDemandScreen> createState() => _PostDemandScreenState();
}

class _PostDemandScreenState extends State<PostDemandScreen> {
  static const List<String> _units = ['kg', 'litre', 'pcs'];
  bool _isSubmitting = false;

  final TextEditingController _productController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _budgetController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  String _selectedCategory = 'Grocery';
  String _selectedUnit = 'kg';

  String? _address;
  double? _latitude;
  double? _longitude;

  static const Map<String, IconData> _categories = {
    'Grocery': Icons.shopping_bag_outlined,
    'Pharmacy': Icons.medical_services_outlined,
    'Hardware': Icons.home_repair_service_outlined,
  };

  @override
  void initState() {
    super.initState();
    _fetchUserLocation();
  }

  Future<void> _fetchUserLocation() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? userId = prefs.getString('user_id');
      if (userId == null) return;

      final res = await SupabaseConfig.client
          .from(SupabaseConfig.tableUsers)
          .select('address, latitude, longitude')
          .eq('id', userId)
          .single();
      
      if (mounted) {
        setState(() {
          _address = res['address']?.toString();
          _latitude = res['latitude'] != null ? (res['latitude'] as num).toDouble() : null;
          _longitude = res['longitude'] != null ? (res['longitude'] as num).toDouble() : null;
        });
      }
    } catch (e) {
      // Ignore if it fails to load address; they can still post
    }
  }

  @override
  void dispose() {
    _productController.dispose();
    _quantityController.dispose();
    _budgetController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pdScreenBg,
      appBar: _buildAppBar(context),
      body: _buildFormBody(),
      bottomNavigationBar: _buildBottomActionBar(context),
    );
  }

  // ---------- AppBar ----------
  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(60),
      child: Container(
        height: 60,
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(bottom: BorderSide(color: _pdBorderGray)),
        ),
        child: Row(
          children: [
            const SizedBox(width: 16),
            _buildBackButton(context),
            const SizedBox(width: 12),
            const Text(
              'Post a demand',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: _pdDarkText,
                fontFamily: 'Sora',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackButton(BuildContext context) {
    if (widget.isTab) return const SizedBox();
    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: _pdLightGrayBox,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(
          Icons.arrow_back_ios_new_rounded,
          size: 16,
          color: _pdMutedText,
        ),
      ),
    );
  }

  // ---------- Form Body ----------
  Widget _buildFormBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLabel('Category'),
          const SizedBox(height: 8),
          _buildCategoryGrid(),
          const SizedBox(height: 16),
          _buildTextFieldField(
            label: 'Product',
            hintText: 'e.g. Rice — Basmati',
            controller: _productController,
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: _buildTextFieldField(
                  label: 'Quantity',
                  hintText: '50',
                  controller: _quantityController,
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 1,
                child: _buildDropdownField(
                  label: 'Unit',
                  value: _selectedUnit,
                  options: _units,
                  onChanged: (value) => setState(() => _selectedUnit = value!),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildTextFieldField(
            label: 'Budget / target price per unit (৳)',
            hintText: 'e.g. 65',
            controller: _budgetController,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 16),
          _buildLabel('Delivery location'),
          const SizedBox(height: 8),
          _buildMapCard(),
          const SizedBox(height: 8),
          Text(
            _address != null && _address!.isNotEmpty 
              ? 'Using shop location — $_address' 
              : 'Shop location not set',
            style: const TextStyle(
              fontSize: 13,
              color: _pdMutedText,
              fontFamily: 'Inter',
            ),
          ),
          const SizedBox(height: 16),
          _buildTextFieldField(
            label: 'Notes (optional)',
            hintText: 'Any preference for brand or packaging',
            controller: _notesController,
            maxLines: 3,
          ),
        ],
      ),
    );
  }

  // ---------- Category Grid ----------
  Widget _buildCategoryGrid() {
    return Row(
      children: _categories.entries.map((entry) {
        final isSelected = _selectedCategory == entry.key;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: () => setState(() => _selectedCategory = entry.key),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: isSelected ? _pdActiveCardTeal : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? _pdPrimaryTeal : _pdBorderGray,
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      entry.value,
                      size: 22,
                      color: isSelected ? _pdPrimaryTeal : _pdLabelText,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      entry.key,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? _pdPrimaryTeal : _pdLabelText,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ---------- Label ----------
  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
        color: _pdLabelText,
        fontFamily: 'Inter',
      ),
    );
  }

  // ---------- Text Field ----------
  Widget _buildTextFieldField({
    required String label,
    required String hintText,
    required TextEditingController controller,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(label),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          style: const TextStyle(
            fontSize: 15,
            color: _pdDarkText,
            fontFamily: 'Inter',
          ),
          decoration: _inputDecoration(hintText),
        ),
      ],
    );
  }

  // ---------- Dropdown ----------
  Widget _buildDropdownField({
    required String label,
    required String value,
    required List<String> options,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(label),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: _pdBorderGray),
            borderRadius: BorderRadius.circular(10),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              icon: const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: _pdMutedText,
              ),
              style: const TextStyle(
                fontSize: 15,
                color: _pdDarkText,
                fontFamily: 'Inter',
                fontWeight: FontWeight.w400,
              ),
              items: options
                  .map(
                    (option) => DropdownMenuItem<String>(
                      value: option,
                      child: Text(option),
                    ),
                  )
                  .toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  // ---------- Input Decoration ----------
  InputDecoration _inputDecoration(String hintText) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(
        fontSize: 15,
        color: _pdMutedText,
        fontFamily: 'Inter',
      ),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _pdBorderGray),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _pdPrimaryTeal, width: 1.5),
      ),
    );
  }

  // ---------- Map Card ----------
  Widget _buildMapCard() {
    return Container(
      height: 110,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _pdBorderGray),
        color: const Color(0xFFEEF8F6),
      ),
      clipBehavior: Clip.antiAlias,
      child: _latitude != null && _longitude != null
          ? IgnorePointer(
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: LatLng(_latitude!, _longitude!),
                  initialZoom: 15.0,
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.tradelink',
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: LatLng(_latitude!, _longitude!),
                        width: 40,
                        height: 40,
                        child: const Icon(Icons.location_on, size: 36, color: _pdPrimaryTeal),
                      ),
                    ],
                  ),
                ],
              ),
            )
          : Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(child: CustomPaint(painter: _GridPainter())),
                const Icon(
                  Icons.location_on_rounded,
                  size: 36,
                  color: _pdPrimaryTeal,
                ),
              ],
            ),
    );
  }

  // ---------- Bottom Action Bar ----------
  Widget _buildBottomActionBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: _pdBorderGray)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: _isSubmitting
                ? null
                : () async {
                    final product = _productController.text.trim();
                    final quantityStr = _quantityController.text.trim();
                    final quantity = double.tryParse(quantityStr);
                    final budgetStr = _budgetController.text.trim();
                    final budget = double.tryParse(budgetStr);

                    if (product.isEmpty || quantity == null || quantity <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Please enter a valid product name and quantity.',
                          ),
                          backgroundColor: Colors.redAccent,
                        ),
                      );
                      return;
                    }

                    if (budgetStr.isNotEmpty && (budget == null || budget <= 0)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please enter a valid budget.'),
                          backgroundColor: Colors.redAccent,
                        ),
                      );
                      return;
                    }

                    setState(() => _isSubmitting = true);

                    try {
                      final prefs = await SharedPreferences.getInstance();
                      String? userId = prefs.getString('user_id');

                      // If user_id isn't saved, try to fetch the first shop_owner
                      if (userId == null || userId.isEmpty) {
                        final userRes = await SupabaseConfig.client
                            .from(SupabaseConfig.tableUsers)
                            .select('id')
                            .eq('role', 'shop_owner')
                            .limit(1);
                        if ((userRes as List).isNotEmpty) {
                          userId = userRes[0]['id'];
                        }
                      }

                      if (userId == null) {
                        throw Exception('Please register or log in first.');
                      }

                      // Ensure location is set
                      if (_latitude == null || _longitude == null) {
                        bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
                        if (!serviceEnabled) {
                          throw Exception('Location services are disabled. Please enable them to post a demand.');
                        }

                        LocationPermission permission = await Geolocator.checkPermission();
                        if (permission == LocationPermission.denied) {
                          permission = await Geolocator.requestPermission();
                          if (permission == LocationPermission.denied) {
                            throw Exception('Location permissions are denied.');
                          }
                        }
                        
                        if (permission == LocationPermission.deniedForever) {
                          throw Exception('Location permissions are permanently denied.');
                        } 

                        final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
                        
                        _latitude = position.latitude;
                        _longitude = position.longitude;

                        // Auto-save location to user profile
                        await SupabaseConfig.client
                            .from(SupabaseConfig.tableUsers)
                            .update({
                              'latitude': _latitude,
                              'longitude': _longitude,
                            })
                            .eq('id', userId);

                        if (mounted) setState(() {});
                      }

                      await SupabaseConfig.client
                          .from(SupabaseConfig.tableDemands)
                          .insert({
                            'shop_owner_id': userId,
                            'product_name': product,
                            'category': _selectedCategory,
                            'quantity': quantity,
                            'unit': _selectedUnit,
                            'target_price': budget,
                            'notes': _notesController.text.trim(),
                            'status': 'open',
                            'delivery_address': _address,
                            'latitude': _latitude,
                            'longitude': _longitude,
                          });

                      if (!mounted) return;

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Demand posted: $product ($quantityStr $_selectedUnit)',
                          ),
                          backgroundColor: _pdPrimaryTeal,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );

                      if (widget.isTab) {
                        _productController.clear();
                        _quantityController.clear();
                        _budgetController.clear();
                        _notesController.clear();
                        if (widget.onPostSuccess != null) {
                          widget.onPostSuccess!();
                        }
                      } else {
                        Navigator.pop(context, true);
                      }
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Failed to post demand: ${e.toString()}',
                          ),
                          backgroundColor: Colors.redAccent,
                        ),
                      );
                    } finally {
                      if (mounted) setState(() => _isSubmitting = false);
                    }
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: _pdPrimaryTeal,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: _isSubmitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text(
                    'Post demand',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Inter',
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _pdPrimaryTeal.withValues(alpha: 0.06)
      ..strokeWidth = 1;
    const step = 18.0;
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
