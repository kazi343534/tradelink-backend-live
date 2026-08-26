import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/config/supabase_config.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../auth/presentation/screens/login_screen.dart';
import 'delivery_request_details_screen.dart';
import '../screens/qr_scanner_screen.dart';

class DeliveryManHomeScreen extends StatefulWidget {
  const DeliveryManHomeScreen({Key? key}) : super(key: key);

  @override
  State<DeliveryManHomeScreen> createState() => _DeliveryManHomeScreenState();
}

class _DeliveryManHomeScreenState extends State<DeliveryManHomeScreen> with WidgetsBindingObserver {
  int _currentIndex = 0;
  bool _isLoading = false;
  List<dynamic> _nearbyRequests = [];
  List<dynamic> _myDeliveries = [];
  Timer? _locationTimer;
  String? _userId;
  String? _userName;
  LatLng? _currentLocation;
  Timer? _feedPollTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initData();
    _startFeedPolling();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _locationTimer?.cancel();
    _feedPollTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _performLocationUpdate();
    }
  }

  Future<void> _initData() async {
    final prefs = await SharedPreferences.getInstance();
    _userId = prefs.getString('user_id');
    _userName = prefs.getString('user_name');
    _fetchData();
    _startLocationUpdates();
  }

  void _startFeedPolling() {
    _feedPollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) {
        _fetchNearbyRequests(showLoading: false);
        _fetchMyDeliveries(showLoading: false);
      }
    });
  }

  Future<void> _fetchData() async {
    if (_currentIndex == 0) {
      await _fetchNearbyRequests();
    } else {
      await _fetchMyDeliveries();
    }
  }

  Future<void> _fetchNearbyRequests({bool showLoading = true}) async {
    if (showLoading) setState(() => _isLoading = true);
    final data = await ApiService.get('/delivery/requests');
    if (mounted) {
      setState(() {
        _nearbyRequests = data ?? [];
        if (showLoading) _isLoading = false;
      });
    }
  }

  Future<void> _fetchMyDeliveries({bool showLoading = true}) async {
    if (showLoading) setState(() => _isLoading = true);
    final data = await ApiService.get('/delivery/orders');
    if (mounted) {
      setState(() {
        _myDeliveries = data ?? [];
        if (showLoading) _isLoading = false;
      });
    }
  }

  void _startLocationUpdates() {
    _performLocationUpdate();
    _locationTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      _performLocationUpdate();
    });
  }

  Future<void> _performLocationUpdate() async {
    if (_userId == null) return;
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }

      if (permission == LocationPermission.deniedForever) return;

      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      
      if (mounted) {
        setState(() {
          _currentLocation = LatLng(position.latitude, position.longitude);
        });
      }

      await SupabaseConfig.client.from(SupabaseConfig.tableUsers).update({
        'latitude': position.latitude,
        'longitude': position.longitude,
      }).eq('id', _userId!);

      _checkProximityToDropoff(position.latitude, position.longitude);
    } catch (e) {
      debugPrint('Location update error: $e');
    }
  }

  final Set<String> _notifiedArrivalOrders = {};

  Future<void> _checkProximityToDropoff(double lat, double lng) async {
    if (_myDeliveries.isEmpty) return;
    final currentLoc = LatLng(lat, lng);
    const distance = Distance();

    for (var order in _myDeliveries) {
      if (order['status'] == 'out_for_delivery') {
        final orderId = order['id'];
        if (_notifiedArrivalOrders.contains(orderId)) continue;

        if (order['delivery_lat'] != null && order['delivery_lng'] != null) {
          final deliveryLat = double.tryParse(order['delivery_lat'].toString());
          final deliveryLng = double.tryParse(order['delivery_lng'].toString());
          if (deliveryLat != null && deliveryLng != null) {
            final dropoffLoc = LatLng(deliveryLat, deliveryLng);
            final distInMeters = distance.as(LengthUnit.Meter, currentLoc, dropoffLoc);
            
            if (distInMeters < 1000) {
              _notifiedArrivalOrders.add(orderId);
              ApiService.post('/orders/$orderId/notify-arrival', body: {});
            }
          }
        }
      }
    }
  }

  Future<void> _acceptRequest(String orderId) async {
    setState(() => _isLoading = true);
    final res = await ApiService.patch('/delivery/requests/$orderId/accept', body: {});
    
    if (res != null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Successfully assigned to you!'),
        backgroundColor: AppColors.primaryTeal,
      ));
      setState(() {
        _currentIndex = 1;
      });
      _fetchMyDeliveries();
    } else {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Failed to accept. It might have been taken by another rider.'),
        backgroundColor: AppColors.cancelled,
      ));
      _fetchNearbyRequests();
    }
  }

  Future<void> _pickupOrder(String orderId) async {
    setState(() => _isLoading = true);
    final res = await ApiService.patch('/delivery/orders/$orderId/pickup', body: {});

    if (res != null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Order picked up! OTP sent to shop owner.'),
        backgroundColor: AppColors.primaryTeal,
      ));
      _fetchMyDeliveries();
    } else {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Failed to pick up order.'),
        backgroundColor: AppColors.cancelled,
      ));
      _fetchMyDeliveries();
    }
  }

  Future<void> _showDeliveryCompletionOptions(String orderId) async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.inputBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Complete Delivery',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 6),
            const Text(
              'Choose how to verify this delivery',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            _buildCompletionOption(
              ctx,
              icon: Icons.sms_outlined,
              title: 'Send OTP to Shop Owner',
              subtitle: 'Shop owner receives a code to share with you',
              color: AppColors.primaryTeal,
              onTap: () {
                Navigator.pop(ctx);
                _sendOtpAndVerify(orderId);
              },
            ),
            const SizedBox(height: 12),
            _buildCompletionOption(
              ctx,
              icon: Icons.qr_code_scanner,
              title: 'Scan QR Code',
              subtitle: 'Scan the shop owner\'s QR code to confirm',
              color: const Color(0xFF2563EB),
              onTap: () {
                Navigator.pop(ctx);
                _scanQrAndVerify(orderId);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompletionOption(BuildContext ctx, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.12)),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: color)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: color.withValues(alpha: 0.5)),
          ],
        ),
      ),
    );
  }

  Future<void> _scanQrAndVerify(String orderId) async {
    final otp = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const QRScannerScreen()),
    );

    if (otp != null && otp.trim().isNotEmpty) {
      _processOtp(orderId, otp.trim(), isQrScan: true);
    }
  }

  Future<void> _sendOtpAndVerify(String orderId) async {
    setState(() => _isLoading = true);
    final res = await ApiService.post('/orders/$orderId/send-otp', body: {});
    setState(() => _isLoading = false);

    if (res != null) {
      if (!mounted) return;
      
      final otpController = TextEditingController();
      final otp = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.primaryTeal.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.lock_outline, color: AppColors.primaryTeal, size: 26),
                ),
                const SizedBox(height: 16),
                const Text('Enter OTP', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                const SizedBox(height: 6),
                const Text(
                  'Enter the 6-digit code shared by the shop owner',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: otpController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 24, letterSpacing: 10, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: '------',
                    counterText: '',
                    filled: true,
                    fillColor: AppColors.toggleBackground,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: AppColors.primaryTeal, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textSecondary,
                          side: const BorderSide(color: AppColors.inputBorder),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryTeal,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () => Navigator.pop(ctx, otpController.text),
                        child: const Text('Verify', style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );

      if (otp != null && otp.trim().isNotEmpty) {
        _processOtp(orderId, otp);
      }
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Failed to send OTP.'),
        backgroundColor: AppColors.cancelled,
      ));
    }
  }

  Future<void> _processOtp(String orderId, String otp, {bool isQrScan = false}) async {
    setState(() => _isLoading = true);

    try {
      final res = await ApiService.patch('/delivery/orders/$orderId/status', body: {
        'otp': otp,
        'isQrScan': isQrScan,
      });

      if (res != null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Order delivered successfully!'),
          backgroundColor: AppColors.primaryTeal,
        ));
        _fetchMyDeliveries();
      } else {
        if (!mounted) return;
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Failed to confirm delivery. Invalid OTP or server error.'),
          backgroundColor: AppColors.cancelled,
        ));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error: $e'),
        backgroundColor: AppColors.cancelled,
      ));
    }
  }

  Future<void> _openMap(double? lat, double? lng) async {
    if (lat == null || lng == null) return;
    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open Maps')));
      }
    }
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  Widget _buildRequestsTab() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppColors.primaryTeal, strokeWidth: 2.5),
            SizedBox(height: 16),
            Text('Finding nearby requests...', style: TextStyle(color: AppColors.textSecondary)),
          ],
        ),
      );
    }
    if (_nearbyRequests.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.primaryTeal.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.electric_bike_outlined, size: 36, color: AppColors.primaryTeal.withValues(alpha: 0.5)),
              ),
              const SizedBox(height: 20),
              const Text('No requests nearby', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              const SizedBox(height: 8),
              const Text(
                'New delivery requests in your area will appear here. Stay online to receive them.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.5),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.primaryTeal,
      onRefresh: _fetchNearbyRequests,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        itemCount: _nearbyRequests.length,
        itemBuilder: (context, index) {
          final order = _nearbyRequests[index];
          return _buildRequestCard(order);
        },
      ),
    );
  }

  Widget _buildRequestCard(dynamic order) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.inputBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => DeliveryRequestDetailsScreen(
                  request: order,
                  riderLocation: _currentLocation,
                  onAccept: () => _acceptRequest(order['id']),
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primaryTeal.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.inventory_2_outlined, color: AppColors.primaryTeal, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            order['product_name'] ?? 'Item',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Qty: ${order['quantity']} ${order['unit']}',
                            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '৳${order['total_amount']}',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF059669)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.toggleBackground,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      _buildRouteInfo(
                        icon: Icons.store,
                        iconColor: const Color(0xFF2563EB),
                        label: 'Pickup',
                        value: order['supplier_name'] ?? '',
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            const SizedBox(width: 11),
                            Container(
                              width: 2,
                              height: 16,
                              decoration: BoxDecoration(
                                color: AppColors.inputBorder,
                                borderRadius: BorderRadius.circular(1),
                              ),
                            ),
                          ],
                        ),
                      ),
                      _buildRouteInfo(
                        icon: Icons.location_on_outlined,
                        iconColor: const Color(0xFF059669),
                        label: 'Dropoff',
                        value: order['delivery_address'] ?? 'Customer Address',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () => _acceptRequest(order['id']),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryTeal,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle_outline, size: 20),
                        SizedBox(width: 8),
                        Text('Accept Delivery', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRouteInfo({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: iconColor),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textHint, fontWeight: FontWeight.w600)),
              Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDeliveriesTab() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppColors.primaryTeal, strokeWidth: 2.5),
            SizedBox(height: 16),
            Text('Loading deliveries...', style: TextStyle(color: AppColors.textSecondary)),
          ],
        ),
      );
    }
    if (_myDeliveries.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.inventory_2_outlined, size: 36, color: const Color(0xFF2563EB).withValues(alpha: 0.5)),
              ),
              const SizedBox(height: 20),
              const Text('No active deliveries', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              const SizedBox(height: 8),
              const Text(
                'Accept a delivery request to start making deliveries.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.5),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.primaryTeal,
      onRefresh: _fetchMyDeliveries,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        itemCount: _myDeliveries.length,
        itemBuilder: (context, index) {
          final order = _myDeliveries[index];
          return _buildDeliveryCard(order);
        },
      ),
    );
  }

  Widget _buildDeliveryCard(dynamic order) {
    final isCompleted = order['status'] == 'delivered';
    final statusColor = isCompleted ? const Color(0xFF059669) : const Color(0xFF2563EB);
    final statusBg = isCompleted ? const Color(0xFFECFDF5) : const Color(0xFFEFF6FF);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isCompleted ? const Color(0xFF059669).withValues(alpha: 0.15) : AppColors.inputBorder,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isCompleted ? Icons.check_circle_outline : Icons.local_shipping_outlined,
                    color: statusColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order['product_name'] ?? 'Item',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Qty: ${order['quantity']} ${order['unit']}',
                        style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isCompleted ? 'Done' : 'Active',
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.toggleBackground,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.store, size: 14, color: Color(0xFF2563EB)),
                      const SizedBox(width: 8),
                      const Text('Pickup: ', style: TextStyle(fontSize: 12, color: AppColors.textHint)),
                      Expanded(
                        child: Text(
                          '${order['supplier_name']} - ${order['supplier_phone']}',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (order['supplier_lat'] != null && order['supplier_lng'] != null)
                        GestureDetector(
                          onTap: () => _openMap(
                            double.tryParse(order['supplier_lat'].toString()),
                            double.tryParse(order['supplier_lng'].toString()),
                          ),
                          child: const Icon(Icons.map_outlined, size: 18, color: Color(0xFF2563EB)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.location_on_outlined, size: 14, color: Color(0xFF059669)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${order['shop_owner_name']} - ${order['shop_owner_phone']}',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if ((order['delivery_address'] ?? '').toString().isNotEmpty)
                              Text(
                                order['delivery_address'],
                                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                      Builder(
                        builder: (context) {
                          var dLat = order['delivery_lat'] != null ? double.tryParse(order['delivery_lat'].toString()) : null;
                          var dLng = order['delivery_lng'] != null ? double.tryParse(order['delivery_lng'].toString()) : null;
                          if (dLat == null || dLng == null) {
                            final addr = (order['delivery_address'] ?? '').toString();
                            final match = RegExp(r'\(([-\d.]+)[°,\s]+([-\d.]+)[°]?\)').firstMatch(addr);
                            if (match != null) {
                              dLat = double.tryParse(match.group(1)!);
                              dLng = double.tryParse(match.group(2)!);
                            }
                          }
                          if (dLat != null && dLng != null) {
                            return GestureDetector(
                              onTap: () => _openMap(dLat, dLng),
                              child: const Icon(Icons.map_outlined, size: 18, color: Color(0xFF059669)),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (!isCompleted) ...[
              const SizedBox(height: 14),
              if (order['status'] == 'accepted') ...[
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 44,
                        child: ElevatedButton.icon(
                          onPressed: () => _pickupOrder(order['id']),
                          icon: const Icon(Icons.inventory_2_outlined, size: 18),
                          label: const Text('Order Pick Up'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryTeal,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Builder(
                      builder: (context) {
                        var dLat = order['delivery_lat'] != null ? double.tryParse(order['delivery_lat'].toString()) : null;
                        var dLng = order['delivery_lng'] != null ? double.tryParse(order['delivery_lng'].toString()) : null;
                        if (dLat == null || dLng == null) {
                          final addr = (order['delivery_address'] ?? '').toString();
                          final match = RegExp(r'\(([-\d.]+)[°,\s]+([-\d.]+)[°]?\)').firstMatch(addr);
                          if (match != null) {
                            dLat = double.tryParse(match.group(1)!);
                            dLng = double.tryParse(match.group(2)!);
                          }
                        }
                        if (dLat != null && dLng != null) {
                          return SizedBox(
                            width: 44,
                            height: 44,
                            child: OutlinedButton(
                              onPressed: () => _openMap(dLat, dLng),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF2563EB),
                                side: const BorderSide(color: Color(0xFF2563EB)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: EdgeInsets.zero,
                              ),
                              child: const Icon(Icons.map_outlined, size: 20),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ],
                ),
              ] else ...[
                Row(
                  children: [
                    if (order['delivery_lat'] != null && order['delivery_lng'] != null)
                      Expanded(
                        child: SizedBox(
                          height: 44,
                          child: OutlinedButton.icon(
                            onPressed: () => _openMap(
                              double.tryParse(order['delivery_lat'].toString()), 
                              double.tryParse(order['delivery_lng'].toString())
                            ),
                            icon: const Icon(Icons.map_outlined, size: 18),
                            label: const Text('Open Map'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF2563EB),
                              side: const BorderSide(color: Color(0xFF2563EB)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ),
                    if (order['delivery_lat'] != null && order['delivery_lng'] != null)
                      const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 44,
                        child: ElevatedButton.icon(
                          onPressed: () => _showDeliveryCompletionOptions(order['id']),
                          icon: const Icon(Icons.check_circle_outline, size: 18),
                          label: const Text('Verify Delivery'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryTeal,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppColors.primaryTeal, AppColors.primaryTealDark],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.electric_bike_rounded, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _currentIndex == 0 ? 'Nearby Requests' : 'My Deliveries',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary, letterSpacing: -0.3),
                        ),
                        if (_userName != null)
                          Text(
                            'Hello, $_userName',
                            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                          ),
                      ],
                    ),
                  ),
                  _buildHeaderIcon(
                    icon: Icons.refresh_rounded,
                    onTap: _fetchData,
                  ),
                  const SizedBox(width: 4),
                  _buildHeaderIcon(
                    icon: Icons.logout_rounded,
                    onTap: _logout,
                    isDestructive: true,
                  ),
                ],
              ),
            ),
            // Content
            Expanded(
              child: _currentIndex == 0 ? _buildRequestsTab() : _buildDeliveriesTab(),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(
                  index: 0,
                  icon: Icons.electric_bike_outlined,
                  activeIcon: Icons.electric_bike_rounded,
                  label: 'Requests',
                  badge: _nearbyRequests.isNotEmpty ? _nearbyRequests.length : null,
                ),
                _buildNavItem(
                  index: 1,
                  icon: Icons.inventory_2_outlined,
                  activeIcon: Icons.inventory_2_rounded,
                  label: 'My Deliveries',
                  badge: _myDeliveries.where((d) => d['status'] != 'delivered').length,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderIcon({
    required IconData icon,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isDestructive ? AppColors.cancelled.withValues(alpha: 0.08) : AppColors.toggleBackground,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          size: 20,
          color: isDestructive ? AppColors.cancelled : AppColors.textSecondary,
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
    int? badge,
  }) {
    final isActive = _currentIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _currentIndex = index;
        });
        _fetchData();
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primaryTeal.withValues(alpha: 0.08) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  isActive ? activeIcon : icon,
                  size: 22,
                  color: isActive ? AppColors.primaryTeal : AppColors.textHint,
                ),
                if (badge != null && badge > 0)
                  Positioned(
                    right: -6,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: AppColors.cancelled,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '$badge',
                        style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
              ],
            ),
            if (isActive) ...[
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.primaryTeal),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
