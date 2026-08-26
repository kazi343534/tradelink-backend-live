import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/services/api_service.dart';
import 'shop_owner_home_screen.dart';
import 'models/supplier_result.dart';
import 'services/assistant_service.dart';
import 'services/agent_engine.dart';
import 'services/deepseek_planner.dart';
import '../../../../core/config/deepseek_config.dart';
import 'orders_screen.dart';
import 'supplier_comparison_screen.dart';

const Color _asPrimaryTeal = Color(0xFF0F766E);
const Color _asScreenBg = Color(0xFFF8FAFC);
const Color _asDarkText = Color(0xFF0F172A);
const Color _asMutedText = Color(0xFF64748B);
const Color _asBorderGray = Color(0xFFE2E8F0);
const Color _asLightGrayBox = Color(0xFFF1F5F9);
const Color _asGreen = Color(0xFF10B981);

class TradeLinkAssistantScreen extends StatefulWidget {
  const TradeLinkAssistantScreen({super.key});

  @override
  State<TradeLinkAssistantScreen> createState() =>
      _TradeLinkAssistantScreenState();
}

class _TradeLinkAssistantScreenState extends State<TradeLinkAssistantScreen> {
  final AssistantService _service = AssistantService();
  final AgentEngine _agent = AgentEngine(maxIterations: 5);
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isTyping = false;

  // ── Active search context ────────────────────────────────────────
  // Quick-action chips mutate this context instead of being sent to the
  // backend as new (garbage) product queries.
  List<SupplierResult> _activeSuppliers = [];
  String? _activeQuery;
  bool _sortedByDistance = false;
  double? _appliedMinRating;

  final List<AssistantMessage> _messages = [
    AssistantMessage(
      text: 'Hi! I\'m TradeLink Assistant. Ask me for any product and I\'ll '
          'find the best suppliers near you.',
      isUser: false,
    ),
  ];

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage(String rawText) async {
    final text = rawText.trim();
    if (text.isEmpty || _isTyping) return;
    _inputController.clear();

    setState(() {
      _messages.add(AssistantMessage(text: text, isUser: true));
      _isTyping = true;
    });
    _scrollToBottom();

    // ── Intent resolution: LLM first, regex fallback ──
    AgentOrderIntent? orderIntent;

    if (DeepSeekConfig.isConfigured) {
      // LLM handles ANY phrasing: typos, filler, no keywords needed.
      // On rate-limit/outage fall back to the local parser so ordering
      // still works offline of the LLM.
      orderIntent = await DeepSeekPlanner.extractIntent(text) ??
          AgentEngine.parseOrderIntent(text);
    } else {
      orderIntent = AgentEngine.parseOrderIntent(text);
    }

    if (orderIntent != null) {
      try {
        await _runAgentOrder(orderIntent.items, sortBy: orderIntent.sortBy);
      } catch (e) {
        // Engine already reports per-item failures; surface hard crashes too
        if (mounted) {
          setState(() {
            _isTyping = false;
            _messages.add(AssistantMessage(
              text:
                  'Sorry, I couldn\'t complete that order. Please try again.',
              isUser: false,
            ));
          });
        }
      } finally {
        // CRITICAL: always dismiss the typing indicator and re-enable input,
        // even if the agent loop throws mid-execution.
        if (mounted) setState(() => _isTyping = false);
      }
      return;
    }

    final reply = await _service.generateReply(text);

    if (!mounted) return;
    setState(() {
      _isTyping = false;
      _messages.add(reply);
      // A fresh typed query replaces the active search context.
      if (reply.suppliers != null && reply.suppliers!.isNotEmpty) {
        _activeSuppliers = List<SupplierResult>.from(reply.suppliers!);
        _activeQuery = text;
        _sortedByDistance = false;
        _appliedMinRating = null;
      }
    });
    _scrollToBottom();
  }

