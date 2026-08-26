import 'package:flutter/material.dart';
import '../../../../core/services/api_service.dart';
import '../models/marketplace_product_model.dart';

const Color _bsPrimaryTeal = Color(0xFF0F766E);
const Color _bsDarkText = Color(0xFF0F172A);
const Color _bsMutedText = Color(0xFF64748B);
const Color _bsBorderGray = Color(0xFFE2E8F0);

/// Opens the bargaining bottom sheet for a marketplace product.
/// The shop owner proposes a lower per-unit price + quantity and sends
/// it to the supplier's inbox. Nothing is ordered until the supplier
/// counters and the owner accepts.
Future<void> showBargainSheet(
  BuildContext context,
  MarketplaceProductModel product,
) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _BargainSheet(product: product),
  );
}

class _BargainSheet extends StatefulWidget {
  final MarketplaceProductModel product;
  const _BargainSheet({required this.product});

  @override
  State<_BargainSheet> createState() => _BargainSheetState();
}

class _BargainSheetState extends State<_BargainSheet> {
  late final TextEditingController _priceController;
  final TextEditingController _quantityController = TextEditingController(text: '1');
  final TextEditingController _messageController = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Suggest opening ~10% below the listed unit price.
    final suggested =
        (widget.product.pricePerUnit * 0.9).toStringAsFixed(2);
    _priceController = TextEditingController(text: suggested);
  }

  @override
  void dispose() {
    _priceController.dispose();
    _quantityController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  double get _proposed =>
      double.tryParse(_priceController.text.trim()) ?? 0;
  double get _quantity =>
      double.tryParse(_quantityController.text.trim()) ?? 0;

  bool get _isValid =>
      _proposed > 0 &&
      _quantity > 0 &&
      _quantity <= widget.product.quantityAvailable;

  Future<void> _submit() async {
    if (!_isValid) {
      setState(() => _error = 'Enter a valid price and quantity');
      return;
    }
    if (_proposed >= widget.product.pricePerUnit) {
      setState(() =>
          _error = 'Offer must be below the listed ৳${widget.product.pricePerUnit.toStringAsFixed(2)}');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final result = await ApiService.post('/negotiations/initiate', body: {
        'stockId': widget.product.stockId,
        'quantity': _quantity,
        'proposedPrice': _proposed,
        'message': _messageController.text.trim().isNotEmpty
            ? _messageController.text.trim()
            : null,
      });

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result != null
              ? 'Offer sent to ${widget.product.supplierName}! Track it in My Bargains.'
              : 'Failed to send offer. Please try again.'),
          backgroundColor:
              result != null ? const Color(0xFF10B981) : const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = 'Network error — please try again';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _bsBorderGray,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Expanded(
                    child: Text('Negotiate Price',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: _bsDarkText)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded,
                        size: 20, color: _bsMutedText),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(widget.product.productName,
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: _bsDarkText),
                          overflow: TextOverflow.ellipsis),
                    ),
                    Text(
                      'Listed: ৳${widget.product.pricePerUnit.toStringAsFixed(2)} / ${widget.product.unit}',
                      style:
                          const TextStyle(fontSize: 12, color: _bsMutedText),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Your offer (৳ per unit)',
                            style: TextStyle(fontSize: 12)),
                        TextField(
                          controller: _priceController,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: InputDecoration(
                            prefixText: '৳ ',
                            hintText: widget.product.pricePerUnit
                                .toStringAsFixed(2),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10)),
                            focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(
                                    color: _bsPrimaryTeal, width: 1.5)),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Quantity (${widget.product.unit})',
                            style: const TextStyle(fontSize: 12)),
                        TextField(
                          controller: _quantityController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            hintText: '1',
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10)),
                            focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(
                                    color: _bsPrimaryTeal, width: 1.5)),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _messageController,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'Message to supplier (optional)',
                  hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide:
                          BorderSide(color: _bsPrimaryTeal, width: 1.5)),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!,
                    style:
                        const TextStyle(fontSize: 12.5, color: Color(0xFFEF4444))),
              ],
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Total: ৳${(_proposed * _quantity).toStringAsFixed(2)}',
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: _bsPrimaryTeal)),
                  Text(
                    'vs listed ৳${(widget.product.pricePerUnit * _quantity).toStringAsFixed(2)}',
                    style: const TextStyle(
                        fontSize: 12,
                        color: _bsMutedText,
                        decoration: TextDecoration.lineThrough),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton.icon(
                  onPressed: _submitting ? null : _submit,
                  icon: _submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.send_outlined, size: 18),
                  label: const Text('Send Offer'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _bsPrimaryTeal,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
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
