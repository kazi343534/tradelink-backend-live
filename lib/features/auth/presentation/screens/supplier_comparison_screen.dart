import 'package:flutter/material.dart';
import 'models/supplier_result.dart';

const Color _scPrimaryTeal = Color(0xFF0F766E);
const Color _scScreenBg = Color(0xFFF8FAFC);
const Color _scDarkText = Color(0xFF0F172A);
const Color _scMutedText = Color(0xFF64748B);
const Color _scBorderGray = Color(0xFFE2E8F0);
const Color _scLightGrayBox = Color(0xFFF1F5F9);
const Color _scLabelText = Color(0xFF334155);
const Color _scDangerRed = Color(0xFFDC2626);
const Color _scGreenText = Color(0xFF137333);
const Color _scGreenBg = Color(0xFFE6F4EA);
const Color _scAmberText = Color(0xFFD97706);
const Color _scAmberBg = Color(0xFFFEF3C7);

class SupplierComparisonScreen extends StatefulWidget {
  final String product;
  final List<SupplierResult> suppliers;

  const SupplierComparisonScreen({
    super.key,
    this.product = 'Rice — Basmati, 50kg',
    this.suppliers = const [],
  });

  @override
  State<SupplierComparisonScreen> createState() =>
      _SupplierComparisonScreenState();
}

class _SupplierComparisonScreenState extends State<SupplierComparisonScreen> {
  late List<SupplierResult> _suppliers;
  String _activeFilter = 'Lowest price';

  static const List<String> _filters = [
    'Lowest price',
    'Nearest',
    'Top rated',
    'In stock',
  ];

  @override
  void initState() {
    super.initState();
    _suppliers = widget.suppliers.isNotEmpty
        ? widget.suppliers
        : SupplierResult.mockForProduct(widget.product);
  }

  void _applyFilter(String filter) {
    setState(() {
      _activeFilter = filter;
      final current = List<SupplierResult>.from(_suppliers);
      switch (filter) {
        case 'Nearest':
          current.sort((a, b) =>
              _distanceValue(a.distance).compareTo(_distanceValue(b.distance)));
          break;
        case 'Top rated':
          current.sort((a, b) => b.rating.compareTo(a.rating));
          break;
        case 'In stock':
          current.sort((a, b) => (b.inStock ? 1 : 0) - (a.inStock ? 1 : 0));
          break;
        default:
          current.sort((a, b) => a.price.compareTo(b.price));
      }
      for (var i = 0; i < current.length; i++) {
        current[i] = SupplierResult(
          rank: i + 1,
          storeName: current[i].storeName,
          location: current[i].location,
          distance: current[i].distance,
          price: current[i].price,
          unit: current[i].unit,
          rating: current[i].rating,
          ratingCount: current[i].ratingCount,
          stockBadge: current[i].stockBadge,
          inStock: current[i].inStock,
          isBestPrice: i == 0,
        );
      }
      _suppliers = current;
    });
  }

  double _distanceValue(String distance) {
    return double.tryParse(distance.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _scScreenBg,
      appBar: _buildAppBar(context),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFilterBar(),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              itemCount: _suppliers.length,
              itemBuilder: (context, index) =>
                  _SupplierCard(supplier: _suppliers[index]),
            ),
          ),
        ],
      ),
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
          border: Border(bottom: BorderSide(color: _scBorderGray)),
        ),
        child: Row(
          children: [
            const SizedBox(width: 16),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: _scLightGrayBox,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 16,
                  color: _scMutedText,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Rice — Basmati, 50kg',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: _scDarkText,
                      fontFamily: 'Sora',
                    ),
                  ),
                  Text(
                    '${_suppliers.length} suppliers near Mirpur-10',
                    style: const TextStyle(
                      fontSize: 12,
                      color: _scMutedText,
                      fontFamily: 'Inter',
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: _scLightGrayBox,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.more_horiz_rounded,
                size: 20,
                color: _scDarkText,
              ),
            ),
            const SizedBox(width: 16),
          ],
        ),
      ),
    );
  }

  // ---------- Filter Bar ----------
  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      color: Colors.white,
      child: Row(
        children: _filters.map((filter) {
          final isActive = _activeFilter == filter;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => _applyFilter(filter),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isActive ? _scPrimaryTeal : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: isActive
                      ? null
                      : Border.all(color: _scBorderGray),
                ),
                child: Text(
                  filter,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isActive ? Colors.white : _scLabelText,
                    fontFamily: 'Inter',
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ---------- Supplier Card ----------
class _SupplierCard extends StatelessWidget {
  final SupplierResult supplier;

  const _SupplierCard({required this.supplier});

  @override
  Widget build(BuildContext context) {
    final isBest = supplier.isBestPrice;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isBest ? _scPrimaryTeal : _scBorderGray,
          width: isBest ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: isBest ? _scPrimaryTeal : _scLightGrayBox,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    '#${supplier.rank}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isBest ? Colors.white : _scMutedText,
                      fontFamily: 'Inter',
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      supplier.storeName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: _scDarkText,
                        fontFamily: 'Sora',
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${supplier.location} · ${supplier.distance}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: _scMutedText,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.star_rounded,
                size: 15,
                color: Color(0xFFF59E0B),
              ),
              const SizedBox(width: 2),
              Text(
                '${supplier.rating} (${supplier.ratingCount})',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _scDarkText,
                  fontFamily: 'Inter',
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    supplier.priceLabel,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: isBest ? _scPrimaryTeal : _scDarkText,
                      fontFamily: 'Inter',
                    ),
                  ),
                  if (supplier.diffLabel.isNotEmpty)
                    Text(
                      supplier.diffLabel,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _scDangerRed,
                        fontFamily: 'Inter',
                      ),
                    ),
                ],
              ),
              const Spacer(),
              _StockBadge(
                label: supplier.stockBadge,
                textColor: supplier.stockBadge == '2 left'
                    ? _scAmberText
                    : _scGreenText,
                bgColor: supplier.stockBadge == '2 left'
                    ? _scAmberBg
                    : _scGreenBg,
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 42,
            child: isBest
                ? ElevatedButton(
                    onPressed: () => _order(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _scPrimaryTeal,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Order',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Inter',
                      ),
                    ),
                  )
                : OutlinedButton(
                    onPressed: () => _order(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _scPrimaryTeal,
                      side: const BorderSide(color: _scPrimaryTeal),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Order',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  void _order(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Place order?',
          style: TextStyle(fontFamily: 'Sora', fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Order "${supplier.storeName}" for ${supplier.priceLabel}?',
          style: const TextStyle(fontFamily: 'Inter'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Order placed at ${supplier.storeName}'),
                  backgroundColor: _scPrimaryTeal,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _scPrimaryTeal,
              foregroundColor: Colors.white,
            ),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }
}

class _StockBadge extends StatelessWidget {
  final String label;
  final Color textColor;
  final Color bgColor;

  const _StockBadge({
    required this.label,
    required this.textColor,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: textColor,
          fontFamily: 'Inter',
        ),
      ),
    );
  }
}