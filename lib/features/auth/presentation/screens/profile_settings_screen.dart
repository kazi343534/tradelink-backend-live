import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import '../../../../core/constants/app_categories.dart';
import '../../../../core/services/api_service.dart';

/// Editable profile settings — persists via PATCH /profile.
class ProfileSettingsScreen extends StatefulWidget {
  final Map<String, dynamic> initialData;
  const ProfileSettingsScreen({super.key, required this.initialData});

  @override
  State<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
  static const Color _brand = Color(0xFF0F766E);
  static const Color _dark = Color(0xFF0F172A);
  static const Color _border = Color(0xFFE2E8F0);

  late final bool _isSupplier;
  late final TextEditingController _nameCtrl;
  late final TextEditingController _businessCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _licenseCtrl;
  late final TextEditingController _minOrderCtrl;
  late final TextEditingController _radiusCtrl;
  late String _category;
  double? _latitude;
  double? _longitude;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final d = widget.initialData;
    String s(String k) => d[k]?.toString() ?? '';
    _isSupplier = (d['role'] ?? '').toString() == 'supplier';
    _nameCtrl = TextEditingController(text: s('fullName'));
    _businessCtrl = TextEditingController(text: s('businessName'));
    _phoneCtrl = TextEditingController(text: s('phoneNumber'));
    _addressCtrl = TextEditingController(text: s('address'));
    _licenseCtrl = TextEditingController(text: s('tradeLicense'));
    _minOrderCtrl =
        TextEditingController(text: s('minOrderValue').replaceAll(RegExp(r'\.0+$'), ''));
    _radiusCtrl = TextEditingController(text: s('supplyRadius'));
    _category = s('category').isEmpty ? AppCategories.grocery : s('category');
    final lat = d['latitude'];
    final lng = d['longitude'];
    _latitude = lat != null ? (lat as num).toDouble() : null;
    _longitude = lng != null ? (lng as num).toDouble() : null;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _businessCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _licenseCtrl.dispose();
    _minOrderCtrl.dispose();
    _radiusCtrl.dispose();
    super.dispose();
  }

  InputDecoration _dec(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _brand, width: 1.6)),
      );

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(t,
            style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF334155))),
      );

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final business = _businessCtrl.text.trim();
    if (name.isEmpty || business.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Name and business name are required.'),
          backgroundColor: Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating));
      return;
    }

    setState(() => _saving = true);
    final body = <String, dynamic>{
      'fullName': name,
      'businessName': business,
      'category': _category,
      'phoneNumber': _phoneCtrl.text.trim(),
      'address': _addressCtrl.text.trim(),
    };
    if (_latitude != null && _longitude != null) {
      body['latitude'] = _latitude;
      body['longitude'] = _longitude;
    }
    if (_isSupplier) {
      body['tradeLicense'] = _licenseCtrl.text.trim();
      body['minOrderValue'] =
          double.tryParse(_minOrderCtrl.text.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;
      final r = double.tryParse(_radiusCtrl.text.trim());
      body['supplyRadius'] = r?.toString();
    }

    final hasLocation = _latitude != null;
    if (!hasLocation) {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (serviceEnabled) {
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
          final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
          body['latitude'] = position.latitude;
          body['longitude'] = position.longitude;
        }
      }
    }

    final data = await ApiService.patch('/profile', body: body);

    if (!mounted) return;
    if (data != null) {
      // Keep session cache in sync
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_name', data['fullName']?.toString() ?? name);
      await prefs.setString(
          'user_business', data['businessName']?.toString() ?? business);
      await prefs.setString('user_phone', data['phoneNumber']?.toString() ?? '');
      await prefs.setString('user_address', data['address']?.toString() ?? '');
      await prefs.setString('user_category', _category);
      if (_isSupplier) {
        await prefs.setString('user_trade_license', data['tradeLicense']?.toString() ?? '');
        await prefs.setString('user_min_order', data['minOrderValue']?.toString() ?? '');
        await prefs.setString('user_supply_radius', data['supplyRadius']?.toString() ?? '');
      }

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Profile updated successfully'),
          backgroundColor: Color(0xFF10B981),
          behavior: SnackBarBehavior.floating));
      Navigator.pop(context, true);
    } else {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Failed to save. Please try again.'),
          backgroundColor: Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('Profile Settings',
            style: TextStyle(
                color: _dark, fontSize: 17, fontWeight: FontWeight.w700)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              size: 18, color: Color(0xFF374151)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _label('Full name'),
            TextField(controller: _nameCtrl, decoration: _dec('Your name')),
            const SizedBox(height: 16),
            _label('Business name'),
            TextField(
                controller: _businessCtrl, decoration: _dec('Business name')),
            const SizedBox(height: 16),
            _label('Phone number'),
            TextField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: _dec('01XXX-XXXXXX'),
            ),
            const SizedBox(height: 16),
            _label('Category'),
            DropdownButtonFormField<String>(
              initialValue: _category,
              items: const [
                DropdownMenuItem(value: AppCategories.grocery, child: Text('Grocery')),
                DropdownMenuItem(value: AppCategories.pharmacy, child: Text('Pharmacy')),
                DropdownMenuItem(value: AppCategories.hardware, child: Text('Hardware')),
              ],
              onChanged: (v) =>
                  setState(() => _category = v ?? AppCategories.grocery),
              decoration: _dec('Select category'),
            ),
            const SizedBox(height: 16),
            _label('Delivery address'),
            TextField(
              controller: _addressCtrl,
              maxLines: 2,
              decoration: _dec('Shop location / delivery address'),
            ),
            const SizedBox(height: 16),
            _label('Map location'),
            _buildMapCard(),
            if (_isSupplier) ...[
              const SizedBox(height: 16),
              _label('Trade license'),
              TextField(controller: _licenseCtrl, decoration: _dec('License no.')),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label('Min order (৳)'),
                        TextField(
                            controller: _minOrderCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            decoration: _dec('0')),
                      ]),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label('Supply radius (km)'),
                        TextField(
                            controller: _radiusCtrl,
                            keyboardType: TextInputType.number,
                            decoration: _dec('10')),
                      ]),
                ),
              ]),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save_outlined, size: 18),
                label: const Text('Save Changes',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _brand,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: const Color(0xFFD1D5DB),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapCard() {
    return GestureDetector(
      onTap: () async {
        if (_latitude == null) {
          bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
          if (!serviceEnabled) return;
          LocationPermission permission = await Geolocator.checkPermission();
          if (permission == LocationPermission.denied) {
            permission = await Geolocator.requestPermission();
          }
          if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
            final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
            setState(() {
              _latitude = position.latitude;
              _longitude = position.longitude;
            });
          }
        }
      },
      child: Container(
        height: 140,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _border),
          color: const Color(0xFFEEF8F6),
        ),
        clipBehavior: Clip.antiAlias,
        child: _latitude != null && _longitude != null
            ? FlutterMap(
                options: MapOptions(
                  initialCenter: LatLng(_latitude!, _longitude!),
                  initialZoom: 15.0,
                  onTap: (tapPosition, point) {
                    setState(() {
                      _latitude = point.latitude;
                      _longitude = point.longitude;
                    });
                  },
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
                        child: const Icon(Icons.location_on, size: 36, color: _brand),
                      ),
                    ],
                  ),
                ],
              )
            : Stack(
                alignment: Alignment.center,
                children: [
                  Positioned.fill(child: CustomPaint(painter: _GridPainter())),
                  const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.location_on_rounded, size: 36, color: _brand),
                      SizedBox(height: 8),
                      Text(
                        'Tap to get current location',
                        style: TextStyle(
                          color: _brand,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF0F766E).withValues(alpha: 0.06)
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

