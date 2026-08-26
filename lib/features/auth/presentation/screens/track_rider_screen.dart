import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/config/supabase_config.dart';
import '../../../../core/constants/app_colors.dart';

class TrackRiderScreen extends StatefulWidget {
  final String deliveryManId;
  final String orderId;

  const TrackRiderScreen({
    super.key,
    required this.deliveryManId,
    required this.orderId,
  });

  @override
  State<TrackRiderScreen> createState() => _TrackRiderScreenState();
}

class _TrackRiderScreenState extends State<TrackRiderScreen> {
  LatLng? _riderLocation;
  Timer? _timer;
  final MapController _mapController = MapController();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchRiderLocation();
    // Poll every 5 seconds since Supabase real-time is not configured for public.users yet
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      _fetchRiderLocation();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _fetchRiderLocation() async {
    try {
      final data = await SupabaseConfig.client
          .from(SupabaseConfig.tableUsers)
          .select('latitude, longitude, full_name, phone_number')
          .eq('id', widget.deliveryManId)
          .maybeSingle();

      if (data != null && data['latitude'] != null && data['longitude'] != null) {
        final lat = double.tryParse(data['latitude'].toString());
        final lng = double.tryParse(data['longitude'].toString());
        if (lat != null && lng != null) {
          final loc = LatLng(lat, lng);
          if (mounted) {
            bool wasLoading = _isLoading;
            setState(() {
              _riderLocation = loc;
              _isLoading = false;
            });
            // Auto-center map if it's the first load
            if (wasLoading) {
              _mapController.move(loc, 15);
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching rider location: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Track Delivery Rider'),
        backgroundColor: Colors.white,
        elevation: 1,
      ),
      body: _isLoading && _riderLocation == null
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryTeal))
          : _riderLocation == null
              ? const Center(child: Text('Location not available yet.'))
              : FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _riderLocation!,
                    initialZoom: 15,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.tradelink.app',
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: _riderLocation!,
                          width: 50,
                          height: 50,
                          child: const Icon(
                            Icons.electric_bike,
                            color: Colors.blue,
                            size: 40,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
    );
  }
}