  /// Streams a live agentic execution for the parsed order items.
  Future<void> _runAgentOrder(List<AgentOrderItem> items,
      {String sortBy = 'distance'}) async {
    final liveIndex = _messages.length;
    setState(() {
      _messages.add(AssistantMessage(
        text: 'Working on your order — ${items.length} item${items.length > 1 ? 's' : ''}…',
        isUser: false,
        isAgentLive: true,
        agentSteps: const [],
      ));
    });
    _scrollToBottom();

    final result = await _agent.runOrderTask(items,
        sortBy: sortBy,
        onConfirm: _showOrderConfirmationDialog,
        onStep: (step) {
      if (!mounted) return;
      final msg = _messages[liveIndex];
      setState(() {
        _messages[liveIndex] = AssistantMessage(
          text: step.type == AgentStepType.answer ? step.title : 'Executing your order…',
          isUser: false,
          isAgentLive: true,
          agentSteps: [...(msg.agentSteps ?? const []), step],
          placedOrders: msg.placedOrders,
        );
      });
      _scrollToBottom();
    });

    if (!mounted) return;
    setState(() {
      _messages[liveIndex] = AssistantMessage(
        text: result.reply,
        isUser: false,
        placedOrders: result.placedOrders,
      );
    });
    _scrollToBottom();
  }

