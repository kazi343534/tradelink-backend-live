import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/api_service.dart';
import 'negotiation_chat_screen.dart';

const Color _siPrimaryTeal = Color(0xFF0F766E);
const Color _siScreenBg = Color(0xFFF8FAFC);
const Color _siDarkText = Color(0xFF0F172A);
const Color _siMutedText = Color(0xFF64748B);
const Color _siBorderGray = Color(0xFFE2E8F0);

/// Supplier's negotiation inbox: every bargain conversation addressed to
/// this supplier, with Accept Deal / Counter-Chat / Decline quick actions.
class SupplierNegotiationInbox extends StatefulWidget {
  const SupplierNegotiationInbox({super.key});

  @override
  State<SupplierNegotiationInbox> createState() =>
      _SupplierNegotiationInboxState();
}

class _SupplierNegotiationInboxState extends State<SupplierNegotiationInbox> {
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _negotiations = [];
  String? _actingId;

  @override
  void initState() {
    super.initState();
    _fetchInbox();
  }

  Future<void> _fetchInbox() async {
    if (mounted) setState(() { _isLoading = true; _error = null; });
    final data = await ApiService.get('/negotiations/supplier');
    if (data != null && mounted) {
      setState(() {
        _negotiations = List<Map<String, dynamic>>.from(data);
        _isLoading = false;
      });
    } else if (mounted) {
      setState(() {
        _error = 'Failed to load inbox. Pull to refresh.';
        _isLoading = false;
      });
    }
  }

