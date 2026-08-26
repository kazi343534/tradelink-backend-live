import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/api_service.dart';
import 'negotiation_chat_screen.dart';

const Color _bgPrimaryTeal = Color(0xFF0F766E);
const Color _bgScreenBg = Color(0xFFF8FAFC);
const Color _bgDarkText = Color(0xFF0F172A);
const Color _bgMutedText = Color(0xFF64748B);
const Color _bgBorderGray = Color(0xFFE2E8F0);

class ShopOwnerBargainsScreen extends StatefulWidget {
  const ShopOwnerBargainsScreen({super.key});

  @override
  State<ShopOwnerBargainsScreen> createState() =>
      _ShopOwnerBargainsScreenState();
}

class _ShopOwnerBargainsScreenState extends State<ShopOwnerBargainsScreen> {
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _negotiations = [];
  String? _actingId;

  @override
  void initState() {
    super.initState();
    _fetchNegotiations();
  }

  Future<void> _fetchNegotiations() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }
    final data = await ApiService.get('/negotiations/shop-owner');
    if (data != null && mounted) {
      setState(() {
        _negotiations = List<Map<String, dynamic>>.from(data);
        _isLoading = false;
      });
    } else if (mounted) {
      setState(() {
        _error = 'Failed to load bargains. Pull to refresh.';
        _isLoading = false;
      });
    }
  }

  Future<void> _respond(String negotiationId, String action) async {
    if (_actingId != null) return;
    setState(() => _actingId = negotiationId);

    final result = await ApiService.post('/negotiations/respond', body: {
      'negotiationId': negotiationId,
      'action': action,
    });

    if (!mounted) return;
    setState(() => _actingId = null);

    if (result != null) {
      final orderCreated = result['orderCreated'] == true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(orderCreated
              ? 'Deal accepted! Order placed — awaiting supplier confirmation.'
              : action == 'decline'
                  ? 'Bargain declined.'
                  : 'Updated.'),
          backgroundColor:
              orderCreated ? const Color(0xFF10B981) : const Color(0xFF64748B),
          behavior: SnackBarBehavior.floating,
        ),
      );
      _fetchNegotiations();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Action failed. Please try again.'),
          backgroundColor: Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgScreenBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('My Bargains',
            style: TextStyle(color: _bgDarkText, fontWeight: FontWeight.w700)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF374151)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primaryTeal))
          : _error != null
              ? ListView(children: [
                  const SizedBox(height: 80),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 32),
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(16),
                      border:
                          Border.all(color: const Color(0xFFFECACA)),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.error_outline,
                            size: 32, color: Color(0xFFEF4444)),
                        const SizedBox(height: 12),
                        Text(_error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontSize: 14, color: Color(0xFF9CA3AF))),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _fetchNegotiations,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _bgPrimaryTeal,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                ])
              : RefreshIndicator(
                  onRefresh: _fetchNegotiations,
                  color: _bgPrimaryTeal,
                  child: _negotiations.isEmpty
                      ? ListView(children: const [
                          SizedBox(height: 80),
                          Icon(Icons.handshake_outlined,
                              size: 44, color: Color(0xFF9CA3AF)),
                          SizedBox(height: 12),
                          Center(
                            child: Text(
                              'No bargains yet.\nTap "Negotiate" on any marketplace product.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 14, color: Color(0xFF9CA3AF)),
                            ),
                          ),
                        ])
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 16),
                          itemCount: _negotiations.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) => _buildCard(
                              _negotiations[index]),
                        ),
                ),
    );
  }

  Widget _buildCard(Map<String, dynamic> n) {
    final status = (n['status'] ?? '').toString();
    final lastBy = (n['lastOfferedBy'] ?? '').toString();
    final original = _toDouble(n['originalPrice']);
    final proposed = _toDouble(n['proposedPrice']);
    final quantity = _toDouble(n['quantity']);
    final unit = (n['unit'] ?? '').toString();
    final supplierName = (n['supplierName'] ?? 'Supplier').toString();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _bgBorderGray),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text((n['productName'] ?? '').toString(),
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: _bgDarkText)),
              ),
              _statusChip(status),
            ],
          ),
          const SizedBox(height: 4),
          Text(supplierName,
              style:
                  const TextStyle(fontSize: 13, color: _bgMutedText)),
          const Divider(height: 18, color: _bgBorderGray),
          Row(
            children: [
              Text('৳${original.toStringAsFixed(2)}/$unit',
                  style: const TextStyle(
                      fontSize: 13,
                      color: _bgMutedText,
                      decoration: TextDecoration.lineThrough)),
              const Icon(Icons.arrow_forward_rounded,
                  size: 14, color: _bgPrimaryTeal),
              const SizedBox(width: 6),
              Text('৳${proposed.toStringAsFixed(2)}/$unit',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: status == 'REJECTED'
                          ? _bgMutedText
                          : _bgPrimaryTeal)),
              const Spacer(),
              Text('${_fmtQty(quantity)} $unit',
                  style: const TextStyle(
                      fontSize: 13, color: Color(0xFF374151))),
            ],
          ),
          if ((n['message'] ?? '').toString().isNotEmpty) ...[
            const SizedBox(height: 8),
            _quoteBox(n['message'].toString(), 'Your message'),
          ],
          if ((n['counterMessage'] ?? '').toString().isNotEmpty &&
              lastBy == 'supplier') ...[
            const SizedBox(height: 8),
            _quoteBox(n['counterMessage'].toString(),
                'Supplier response', isSupplier: true),
          ],
          const SizedBox(height: 6),
          // Chat stays open for EVERY status — history is permanently
          // readable; finalized threads open read-only with a banner.
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => NegotiationChatScreen(
                        negotiationId: n['id'].toString()),
                  ),
                ).then((_) => _fetchNegotiations());
              },
              icon: const Icon(Icons.forum_outlined, size: 15),
              label: Text(
                  status == 'PENDING' || status == 'COUNTERED'
                      ? 'Open Chat'
                      : 'View Chat',
                  style: const TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primaryTeal,
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
            ),
          ),
          if (lastBy == 'supplier' && status == 'COUNTERED') ...[
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: const Text(
                'Supplier countered your offer — accept to place this order at their price.',
                style: TextStyle(fontSize: 12.5, color: Color(0xFF92400E)),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _actingId != null
                        ? null
                        : () => _respond(n['id'], 'decline'),
                    icon: const Icon(Icons.close_rounded, size: 16),
                    label: const Text('Decline'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFEF4444),
                      side: const BorderSide(color: Color(0xFFEF4444)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: _actingId != null
                        ? null
                        : () => _respond(n['id'], 'accept'),
                    icon: _actingId == n['id']
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.check_circle_outline, size: 16),
                    label: const Text('Accept & Order'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F4C3A),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: const Color(0xFFD1D5DB),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            const SizedBox(height: 4),
            Text(
              status == 'PENDING'
                  ? 'Waiting for the supplier to respond…'
                  : status == 'ORDER_CREATED' || status == 'ACCEPTED'
                      ? 'Deal accepted — order placed!'
                      : 'Declined.',
              style: const TextStyle(
                  fontSize: 12.5,
                  fontStyle: FontStyle.italic,
                  color: _bgMutedText),
            ),
          ],
        ],
      ),
    );
  }

  Widget _quoteBox(String text, String label, {bool isSupplier = false}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isSupplier ? const Color(0xFFF0F9FF) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border(
          left: BorderSide(
              color: isSupplier ? const Color(0xFF0284C7) : _bgPrimaryTeal,
              width: 3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: isSupplier
                      ? const Color(0xFF0284C7)
                      : _bgMutedText)),
          const SizedBox(height: 2),
          Text(text,
              style: const TextStyle(fontSize: 13, color: Color(0xFF374151))),
        ],
      ),
    );
  }

  Widget _statusChip(String status) {
    Color bg;
    Color fg;
    switch (status) {
      case 'COUNTERED':
        bg = const Color(0xFFFFFBEB);
        fg = const Color(0xFFB45309);
        break;
      case 'ORDER_CREATED':
        bg = const Color(0xFFECFDF5);
        fg = const Color(0xFF059669);
        break;
      case 'REJECTED':
        bg = const Color(0xFFFEF2F2);
        fg = const Color(0xFFDC2626);
        break;
      default: // PENDING / ACCEPTED
        bg = const Color(0xFFEEF8F6);
        fg = _bgPrimaryTeal;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(status.replaceAll('_', ' ').toLowerCase(),
          style: TextStyle(
              fontSize: 10.5, fontWeight: FontWeight.w700, color: fg)),
    );
  }

  static double _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? 0;
  }

  static String _fmtQty(double q) =>
      q == q.roundToDouble() ? q.toInt().toString() : q.toStringAsFixed(1);
}