  /// Blocks the agent loop until the user confirms or cancels the order.
  Future<bool> _showOrderConfirmationDialog(OrderProposal p) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: _asBorderGray),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _asPrimaryTeal.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.receipt_long,
                  color: _asPrimaryTeal, size: 22),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text('Confirm Order',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: _asDarkText)),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _confirmRow('Product', p.productName),
            _confirmRow('Supplier', p.supplierName),
            _confirmRow('Unit price',
                '৳${p.pricePerUnit.toStringAsFixed(2)}/${p.unit}'),
            _confirmRow(
                'Quantity', '${p.quantity} ${p.unit}'),
            _confirmRow('Distance', p.distanceLabel),
            _confirmRow(
                'Rating',
                p.ratingCount > 0
                    ? '${p.rating}★ (${p.ratingCount} review${p.ratingCount > 1 ? 's' : ''})'
                    : 'No reviews yet'),
            const Divider(height: 20, color: _asBorderGray),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: _asDarkText)),
                Text(
                  '৳${p.total.toStringAsFixed(2)}',
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: _asPrimaryTeal),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(
                    color: _asMutedText, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _asPrimaryTeal,
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Confirm Order',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  Widget _confirmRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 13, color: _asMutedText)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _asDarkText)),
          ),
        ],
      ),
    );
  }

  /// 'Sort by distance instead' chip — re-sorts the ACTIVE result set
  /// by distance_km ASC without touching the original product query.
  void _applyDistanceSort() {
    if (_activeSuppliers.isEmpty) return;
    final sorted = List<SupplierResult>.from(_activeSuppliers)
      ..sort((a, b) {
        final da = a.distanceKm ?? double.infinity;
        final db = b.distanceKm ?? double.infinity;
        return da.compareTo(db);
      });
    setState(() {
      _sortedByDistance = true;
      _activeSuppliers = sorted;
      _messages.add(AssistantMessage(
        text: 'Sorted ${_resultLabel()} by nearest first. Still showing '
            'results for "$_queryLabel".',
        isUser: false,
        suppliers: sorted,
      ));
    });
    _scrollToBottom();
  }

  /// 'Only show 4.5★ & up' chip — filters the ACTIVE result set by
  /// rating >= 4.5 while keeping the original product query active.
  void _applyRatingFilter() {
    if (_activeSuppliers.isEmpty) return;
    final total = _activeSuppliers.length;
    final filtered =
        _activeSuppliers.where((s) => s.rating >= 4.5).toList();
    setState(() {
      _appliedMinRating = 4.5;
      if (filtered.isNotEmpty) {
        _activeSuppliers = filtered;
      }
      _messages.add(AssistantMessage(
        text: filtered.isEmpty
            ? 'No "${_queryLabel}" results are rated 4.5★ or higher yet. '
                'Showing all results instead.'
            : 'Showing ${filtered.length} of $total '
                '"${_queryLabel}" results rated 4.5★ & up.',
        isUser: false,
        suppliers: filtered.isEmpty ? _activeSuppliers : filtered,
      ));
    });
    _scrollToBottom();
  }

  String get _queryLabel => _activeQuery ?? 'your product';

  /// Sends each supplier-group of matched items as targeted open demands.
  /// Suppliers Accept/Decline from their Nearby Demands feed; accepting
  /// creates the real order for both parties.
  Future<void> _confirmMultiOrder(List<PendingOrderItem> items) async {
    // Group matched items per target supplier
    final groups = <String, List<Map<String, dynamic>>>{};
    final unmatched = <String>[];

    for (final item in items) {
      if (item.match == null) {
        unmatched.add(item.name);
        continue;
      }
      groups
          .putIfAbsent(item.match!.stockholderId, () => [])
          .add({
            'name': item.match!.productName,
            'quantity': item.quantity,
          });
    }

    if (groups.isEmpty && unmatched.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('None of those items are available to order.'),
          backgroundColor: Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    var sentTo = 0;
    final failedSuppliers = <String>[];

    for (final entry in groups.entries) {
      try {
        final result = await ApiService.post('/assistant/order', body: {
          'stockholderId': entry.key,
          'items': entry.value,
        });
        if (result != null) {
          sentTo++;
        } else {
          failedSuppliers.add(entry.value.first['name']?.toString() ?? 'supplier');
        }
      } catch (_) {
        failedSuppliers.add(entry.value.first['name']?.toString() ?? 'supplier');
      }
    }

    if (!mounted) return;
    final parts = <String>[
      if (sentTo > 0)
        'Request${sentTo == 1 ? '' : 's'} sent — waiting for supplier confirmation',
      if (failedSuppliers.isNotEmpty)
        'Failed: ${failedSuppliers.join(', ')}',
      if (unmatched.isNotEmpty) 'Skipped: ${unmatched.join(', ')}',
    ];
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(parts.join(' • ')),
        backgroundColor:
            failedSuppliers.isEmpty ? const Color(0xFF10B981) : const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _resultLabel() =>
      '${_activeSuppliers.length} result${_activeSuppliers.length == 1 ? '' : 's'}';

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _openSupplierComparison(SupplierResult best, List<SupplierResult> all) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SupplierComparisonScreen(
          product: '${best.storeName} — ${best.unit}',
          suppliers: all,
        ),
      ),
    );
  }

  void _handleOrderNow(SupplierResult supplier) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DirectOrderBottomSheet(supplier: supplier),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _asScreenBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        shape: const Border(
          bottom: BorderSide(color: Color(0xFFE2E8F0)),
        ),
        titleSpacing: 0,
        // Standard AppBar auto-clears the status bar / Dynamic Island.
        leadingWidth: 60,
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              size: 18, color: Color(0xFF64748B)),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              // Fallback if launched as a root screen
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                    builder: (_) => const ShopOwnerHomeScreen()),
              );
            }
          },
        ),
        title: _buildTitleBlock(),
        actions: [
          Container(
            width: 34,
            height: 34,
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              color: _asLightGrayBox,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.more_horiz_rounded,
              size: 20,
              color: _asDarkText,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                const _DateHeader(),
                ..._buildMessages(),
                if (_isTyping) const _TypingBubble(),
                const SizedBox(height: 16),
              ],
            ),
          ),
          _buildInputBar(context),
        ],
      ),
    );
  }

  List<Widget> _buildMessages() {
    return _messages.map((msg) {
      if (msg.isUser) {
        return _UserBubble(text: msg.text);
      }
      if (msg.pendingItems != null) {
        return _MultiItemConfirmationCard(
          items: msg.pendingItems!,
          onConfirm: () => _confirmMultiOrder(msg.pendingItems!),
        );
      }
      if (msg.isAgentLive && msg.agentSteps != null) {
        return _AgentStepCard(steps: msg.agentSteps!, live: true);
      }
      if (msg.placedOrders != null && msg.placedOrders!.isNotEmpty) {
        return _AgentResultCard(
          text: msg.text,
          orders: msg.placedOrders!,
          onViewOrders: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const OrdersScreen()),
          ),
        );
      }
      if (msg.suppliers != null) {
        return _AssistantReply(
          text: msg.text,
          suppliers: msg.suppliers!,
          onSeeAll: () => _openSupplierComparison(msg.suppliers!.first, msg.suppliers!),
          onSortByDistance: _applyDistanceSort,
          onRatingFilter: _applyRatingFilter,
          onOrderNow: _handleOrderNow,
        );
      }
      return _AssistantBubble(text: msg.text);
    }).toList();
  }

  Widget _buildTitleBlock() {
    return Row(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _asPrimaryTeal,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.chat_bubble_outline_rounded,
                size: 20,
                color: Colors.white,
              ),
            ),
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: _asGreen,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'TradeLink Assistant',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: _asDarkText,
                fontFamily: 'Sora',
              ),
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: _asGreen,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                const Text(
                  'Online',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _asGreen,
                    fontFamily: 'Inter',
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  // ---------- Input Bar ----------
  Widget _buildInputBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: _asBorderGray)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            const Icon(
              Icons.attach_file_rounded,
              size: 24,
              color: _asMutedText,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _inputController,
                textInputAction: TextInputAction.send,
                onSubmitted: _sendMessage,
                style: const TextStyle(
                  fontSize: 14,
                  color: _asDarkText,
                  fontFamily: 'Inter',
                ),
                decoration: InputDecoration(
                  hintText: 'Ask about another product...',
                  hintStyle: const TextStyle(
                    fontSize: 14,
                    color: _asMutedText,
                    fontFamily: 'Inter',
                  ),
                  filled: true,
                  fillColor: _asLightGrayBox,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: () => _sendMessage(_inputController.text),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _asPrimaryTeal,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.send_rounded,
                  size: 20,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------- Date Header ----------
class _DateHeader extends StatelessWidget {
  const _DateHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Text(
            'TODAY',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
              fontFamily: 'Inter',
            ),
          ),
        ),
      ),
    );
  }
}

