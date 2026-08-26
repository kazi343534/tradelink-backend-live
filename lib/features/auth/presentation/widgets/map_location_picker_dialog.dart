import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/constants/app_colors.dart';

class LocationResult {
  final LatLng coordinates;
  final String address;

  LocationResult({
    required this.coordinates,
    required this.address,
  });
}

class MapLocationPickerDialog extends StatefulWidget {
  final LatLng initialLocation;

  const MapLocationPickerDialog({
    super.key,
    required this.initialLocation,
  });

  @override
  State<MapLocationPickerDialog> createState() => _MapLocationPickerDialogState();
}

class _MapLocationPickerDialogState extends State<MapLocationPickerDialog> {
  late MapController _mapController;
  late LatLng _currentCenter;
  bool _isLocating = false;
  String _statusMessage = 'Drag or tap map to select location';

  // Fallback default coordinates (Dhaka, Bangladesh)
  static const LatLng _fallbackLocation = LatLng(23.8103, 90.4125);

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _currentCenter = widget.initialLocation;
    _detectUserLocation();
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  /// Safely detect GPS location
  Future<void> _detectUserLocation() async {
    if (!mounted) return;

    setState(() {
      _isLocating = true;
      _statusMessage = 'Detecting GPS location...';
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          setState(() {
            _isLocating = false;
            _statusMessage = 'GPS is OFF. Tap map to select manually.';
          });
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            setState(() {
              _isLocating = false;
              _statusMessage = 'Location permission denied. Select manually.';
            });
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() {
            _isLocating = false;
            _statusMessage = 'Location permission blocked. Select manually.';
          });
        }
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 6),
        ),
      );

      final userLatLng = LatLng(position.latitude, position.longitude);

      if (mounted) {
        setState(() {
          _currentCenter = userLatLng;
          _isLocating = false;
          _statusMessage = 'Auto-detected GPS location';
        });

        try {
          _mapController.move(userLatLng, 16.0);
        } catch (_) {
          // Controller move ignored if map engine is initializing
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLocating = false;
          _statusMessage = 'Manual selection mode (GPS unavailable)';
        });
      }
    }
  }

  void _confirmSelection() {
    final lat = _currentCenter.latitude.toStringAsFixed(4);
    final lng = _currentCenter.longitude.toStringAsFixed(4);
    final addressText = 'Selected Location ($lat°, $lng°)';

    Navigator.pop(
      context,
      LocationResult(
        coordinates: _currentCenter,
        address: addressText,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Container(
          width: double.infinity,
          height: 520,
          color: Colors.white,
          child: Column(
            children: [
              // Dialog Header Bar
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Select Location',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              // Interactive OpenStreetMap Container
              Expanded(
                child: Stack(
                  children: [
                    FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: _currentCenter,
                        initialZoom: 15.0,
                        onPositionChanged: (position, hasGesture) {
                          if (hasGesture) {
                            final newCenter = position.center;
                            if (newCenter != null) {
                              setState(() {
                                _currentCenter = newCenter;
                                _statusMessage = 'Pin Position Adjusted';
                              });
                            }
                          }
                        },
                        onTap: (tapPosition, point) {
                          setState(() {
                            _currentCenter = point;
                            _statusMessage = 'Manual Pin Placed';
                          });
                        },
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.tradelink.app',
                        ),
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: _currentCenter,
                              width: 50,
                              height: 50,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: AppColors.primaryTeal.withValues(alpha: 0.25),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.location_on_rounded,
                                  color: AppColors.primaryTeal,
                                  size: 38,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    // GPS Detect Button (Top Right)
                    Positioned(
                      top: 12,
                      right: 12,
                      child: FloatingActionButton.small(
                        heroTag: 'detect_gps_btn',
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.primaryTeal,
                        elevation: 3,
                        onPressed: _isLocating ? null : _detectUserLocation,
                        child: _isLocating
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.primaryTeal,
                                ),
                              )
                            : const Icon(Icons.my_location_rounded),
                      ),
                    ),

                    // Status Overlay Badge (Bottom Left)
                    Positioned(
                      left: 12,
                      bottom: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline_rounded,
                              size: 16,
                              color: AppColors.primaryTeal,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _statusMessage,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Confirm Selection Action Button
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _confirmSelection,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryTeal,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Confirm Location (${_currentCenter.latitude.toStringAsFixed(3)}, ${_currentCenter.longitude.toStringAsFixed(3)})',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
