import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/api_service.dart';
import '../../../auth/presentation/screens/orders_screen.dart';
import '../../../auth/presentation/screens/pending_orders_screen.dart';

const Color _ncPrimaryTeal = Color(0xFF0F766E);
const Color _ncScreenBg = Color(0xFFF8FAFC);
const Color _ncDarkText = Color(0xFF0F172A);
const Color _ncMutedText = Color(0xFF64748B);
const Color _ncBorderGray = Color(0xFFE2E8F0);

/// Real-time bargaining chat shared by Shop Owner and Supplier.
/// Sticky deal banner + message stream (4s polling) + offer-price input
/// and Accept & Confirm Order / Decline actions.
class NegotiationChatScreen extends StatefulWidget {
  final String negotiationId;
  const NegotiationChatScreen({super.key, required this.negotiationId});

  @override
  State<NegotiationChatScreen> createState() => _NegotiationChatScreenState();
}

class _NegotiationChatScreenState extends State<NegotiationChatScreen> {
  Map<String, dynamic>? _negotiation;
  List<Map<String, dynamic>> _messages = [];
  String? _error;
  bool _sending = false;
  bool _acting = false;
  bool _offerMode = false;
  Timer? _pollTimer;
  String _myRole = '';
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadMyContext();
    _fetchThread();
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) => _fetchThread());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMyContext() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _myRole = prefs.getString('user_role') ?? '');
  }

  bool get _isShopOwner => _myRole == 'shop_owner';

  String get _counterpartName {
    if (_negotiation == null) return '';
    final v = _isShopOwner
        ? _negotiation!['supplierName']
        : _negotiation!['shopOwnerName'];
    return v?.toString().isNotEmpty == true
        ? v.toString()
        : (_isShopOwner ? 'Supplier' : 'Shop Owner');
  }

  double _d(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? 0;
  }

  String _fmtQty(double q) =>
      q == q.roundToDouble() ? q.toInt().toString() : q.toStringAsFixed(1);

  bool get _threadActive {
    final status = (_negotiation?['status'] ?? '').toString();
    return status == 'PENDING' || status == 'COUNTERED';
  }

  /// Bidirectional offers: Accept is only available when the CURRENT
  /// offer came from the other party. If I made the last offer, I wait.
  String get _lastOfferedBy =>
      (_negotiation?['lastOfferedBy'] ?? 'shop_owner').toString();

  bool get _canAccept {
    if (!_threadActive) return false;
    final myType = _isShopOwner ? 'shop_owner' : 'supplier';
    return _lastOfferedBy != myType;
  }

  String get _waitingNote {
    final myType = _isShopOwner ? 'shop_owner' : 'supplier';
    if (_lastOfferedBy == myType) {
      return _lastOfferedBy == 'shop_owner'
          ? 'You sent \u09f3${_d(_negotiation?['proposedPrice']).toStringAsFixed(2)} \u2014 waiting for the supplier\u2019s response.'
          : 'You countered at \u09f3${_d(_negotiation?['proposedPrice']).toStringAsFixed(2)} \u2014 waiting for the shop owner.';
    }
    return 'Counter-offer received \u2014 review and respond below.';
  }

  Future<void> _fetchThread() async {
    final data =
        await ApiService.get('/negotiations/${widget.negotiationId}/messages');
    if (data != null && mounted) {
      setState(() {
        _negotiation = Map<String, dynamic>.from(data['negotiation'] ?? {});
        _messages = List<Map<String, dynamic>>.from(data['messages'] ?? []);
        _error = null;
      });
      _scrollToBottom();
    } else if (mounted && _negotiation == null) {
      setState(() => _error = 'Failed to load conversation.');
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final text = _inputController.text.trim();
    final price = _offerMode ? double.tryParse(text) : null;

    if (!_offerMode && text.isEmpty) return;
    if (_offerMode && (price == null || price <= 0)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Enter a valid offer price'),
          backgroundColor: Colors.orange));
      return;
    }

    setState(() => _sending = true);
    final result = await ApiService.post('/negotiations/message', body: {
      'negotiationId': widget.negotiationId,
      if (_offerMode) 'offeredPrice': price else 'message': text,
    });
    if (!mounted) return;
    setState(() {
      _sending = false;
      if (result != null) _inputController.clear();
    });
    if (result != null) {
      await _fetchThread();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Failed to send'),
          backgroundColor: Color(0xFFEF4444)));
    }
  }

  Future<void> _finalize() async {
    if (_acting || !_threadActive) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Accept Deal'),
        content: Text(
            'Confirm order at \u09f3${_d(_negotiation?['proposedPrice']).toStringAsFixed(2)} per unit \u00d7 ${_fmtQty(_d(_negotiation?['quantity']))}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F4C3A),
                foregroundColor: Colors.white),
            child: const Text('Accept'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _acting = true);
    final result =
        await ApiService.post('/negotiations/${widget.negotiationId}/finalize');
    if (!mounted) return;
    setState(() => _acting = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(result != null
          ? 'Deal accepted \u2014 order placed!'
          : 'Could not finalize. Try again.'),
      backgroundColor:
          result != null ? const Color(0xFF10B981) : const Color(0xFFEF4444),
      behavior: SnackBarBehavior.floating,
    ));
    _fetchThread();
  }

  Future<void> _declineThread() async {
    if (_acting || !_threadActive) return;
    setState(() => _acting = true);
    // Visible note in the thread, then terminate the negotiation.
    await ApiService.post('/negotiations/message', body: {
      'negotiationId': widget.negotiationId,
      'message':
          '${_isShopOwner ? "Shop owner" : "Supplier"} declined this negotiation.',
    });
    await ApiService.post('/negotiations/respond', body: {
      'negotiationId': widget.negotiationId,
      'action': 'decline',
    }).catchError((_) async {
      // Shop-owner-only decline endpoint rejected us (supplier side):
      // mark the thread dead via a terminal message instead.
      await ApiService.post('/negotiations/message', body: {
        'negotiationId': widget.negotiationId,
        'message': 'This negotiation has been withdrawn by the supplier.',
      });
    });
    if (!mounted) return;
    setState(() => _acting = false);
    _fetchThread();
  }

  bool _isMine(Map<String, dynamic> m) =>
      (m['senderType']?.toString() ?? '') ==
      (_isShopOwner ? 'SHOP_OWNER' : 'SUPPLIER');

  @override
  Widget build(BuildContext context) {
    final proposed = _d(_negotiation?['proposedPrice']);
    final original = _d(_negotiation?['originalPrice']);
    final quantity = _d(_negotiation?['quantity']);
    final unit = (_negotiation?['unit'] ?? '').toString();
    final productName = (_negotiation?['productName'] ?? '').toString();
    final status = (_negotiation?['status'] ?? '').toString();

    return Scaffold(
      backgroundColor: _ncScreenBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(productName.isNotEmpty ? productName : 'Negotiation',
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: _ncDarkText)),
            Text(_counterpartName,
                style: const TextStyle(fontSize: 12, color: _ncMutedText)),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF374151)),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            }
          },
        ),
      ),
      body: _negotiation == null
          ? Center(
              child: _error != null
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!,
                            style: const TextStyle(color: _ncMutedText)),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: _fetchThread,
                          style: ElevatedButton.styleFrom(
                              backgroundColor: _ncPrimaryTeal,
                              foregroundColor: Colors.white),
                          child: const Text('Retry'),
                        ),
                      ],
                    )
                  : const CircularProgressIndicator(color: _ncPrimaryTeal))
          : Column(
              children: [
                _buildDealBanner(original, proposed, unit, quantity),
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    itemCount: _messages.length,
                    itemBuilder: (context, i) => _buildBubble(_messages[i]),
                  ),
                ),
                // ── Deal actions / waiting state ──
                if (_threadActive && _canAccept)
                  _buildActionBar()
                else if (_threadActive)
                  Container(
                    width: double.infinity,
                    color: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    child: Row(
                      children: [
                        const Icon(Icons.hourglass_top_rounded,
                            size: 16, color: Color(0xFFB45309)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(_waitingNote,
                              style: const TextStyle(
                                  fontSize: 12.5, color: Color(0xFF92400E))),
                        ),
                      ],
                    ),
                  ),
                // ── Input bar / finalized lock banner ──
                if (_threadActive)
                  _buildInputBar()
                else
                  _buildFinalizedBanner(status),
              ],
            ),
    );
  }

  // ── Locked banner for finalized / declined threads ──
  Widget _buildFinalizedBanner(String status) {
    final accepted = status == 'ACCEPTED' || status == 'ORDER_CREATED';
    final price = _d(_negotiation?['proposedPrice']);
    final quantity = _d(_negotiation?['quantity']);
    final unit = (_negotiation?['unit'] ?? '').toString();
    final orderId = (_negotiation?['orderId'] ?? '').toString();

    return Container(
      width: double.infinity,
      color: accepted ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: Row(
        children: [
          Icon(
            accepted ? Icons.verified_rounded : Icons.cancel_rounded,
            size: 26,
            color:
                accepted ? const Color(0xFF059669) : const Color(0xFFDC2626),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  accepted ? 'Deal Finalized — Order Confirmed' : 'Negotiation Declined',
                  style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: accepted
                          ? const Color(0xFF065F46)
                          : const Color(0xFF991B1B)),
                ),
                if (accepted) ...[
                  const SizedBox(height: 2),
                  Text(
                    '\u09f3${price.toStringAsFixed(2)}/$unit \u00d7 ${_fmtQty(quantity)} $unit = \u09f3${(price * quantity).toStringAsFixed(2)} total',
                    style: const TextStyle(
                        fontSize: 12.5, color: Color(0xFF065F46)),
                  ),
                  if (orderId.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text('Order ID: $orderId',
                          style: const TextStyle(
                              fontSize: 10.5,
                              fontFamily: 'monospace',
                              color: Color(0xFF047857))),
                    ),
                ],
                const SizedBox(height: 6),
                // Track the confirmed order through its lifecycle
                TextButton.icon(
                  onPressed: () {
                    if (_isShopOwner) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const OrdersScreen()),
                      );
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const PendingOrdersScreen()),
                      );
                    }
                  },
                  icon: const Icon(Icons.local_shipping_outlined, size: 15),
                  label: const Text('View Order Status',
                      style:
                          TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  style: TextButton.styleFrom(
                    foregroundColor:
                        accepted ? const Color(0xFF047857) : const Color(0xFFDC2626),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                const SizedBox(height: 2),
                Text('Chat history is read-only.',
                    style: TextStyle(
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                        color: Colors.grey.shade600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Sticky deal banner ──
  Widget _buildDealBanner(
      double original, double proposed, String unit, double quantity) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: _ncBorderGray)),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Current negotiated price',
                  style: TextStyle(fontSize: 11, color: _ncMutedText)),
              const SizedBox(height: 2),
              Row(children: [
                Text('\u09f3${original.toStringAsFixed(2)}',
                    style: const TextStyle(
                        fontSize: 13,
                        color: _ncMutedText,
                        decoration: TextDecoration.lineThrough)),
                const SizedBox(width: 8),
                Text('\u09f3${proposed.toStringAsFixed(2)} / $unit',
                    style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: _ncPrimaryTeal)),
              ]),
            ],
          ),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text('Quantity',
                  style: TextStyle(fontSize: 11, color: _ncMutedText)),
              const SizedBox(height: 4),
              Text('${_fmtQty(quantity)} $unit',
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: _ncDarkText)),
            ],
          ),
        ],
      ),
    );
  }

  // ── Deal action bar ──
  Widget _buildActionBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _acting ? null : _declineThread,
              icon: const Icon(Icons.close_rounded, size: 16),
              label:
                  const Text('Decline', style: TextStyle(fontSize: 13)),
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
              onPressed: _acting ? null : _finalize,
              icon: _acting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check_circle_outline, size: 16),
              label: const Text('Accept & Confirm Order',
                  style: TextStyle(fontSize: 13)),
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
    );
  }

  // ── Input bar with offer-price toggle ──
  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: _ncBorderGray)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            IconButton(
              tooltip: _offerMode ? 'Switch to text' : 'Attach an offer price',
              onPressed: () => setState(() => _offerMode = !_offerMode),
              icon: Icon(
                _offerMode ? Icons.sell_rounded : Icons.sell_outlined,
                size: 22,
                color: _offerMode ? _ncPrimaryTeal : _ncMutedText,
              ),
            ),
            Expanded(
              child: TextField(
                controller: _inputController,
                keyboardType: _offerMode
                    ? const TextInputType.numberWithOptions(decimal: true)
                    : TextInputType.text,
                decoration: InputDecoration(
                  hintText: _offerMode
                      ? 'Your counter-offer price (\u09f3)'
                      : 'Type a message\u2026',
                  hintStyle:
                      const TextStyle(fontSize: 13.5, color: Color(0xFF9CA3AF)),
                  prefixText: _offerMode ? '\u09f3 ' : null,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide(
                          color: _ncPrimaryTeal, width: 1.5)),
                ),
                onSubmitted: (_) => _send(),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _sending ? null : _send,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _ncPrimaryTeal,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: _sending
                    ? const Padding(
                        padding: EdgeInsets.all(10),
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.send_rounded,
                        size: 19, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Message bubble (offer chips highlighted) ──
  Widget _buildBubble(Map<String, dynamic> m) {
    final mine = _isMine(m);
    final hasOffer = m['offeredPrice'] != null;
    final senderName = (m['senderName'] ?? '').toString();

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: hasOffer
              ? (mine ? const Color(0xFFECFDF5) : const Color(0xFFFFFBEB))
              : (mine ? _ncPrimaryTeal : Colors.white),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(14),
            topRight: const Radius.circular(14),
            bottomLeft: Radius.circular(mine ? 14 : 3),
            bottomRight: Radius.circular(mine ? 3 : 14),
          ),
          border:
              mine && !hasOffer ? null : Border.all(color: _ncBorderGray),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hasOffer)
              Container(
                margin: const EdgeInsets.only(bottom: 5),
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: mine
                      ? const Color(0xFF059669)
                      : const Color(0xFFF59E0B),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                    'OFFER: \u09f3${_d(m['offeredPrice']).toStringAsFixed(2)}',
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
              ),
            Text(m['message'].toString(),
                style: TextStyle(
                  fontSize: 13.5,
                  color: mine && !hasOffer ? Colors.white : _ncDarkText,
                )),
            if (!mine && senderName.isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(senderName,
                  style: const TextStyle(
                      fontSize: 10.5, color: _ncMutedText)),
            ],
          ],
        ),
      ),
    );
  }
}