// ---------- User Bubble ----------
class _UserBubble extends StatelessWidget {
  final String text;

  const _UserBubble({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF0F766E),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.white,
                fontFamily: 'Inter',
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '9:41 AM',
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF64748B),
              fontFamily: 'Inter',
            ),
          ),
        ],
      ),
    );
  }
}

// ---------- Assistant Bubble ----------
class _AssistantBubble extends StatelessWidget {
  final String text;

  const _AssistantBubble({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _AssistantAvatar(),
          const SizedBox(width: 10),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Text(
                text,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF0F172A),
                  fontFamily: 'Inter',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AssistantAvatar extends StatelessWidget {
  const _AssistantAvatar();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: const Color(0xFF0F766E),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(
        Icons.chat_bubble_outline_rounded,
        size: 16,
        color: Colors.white,
      ),
    );
  }
}

// ---------- Assistant Reply with product cards ----------
class _AssistantReply extends StatelessWidget {
  final String text;
  final List<SupplierResult> suppliers;
  final VoidCallback onSeeAll;
  final VoidCallback onSortByDistance;
  final VoidCallback onRatingFilter;
  final void Function(SupplierResult) onOrderNow;

  const _AssistantReply({
    required this.text,
    required this.suppliers,
    required this.onSeeAll,
    required this.onSortByDistance,
    required this.onRatingFilter,
    required this.onOrderNow,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _AssistantAvatar(),
              const SizedBox(width: 10),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Text(
                    text,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF0F172A),
                      fontFamily: 'Inter',
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 230,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: suppliers.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, index) => _ProductCard(
                supplier: suppliers[index],
                onOrderNow: onOrderNow,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _ActionChip(
                label: 'See all ${suppliers.length} results',
                isPrimary: true,
                onTap: onSeeAll,
              ),
              _ActionChip(
                label: 'Sort by distance instead',
                isPrimary: false,
                onTap: onSortByDistance,
              ),
              _ActionChip(
                label: 'Only show 4.5★ & up',
                isPrimary: false,
                onTap: onRatingFilter,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------- Product Card ----------
class _ProductCard extends StatelessWidget {
  final SupplierResult supplier;
  final void Function(SupplierResult) onOrderNow;

  const _ProductCard({required this.supplier, required this.onOrderNow});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 190,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF0F766E), width: 1.2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (supplier.isBestPrice)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF0F766E),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'BEST PRICE',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  fontFamily: 'Inter',
                ),
              ),
            ),
          if (supplier.isBestPrice) const SizedBox(height: 6),
          if (supplier.imageUrl != null && supplier.imageUrl!.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                supplier.imageUrl!,
                height: 50,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          if (supplier.imageUrl != null && supplier.imageUrl!.isNotEmpty)
            const SizedBox(height: 6),
          // Product title — falls back to supplier name when missing
          SizedBox(
            height: 20,
            width: double.infinity,
            child: Text(
              (supplier.productName.isNotEmpty ? supplier.productName : supplier.storeName),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
                fontFamily: 'Sora',
              ),
            ),
          ),
          const SizedBox(height: 2),
          // Supplier name + distance line
          Text(
            '${supplier.storeName} · ${supplier.distance}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF64748B),
              fontFamily: 'Inter',
            ),
          ),
          const SizedBox(height: 6),
          Text(
            supplier.priceLabel,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F766E),
              fontFamily: 'Inter',
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(
                Icons.location_on_outlined,
                size: 12,
                color: Color(0xFF64748B),
              ),
              const SizedBox(width: 2),
              Text(
                supplier.distance,
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF64748B),
                  fontFamily: 'Inter',
                ),
              ),
              const Spacer(),
              const Icon(
                Icons.star_rounded,
                size: 12,
                color: Color(0xFFF59E0B),
              ),
              const SizedBox(width: 2),
              Text(
                '${supplier.rating} ★',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0F172A),
                  fontFamily: 'Inter',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 32,
            child: ElevatedButton(
              onPressed: () => onOrderNow(supplier),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F766E),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Order now',
                style: TextStyle(
                  fontSize: 12,
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
}