  Future<void> _act(String negotiationId, String action) async {
    if (_actingId != null) return;
    setState(() => _actingId = negotiationId);

    Map<String, dynamic>? result;
    if (action == 'finalize') {
      result = await ApiService.post('/negotiations/$negotiationId/finalize');
    } else {
      result = await ApiService.post('/negotiations/message', body: {
        'negotiationId': negotiationId,
        'message': action == 'decline'
            ? 'Supplier is not interested in this offer.'
            : null,
      });
      if (result != null && action == 'decline') {
        await ApiService.post('/negotiations/respond', body: {
          'negotiationId': negotiationId,
          'action': 'decline',
        });
      }
    }

    if (!mounted) return;
    setState(() => _actingId = null);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result != null
              ? (action == 'finalize'
                  ? 'Deal accepted — order placed!'
                  : action == 'decline'
                      ? 'Negotiation declined.'
                      : 'Replied.')
              : 'Action failed. Try again.',
        ),
        backgroundColor: result != null
            ? const Color(0xFF10B981)
            : const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
      ),
    );
    _fetchInbox();
  }

  void _openChat(Map<String, dynamic> n) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NegotiationChatScreen(
          negotiationId: n['id'].toString(),
        ),
      ),
    );
    _fetchInbox();
  }

  /// Explicit reverse counter-offer: prompt for a new unit price and
  /// push it onto the thread (updates current_proposed_price live).
  Future<void> _showCounterOfferDialog(Map<String, dynamic> n) async {
    final controller = TextEditingController(
        text: _d(n['proposedPrice'] ?? n['currentProposedPrice'])
            .toStringAsFixed(2));
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Counter Offer'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                'Your new unit price for ${(n['productName'] ?? '').toString()}:',
                style:
                    const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                prefixText: '\u09f3 ',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: _siPrimaryTeal, foregroundColor: Colors.white),
            child: const Text('Send'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    final price = double.tryParse(controller.text.trim());
    if (price == null || price <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Invalid price'), backgroundColor: Colors.orange));
      return;
    }

    setState(() => _actingId = n['id']);
    final result = await ApiService.post('/negotiations/message', body: {
      'negotiationId': n['id'],
      'offeredPrice': price,
      'message': 'Supplier countered with \u09f3${price.toStringAsFixed(2)}/unit',
    });
    if (!mounted) return;
    setState(() => _actingId = null);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(result != null
          ? 'Counter-offer sent: \u09f3${price.toStringAsFixed(2)}/unit'
          : 'Failed to send counter-offer.'),
      backgroundColor:
          result != null ? const Color(0xFF10B981) : const Color(0xFFEF4444),
      behavior: SnackBarBehavior.floating,
    ));
    _fetchInbox();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _siScreenBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('Bargain Inbox',
            style:
                TextStyle(color: _siDarkText, fontWeight: FontWeight.w700)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF374151)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(
              child:
                  CircularProgressIndicator(color: AppColors.primaryTeal))
          : _error != null
              ? ListView(children: [
                  const SizedBox(height: 80),
                  Center(
                    child: Column(
                      children: [
                        const Icon(Icons.error_outline,
                            size: 32, color: Color(0xFFEF4444)),
                        const SizedBox(height: 12),
                        Text(_error!,
                            style: const TextStyle(
                                fontSize: 14, color: Color(0xFF9CA3AF))),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _fetchInbox,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _siPrimaryTeal,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                ])
              : RefreshIndicator(
                  onRefresh: _fetchInbox,
                  color: _siPrimaryTeal,
                  child: _negotiations.isEmpty
                      ? ListView(children: const [
                          SizedBox(height: 80),
                          Icon(Icons.inbox_outlined,
                              size: 44, color: Color(0xFF9CA3AF)),
                          SizedBox(height: 12),
                          Center(
                            child: Text('No bargain requests yet',
                                style: TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF9CA3AF))),
                          ),
                        ])
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 16),
                          itemCount: _negotiations.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, i) =>
                              _buildCard(_negotiations[i]),
                        ),
                ),
    );
  }

  Widget _buildCard(Map<String, dynamic> n) {
    final status = (n['status'] ?? '').toString();
    final isActive = status == 'PENDING' || status == 'COUNTERED';
    final lastBy = (n['lastOfferedBy'] ?? '').toString();
    final canAccept = isActive && lastBy != 'SUPPLIER' && lastBy != 'supplier';
    final original = _d(n['originalPrice']);
    final proposed = _d(n['currentProposedPrice'] ?? n['proposedPrice']);
    final quantity = _d(n['quantity']);
    final unit = (n['unit'] ?? '').toString();
    final buyerName =
        ((n['shopOwnerName'] ?? '') .toString().isNotEmpty)
            ? n['shopOwnerName'].toString()
            : 'Shop Owner';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _siBorderGray),
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
                        color: _siDarkText)),
              ),
              _statusChip(status),
            ],
          ),
          const SizedBox(height: 4),
          Text(buyerName,
              style: const TextStyle(fontSize: 13, color: _siMutedText)),
          const Divider(height: 18, color: _siBorderGray),
          Row(
            children: [
              Text('৳${original.toStringAsFixed(2)}/$unit',
                  style: const TextStyle(
                      fontSize: 13,
                      color: _siMutedText,
                      decoration: TextDecoration.lineThrough)),
              const SizedBox(width: 8),
              const Icon(Icons.trending_down_rounded,
                  size: 15, color: _siPrimaryTeal),
              Text(' ৳${proposed.toStringAsFixed(2)}/$unit',
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: _siPrimaryTeal)),
              const Spacer(),
              // Latest proposal indicator
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: lastBy == 'SUPPLIER' || lastBy == 'supplier'
                      ? const Color(0xFFEEF8F6)
                      : const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  lastBy == 'SUPPLIER' || lastBy == 'supplier'
                      ? 'Your offer'
                      : 'Buyer\u2019s offer',
                  style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: lastBy == 'SUPPLIER' || lastBy == 'supplier'
                          ? _siPrimaryTeal
                          : const Color(0xFFB45309)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text('${_fmt(quantity)} $unit',
                  style: const TextStyle(
                      fontSize: 13, color: Color(0xFF374151))),
              const Spacer(),
              if ((n['shopOwnerName'] ?? '').toString().isNotEmpty)
                Text('Buyer: ${n['shopOwnerName']}',
                    style:
                        const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
            ],
          ),
          if ((n['message'] ?? '').toString().isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: const Border(
                    left: BorderSide(color: _siPrimaryTeal, width: 3)),
              ),
              child: Text(n['message'].toString(),
                  style: const TextStyle(
                      fontSize: 13, color: Color(0xFF374151))),
            ),
          ],
          const SizedBox(height: 12),
          if (isActive)
            Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _actingId != null
                            ? null
                            : () => _act(n['id'], 'decline'),
                        icon: const Icon(Icons.close_rounded, size: 15),
                        label: const Text('Decline',
                            style: TextStyle(fontSize: 12)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFEF4444),
                          side:
                              const BorderSide(color: Color(0xFFEF4444)),
                          padding:
                              const EdgeInsets.symmetric(vertical: 9),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: OutlinedButton.icon(
                        onPressed: _actingId != null
                            ? null
                            : () => _showCounterOfferDialog(n),
                        icon:
                            const Icon(Icons.add_circle_outline, size: 15),
                        label: const Text('Counter Offer',
                            style: TextStyle(fontSize: 12)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _siPrimaryTeal,
                          side: const BorderSide(color: _siPrimaryTeal),
                          padding:
                              const EdgeInsets.symmetric(vertical: 9),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: !canAccept
                            ? () => _openChat(n)
                            : (_actingId != null
                                ? null
                                : () => _act(n['id'], 'finalize')),
                        icon: _actingId == n['id']
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white))
                            : const Icon(Icons.check_circle_outline,
                                size: 15),
                        label: Text(canAccept ? 'Accept' : 'Chat',
                            style: const TextStyle(fontSize: 12)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F4C3A),
                          foregroundColor: Colors.white,
                          disabledBackgroundColor:
                              const Color(0xFFD1D5DB),
                          elevation: 0,
                          padding:
                              const EdgeInsets.symmetric(vertical: 9),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    onPressed: () => _openChat(n),
                    icon: const Icon(Icons.forum_outlined, size: 14),
                    label: const Text('Open Chat',
                        style: TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(
                      foregroundColor: _siMutedText,
                    ),
                  ),
                ),
              ],
            )
          else ...[
            Text(
              status == 'ACCEPTED' || status == 'ORDER_CREATED'
                  ? 'Deal confirmed — order placed.'
                  : 'Declined.',
              style: const TextStyle(
                  fontSize: 12.5,
                  fontStyle: FontStyle.italic,
                  color: _siMutedText),
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _openChat(n),
                icon: const Icon(Icons.forum_outlined, size: 14),
                label: const Text('View Chat',
                    style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(
                  foregroundColor: _siPrimaryTeal,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                ),
              ),
            ),
          ],
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
      case 'ACCEPTED':
      case 'ORDER_CREATED':
        bg = const Color(0xFFECFDF5);
        fg = const Color(0xFF059669);
        break;
      case 'REJECTED':
        bg = const Color(0xFFFEF2F2);
        fg = const Color(0xFFDC2626);
        break;
      default:
        bg = const Color(0xFFEEF8F6);
        fg = _siPrimaryTeal;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(status.toLowerCase(),
          style: TextStyle(
              fontSize: 10.5, fontWeight: FontWeight.w700, color: fg)),
    );
  }

  static double _d(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? 0;
  }

  static String _fmt(double q) =>
      q == q.roundToDouble() ? q.toInt().toString() : q.toStringAsFixed(1);
}
