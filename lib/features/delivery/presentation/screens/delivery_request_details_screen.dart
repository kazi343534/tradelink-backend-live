import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/constants/app_colors.dart';

class DeliveryRequestDetailsScreen extends StatelessWidget {
  final Map<String, dynamic> request;
  final LatLng? riderLocation;
  final VoidCallback onAccept;

  const DeliveryRequestDetailsScreen({
    super.key,
    required this.request,
    required this.riderLocation,
    required this.onAccept,
  });

  Future<void> _openMap(double lat, double lng) async {
    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _callNumber(String phone) async {
    if (phone.isEmpty) return;
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  double? _calculateDistance(LatLng? p1, LatLng? p2) {
    if (p1 == null || p2 == null) return null;
    const distance = Distance();
    return distance.as(LengthUnit.Meter, p1, p2) / 1000.0;
  }

  /// Try to extract lat/lng from an address string like "Selected Location (23.8194°, 90.4289°)"
  LatLng? _parseCoordsFromAddress(String? address) {
    if (address == null) return null;
    final match = RegExp(r'\(([-\d.]+)[°,\s]+([-\d.]+)[°]?\)').firstMatch(address);
    if (match != null) {
      final lat = double.tryParse(match.group(1)!);
      final lng = double.tryParse(match.group(2)!);
      if (lat != null && lng != null) return LatLng(lat, lng);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final supplierLat = request['supplier_lat'] != null ? double.tryParse(request['supplier_lat'].toString()) : null;
    final supplierLng = request['supplier_lng'] != null ? double.tryParse(request['supplier_lng'].toString()) : null;
    var deliveryLat = request['delivery_lat'] != null ? double.tryParse(request['delivery_lat'].toString()) : null;
    var deliveryLng = request['delivery_lng'] != null ? double.tryParse(request['delivery_lng'].toString()) : null;

    // Fallback: parse coordinates from delivery_address string
    if (deliveryLat == null || deliveryLng == null) {
      final parsed = _parseCoordsFromAddress(request['delivery_address']);
      if (parsed != null) {
        deliveryLat = parsed.latitude;
        deliveryLng = parsed.longitude;
      }
    }

    LatLng? supplierLoc;
    if (supplierLat != null && supplierLng != null) supplierLoc = LatLng(supplierLat, supplierLng);
    
    LatLng? deliveryLoc;
    if (deliveryLat != null && deliveryLng != null) deliveryLoc = LatLng(deliveryLat, deliveryLng);

    final distToSupplier = _calculateDistance(riderLocation, supplierLoc);
    final distSupplierToShop = _calculateDistance(supplierLoc, deliveryLoc);

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('Request Details', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: AppColors.inputBorder,
            height: 1,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Product Header Card
            _buildProductHeader(),
            const SizedBox(height: 16),

            // Route Visualization
            _buildRouteVisualization(
              distToSupplier: distToSupplier,
              distSupplierToShop: distSupplierToShop,
              supplierLoc: supplierLoc,
              deliveryLoc: deliveryLoc,
            ),
            const SizedBox(height: 16),

            // Pickup Section
            _buildLocationSection(
              title: 'Pickup Point',
              subtitle: 'Supplier',
              icon: Icons.store,
              iconColor: const Color(0xFF2563EB),
              name: request['supplier_name'] ?? 'N/A',
              phone: request['supplier_phone'] ?? 'N/A',
              distance: distToSupplier != null ? '${distToSupplier.toStringAsFixed(1)} km from you' : null,
              onMapTap: supplierLoc != null ? () => _openMap(supplierLoc!.latitude, supplierLoc.longitude) : null,
              onPhoneTap: request['supplier_phone'] != null ? () => _callNumber(request['supplier_phone']) : null,
            ),
            const SizedBox(height: 16),

            // Dropoff Section
            _buildLocationSection(
              title: 'Dropoff Point',
              subtitle: 'Shop Owner',
              icon: Icons.location_on,
              iconColor: const Color(0xFF059669),
              name: request['shop_owner_name'] ?? 'N/A',
              phone: request['shop_owner_phone'] ?? 'N/A',
              address: request['delivery_address'],
              distance: distSupplierToShop != null ? '${distSupplierToShop.toStringAsFixed(1)} km from pickup' : null,
              onMapTap: deliveryLoc != null ? () => _openMap(deliveryLoc!.latitude, deliveryLoc.longitude) : null,
              onPhoneTap: request['shop_owner_phone'] != null ? () => _callNumber(request['shop_owner_phone']) : null,
            ),

            // Estimated info
            if (distToSupplier != null && distSupplierToShop != null) ...[
              const SizedBox(height: 16),
              _buildEstimateBar(distToSupplier + distSupplierToShop),
            ],
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
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  onAccept();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryTeal,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle_outline, size: 22),
                    SizedBox(width: 10),
                    Text('Accept Delivery', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProductHeader() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.inputBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primaryTeal, AppColors.primaryTealDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.inventory_2_outlined, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  request['product_name'] ?? 'Item',
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 4),
                Text(
                  '${request['quantity']} ${request['unit']}',
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '৳${request['total_amount']}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF059669)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteVisualization({
    double? distToSupplier,
    double? distSupplierToShop,
    LatLng? supplierLoc,
    LatLng? deliveryLoc,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.inputBorder),
      ),
      child: Row(
        children: [
          // Route dots and line
          Column(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: Color(0xFF2563EB),
                  shape: BoxShape.circle,
                ),
              ),
              Container(
                width: 2,
                height: 32,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [const Color(0xFF2563EB), const Color(0xFF059669)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: Color(0xFF059669),
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          // Route info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildRouteStep(
                  'Pickup',
                  '${request['supplier_name'] ?? 'Supplier'}',
                  distToSupplier != null ? '${distToSupplier.toStringAsFixed(1)} km' : null,
                  const Color(0xFF2563EB),
                ),
                const SizedBox(height: 20),
                _buildRouteStep(
                  'Dropoff',
                  '${request['shop_owner_name'] ?? 'Customer'}',
                  distSupplierToShop != null ? '${distSupplierToShop.toStringAsFixed(1)} km' : null,
                  const Color(0xFF059669),
                ),
              ],
            ),
          ),
          // Map button
          if (deliveryLoc != null)
            GestureDetector(
              onTap: () => _openMap(deliveryLoc.latitude, deliveryLoc.longitude),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.toggleBackground,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.directions_outlined, color: Color(0xFF2563EB), size: 22),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRouteStep(String label, String name, String? distance, Color color) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
              const SizedBox(height: 2),
              Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              if (distance != null)
                Text(distance, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLocationSection({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required String name,
    required String phone,
    String? address,
    String? distance,
    VoidCallback? onMapTap,
    VoidCallback? onPhoneTap,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.inputBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                    Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              if (distance != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.toggleBackground,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.near_me, size: 12, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Text(distance, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
            ],
          ),

          const SizedBox(height: 16),

          // Divider
          Container(height: 1, color: AppColors.inputBorder),

          const SizedBox(height: 14),

          // Name
          _buildDetailRow(Icons.person_outline, 'Contact', name),

          // Phone with call action
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                const SizedBox(width: 32),
                const SizedBox(
                  width: 48,
                  child: Text('Phone', style: TextStyle(fontSize: 12, color: AppColors.textHint)),
                ),
                Expanded(
                  child: Text(phone, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                ),
                if (onPhoneTap != null)
                  GestureDetector(
                    onTap: onPhoneTap,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF059669).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.phone, size: 16, color: Color(0xFF059669)),
                    ),
                  ),
              ],
            ),
          ),

          // Address if exists
          if (address != null && address.isNotEmpty)
            _buildDetailRow(Icons.location_on_outlined, 'Address', address),

          // Map button
          if (onMapTap != null) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 42,
              child: OutlinedButton.icon(
                onPressed: onMapTap,
                icon: const Icon(Icons.map_outlined, size: 18),
                label: const Text('View on Map', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: iconColor,
                  side: BorderSide(color: iconColor),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.textHint),
          const SizedBox(width: 8),
          SizedBox(
            width: 48,
            child: Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textHint)),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEstimateBar(double totalDistanceKm) {
    final estimatedMinutes = (totalDistanceKm * 3).round(); // rough estimate
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primaryTeal.withValues(alpha: 0.06), AppColors.primaryTeal.withValues(alpha: 0.02)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primaryTeal.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 18, color: AppColors.primaryTeal),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Total distance: ${totalDistanceKm.toStringAsFixed(1)} km  •  Est. ~$estimatedMinutes min',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primaryTeal),
            ),
          ),
        ],
      ),
    );
  }
}