// ---------- Action Chip ----------
class _ActionChip extends StatelessWidget {
  final String label;
  final bool isPrimary;
  final VoidCallback onTap;

  const _ActionChip({
    required this.label,
    required this.isPrimary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isPrimary ? const Color(0xFF0F766E) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: isPrimary
              ? null
              : Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isPrimary ? Colors.white : const Color(0xFF334155),
            fontFamily: 'Inter',
          ),
        ),
      ),
    );
  }
}

// ---------- Direct Order Bottom Sheet ----------
class _DirectOrderBottomSheet extends StatefulWidget {
  final SupplierResult supplier;

  const _DirectOrderBottomSheet({required this.supplier});

  @override
  State<_DirectOrderBottomSheet> createState() => _DirectOrderBottomSheetState();
}

class _DirectOrderBottomSheetState extends State<_DirectOrderBottomSheet> {
  late TextEditingController _qtyController;
  bool _isPlacing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _qtyController = TextEditingController(text: '1');
  }

  @override
  void dispose() {
    _qtyController.dispose();
    super.dispose();
  }

  double get _total =>
      (double.tryParse(_qtyController.text) ?? 0) * widget.supplier.price;

  Future<void> _placeOrder() async {
    final qty = double.tryParse(_qtyController.text);
    if (qty == null || qty <= 0) {
      setState(() => _error = 'Enter a valid quantity');
      return;
    }
    if (qty > widget.supplier.quantityAvailable) {
      setState(() => _error = 'Only ${widget.supplier.quantityAvailable.toStringAsFixed(0)} ${widget.supplier.unit} available');
      return;
    }

    setState(() {
      _isPlacing = true;
      _error = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id') ?? '';
      final uri = Uri.parse('https://tradelink-2.onrender.com/api/v1/orders/direct');

      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'X-User-Id': '$userId::shop_owner',
        },
        body: jsonEncode({
          'stockId': widget.supplier.stockId,
          'quantity': qty,
        }),
      ).timeout(const Duration(seconds: 15));

      if (!mounted) return;

      if (response.statusCode == 201 || response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body['success'] == true) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(body['data']['message'] ?? 'Order placed!'),
              backgroundColor: const Color(0xFF0F766E),
              behavior: SnackBarBehavior.floating,
            ),
          );
          return;
        }
      }

      String msg = 'Failed to place order';
      try {
        final body = jsonDecode(response.body);
        if (body['error'] != null) msg = body['error'];
      } catch (_) {}
      setState(() => _error = msg);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Network error — please try again');
    } finally {
      if (mounted) setState(() => _isPlacing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.supplier;
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F766E),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    s.productName ?? s.storeName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Inter',
                    ),
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, size: 20, color: Color(0xFF64748B)),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Supplier info
            Text(
              s.storeName,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0F172A),
                fontFamily: 'Sora',
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${s.location} · ${s.distance}',
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF64748B),
                fontFamily: 'Inter',
              ),
            ),
            const SizedBox(height: 12),

            // Price
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDFA),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '৳${s.price.toStringAsFixed(0)} / ${s.unit}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F766E),
                      fontFamily: 'Inter',
                    ),
                  ),
                  Row(
                    children: [
                      const Icon(Icons.star_rounded, size: 14, color: Color(0xFFF59E0B)),
                      const SizedBox(width: 2),
                      Text(
                        '${s.rating} ★',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0F172A),
                          fontFamily: 'Inter',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Quantity
            const Text(
              'Quantity',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF334155),
                fontFamily: 'Inter',
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _qtyButton(Icons.remove, () {
                  final curr = double.tryParse(_qtyController.text) ?? 1;
                  if (curr > 1) {
                    _qtyController.text = (curr - 1).toStringAsFixed(0);
                    setState(() {});
                  }
                }),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _qtyController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Inter',
                    ),
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFF0F766E), width: 1.5),
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      suffixText: s.unit,
                      suffixStyle: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF64748B),
                        fontFamily: 'Inter',
                      ),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 12),
                _qtyButton(Icons.add, () {
                  final curr = double.tryParse(_qtyController.text) ?? 0;
                  _qtyController.text = (curr + 1).toStringAsFixed(0);
                  setState(() {});
                }),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Available: ${s.quantityAvailable.toStringAsFixed(0)} ${s.unit}',
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF94A3B8),
                fontFamily: 'Inter',
              ),
            ),
            const SizedBox(height: 16),

            // Total
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF334155),
                    fontFamily: 'Inter',
                  ),
                ),
                Text(
                  '৳${_total.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F766E),
                    fontFamily: 'Inter',
                  ),
                ),
              ],
            ),

            // Error
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFFEF4444),
                  fontFamily: 'Inter',
                ),
              ),
            ],
            const SizedBox(height: 16),

            // Order button
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                onPressed: _isPlacing ? null : _placeOrder,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F766E),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: const Color(0xFF0F766E).withOpacity(0.5),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isPlacing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        'Place Order — ৳${_total.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Inter',
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _qtyButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Icon(icon, size: 18, color: const Color(0xFF334155)),
      ),
    );
  }
}

// ---------- Typing Indicator ----------
class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _AssistantAvatar(),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _PulsingDot(delay: Duration.zero),
                SizedBox(width: 4),
                _PulsingDot(delay: Duration(milliseconds: 150)),
                SizedBox(width: 4),
                _PulsingDot(delay: Duration(milliseconds: 300)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  final Duration delay;

  const _PulsingDot({required this.delay});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void initState() {
    super.initState();
    Future.delayed(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.3, end: 1.0).animate(_controller),
      child: Container(
        width: 7,
        height: 7,
        decoration: const BoxDecoration(
          color: Color(0xFF94A3B8),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
// ==================== Multi-Item Order Confirmation ====================

class _MultiItemConfirmationCard extends StatelessWidget {
  final List<PendingOrderItem> items;
  final VoidCallback onConfirm;

  const _MultiItemConfirmationCard({
    required this.items,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final matchable = items.where((i) => i.match != null).toList();
    final total = items.fold<double>(
      0,
      (sum, i) => sum + (i.subtotal ?? 0),
    );
    final hasMatch = matchable.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _AssistantAvatar(),
          const SizedBox(width: 10),
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...items.map(_buildItemRow),
                  if (hasMatch) ...[
                    const Divider(height: 20, color: Color(0xFFE2E8F0)),
                    Row(
                      children: [
                        const Text('Estimated total',
                            style: TextStyle(
                                fontSize: 13, color: Color(0xFF64748B))),
                        const Spacer(),
                        Text('৳${total.toStringAsFixed(2)}',
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0F766E))),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: onConfirm,
                        icon: const Icon(Icons.check_circle_outline,
                            size: 18),
                        label: const Text('Confirm Order'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F4C3A),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding:
                              const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemRow(PendingOrderItem item) {
    final match = item.match;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${item.quantity} ${match?.unit ?? ''} ${item.name}',
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0F172A)),
                ),
                if (match != null)
                  Text(
                    '${match.storeName} • ৳${match.price.toStringAsFixed(2)}/${match.unit} • ${match.distance}',
                    style: const TextStyle(
                        fontSize: 11.5, color: Color(0xFF64748B)),
                  )
                else
                  const Text(
                    'Not available nearby — will be skipped',
                    style: TextStyle(fontSize: 11.5, color: Color(0xFFEF4444)),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            match != null ? '৳${item.subtotal!.toStringAsFixed(2)}' : '—',
            style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1E293B)),
          ),
        ],
      ),
    );
  }
}

// ==================== Agent Step / Result Cards ====================

class _AgentStepCard extends StatelessWidget {
  final List<AgentStep> steps;
  final bool live;

  const _AgentStepCard({required this.steps, this.live = false});

  IconData _icon(AgentStepType t) => switch (t) {
        AgentStepType.thought => Icons.psychology_outlined,
        AgentStepType.tool => Icons.build_rounded,
        AgentStepType.result => Icons.check_circle_outline,
        AgentStepType.answer => Icons.smart_toy_outlined,
      };

  Color _color(AgentStepType t) => switch (t) {
        AgentStepType.thought => const Color(0xFF7C3AED),
        AgentStepType.tool => const Color(0xFF0284C7),
        AgentStepType.result => const Color(0xFF059669),
        AgentStepType.answer => const Color(0xFF0F766E),
      };

  @override
  Widget build(BuildContext context) {
    final last = steps.isNotEmpty ? steps.last : null;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _AssistantAvatar(),
          const SizedBox(width: 10),
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    if (live)
                      const SizedBox(
                        width: 13,
                        height: 13,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Color(0xFF0F766E)),
                      )
                    else
                      const Icon(Icons.smart_toy_outlined,
                          size: 15, color: Color(0xFF0F766E)),
                    const SizedBox(width: 6),
                    Text(live ? 'Agent working…' : 'Agent trace',
                        style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F766E))),
                  ]),
                  const SizedBox(height: 8),
                  ExpansionTileTheme(
                    data: const ExpansionTileThemeData(
                        iconColor: Color(0xFF94A3B8)),
                    child: Theme(
                      data: Theme.of(context)
                          .copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        childrenPadding: EdgeInsets.zero,
                        initiallyExpanded: true,
                        title: Text(
                          last?.title ?? 'Starting…',
                          style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF334155)),
                        ),
                        children: steps
                            .map((s) => Container(
                                  margin:
                                      const EdgeInsets.only(bottom: 6),
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFC),
                                    borderRadius:
                                        BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Icon(_icon(s.type),
                                          size: 13, color: _color(s.type)),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(s.title,
                                                style: const TextStyle(
                                                    fontSize: 11.5,
                                                    fontWeight:
                                                        FontWeight.w600,
                                                    color: Color(
                                                        0xFF334155))),
                                            if (s.detail.isNotEmpty)
                                              Text(s.detail,
                                                  style: const TextStyle(
                                                      fontSize: 10.5,
                                                      color: Color(
                                                          0xFF94A3B8))),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ))
                            .toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AgentResultCard extends StatelessWidget {
  final String text;
  final List<PlacedOrder> orders;
  final VoidCallback onViewOrders;

  const _AgentResultCard({
    required this.text,
    required this.orders,
    required this.onViewOrders,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _AssistantAvatar(),
          const SizedBox(width: 10),
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...orders.map((o) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(children: [
                          const Icon(Icons.receipt_long_rounded,
                              size: 14, color: Color(0xFF059669)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                                '${o.productName} × ${o.quantity} ${o.unit} — ৳${o.totalPrice.toStringAsFixed(2)}',
                                style: const TextStyle(
                                    fontSize: 12.5,
                                    color: Color(0xFF334155))),
                          ),
                        ]),
                      )),
                  const SizedBox(height: 6),
                  TextButton.icon(
                    onPressed: onViewOrders,
                    icon: const Icon(Icons.receipt_outlined, size: 15),
                    label: Text('View Order #ORD-${orders.first.orderId.substring(0, 4)}',
                        style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700)),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF0F4C3A),
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
