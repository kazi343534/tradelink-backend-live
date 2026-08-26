import '../../../../../core/services/api_service.dart';
import '../../../../marketplace/services/marketplace_service.dart';
import '../../../../marketplace/models/marketplace_product_model.dart';

/// ── Agentic Execution Loop ────────────────────────────────────────
/// Deterministic planner + registered tools + bounded iterations.
///
/// To upgrade to LLM-driven planning later, implement `AgentPlanner`
/// with an OpenAI/Gemini function-calling adapter — the tool registry,
/// loop controller, and UI contract stay identical.

typedef StepCallback = void Function(AgentStep step);

enum AgentStepType { thought, tool, result, answer }

class AgentStep {
  final AgentStepType type;
  final String tool;
  final String title;
  final String detail;

  const AgentStep({
    required this.type,
    required this.title,
    this.detail = '',
    this.tool = '',
  });
}

class PlacedOrder {
  final String productName;
  final int quantity;
  final String unit;
  final double totalPrice;
  final String orderId;

  const PlacedOrder({
    required this.productName,
    required this.quantity,
    required this.unit,
    required this.totalPrice,
    required this.orderId,
  });
}

class AgentRunResult {
  final List<AgentStep> steps;
  final String reply;
  final List<PlacedOrder> placedOrders;
  final List<String> failedItems;
  final List<String> cancelledItems;

  const AgentRunResult({
    required this.steps,
    required this.reply,
    required this.placedOrders,
    required this.failedItems,
    this.cancelledItems = const [],
  });
}

/// A pending order awaiting explicit user confirmation before placement.
class OrderProposal {
  final String productName;
  final String supplierName;
  final double pricePerUnit;
  final String unit;
  final int quantity;
  final double total;
  final String distanceLabel;
  final double rating;
  final int ratingCount;

  const OrderProposal({
    required this.productName,
    required this.supplierName,
    required this.pricePerUnit,
    required this.unit,
    required this.quantity,
    required this.total,
    required this.distanceLabel,
    required this.rating,
    required this.ratingCount,
  });
}

/// UI hook: resolves true when the user confirms the order.
typedef ConfirmOrderCallback = Future<bool> Function(OrderProposal proposal);

/// Parsed bulk-order item coming from the user prompt.
class AgentOrderItem {
  final String name;
  final int quantity;

  const AgentOrderItem({required this.name, required this.quantity});
}

/// Full parsed intent: items + preferred sorting for the search tool.
class AgentOrderIntent {
  final List<AgentOrderItem> items;
  final String sortBy; // 'price' | 'rating' | 'distance'

  const AgentOrderIntent({required this.items, required this.sortBy});
}

/// Registered tool metadata — OpenAI/Gemini-compatible JSON schema.
class AgentToolSpec {
  final String name;
  final String description;
  final Map<String, dynamic> parameters; // JSON Schema

  const AgentToolSpec({
    required this.name,
    required this.description,
    required this.parameters,
  });
}

abstract class AgentTools {
  /// Registry exposed in OpenAI `tools:` format for future LLM planners.
  static const List<AgentToolSpec> specs = [
    AgentToolSpec(
      name: 'searchProducts',
      description: 'Search nearby supplier inventory by product name.',
      parameters: {
        'type': 'object',
        'properties': {
          'query': {'type': 'string'},
        },
        'required': ['query'],
      },
    ),
    AgentToolSpec(
      name: 'checkInventoryAndPrice',
      description:
          'Fetch live stock quantity and per-unit price for a listing.',
      parameters: {
        'type': 'object',
        'properties': {
          'productId': {'type': 'string'},
        },
        'required': ['productId'],
      },
    ),
    AgentToolSpec(
      name: 'placeOrder',
      description: 'Place a direct order for the given listing.',
      parameters: {
        'type': 'object',
        'properties': {
          'productId': {'type': 'string'},
          'quantity': {'type': 'integer'},
          'maxPrice': {'type': 'number'},
        },
        'required': ['productId', 'quantity'],
      },
    ),
  ];
}

/// Spec-shaped single intent (see [AgentEngine.parseUserMessage]).
class ParsedUserIntent {
  final String cleanSearchQuery;
  final int quantity;
  final String sortBy; // 'price_asc' | 'price_desc' | 'rating_desc' | 'distance_asc'

  const ParsedUserIntent({
    required this.cleanSearchQuery,
    required this.quantity,
    required this.sortBy,
  });
}

class AgentEngine {
  final int maxIterations;
  AgentEngine({this.maxIterations = 5});

  // ── Prompt parsing: typo-tolerant sanitizer ──────────────────────
  // Handles filler verbs, pronouns, adjectives and misspellings:
  //   "order chepest oil 1 littter" → oil ×1, sort by price
  //   "oder for me oil 10"          → oil ×10
  //   "oil=10, rice=5"              → oil ×10, rice ×5

  static const String _triggerWords =
      r'(order|oder|buy|purchase|need|want|kino|kinbo|dorkar|lagbe|chaile|dao|deu)';

  static final RegExp _unitWords = RegExp(
      r'\b(dostha|dosta|litres|litre|liter|litter|ltrs|ltr|l|kilograms|kilogram|kgs|kg|grams|gram|gm|pieces|piece|pcs|ta)\b',
      caseSensitive: false);

  static final RegExp _fillerWords = RegExp(
    r'\b(order|oder|odrer|buy|purches|purchase|get|gimme|give|need|want|'
    r'for me|forme|pls|plz|please|aamake|amar|'
    r'cheapest|chepest|cheepset|cheap|low price|low cost|lowest|low|most expensive|expensive|price|'
    r'nearest|near me|near|closer|'
    r'best|top rated|highest rated|highest|rating|rated|top|quality|good|fresh|'
    r'littter|littr|kino|kinbo|dorkar|lagbe|chaile|dao|deu|me|i|my|the|a|an|some|any|of|and)\b',
    caseSensitive: false,
  );

  /// Returns null when the prompt is not an order request.
  static AgentOrderIntent? parseOrderIntent(String rawInput) {
    final lower = rawInput.trim().toLowerCase();
    if (lower.isEmpty) return null;

    // Gate: must look like an order (explicit verb, '=' syntax, or a unit)
    final hasVerb = RegExp(_triggerWords, caseSensitive: false).hasMatch(lower);
    final hasEq = lower.contains('=');
    final hasUnit = _unitWords.hasMatch(lower);
    if (!hasVerb && !hasEq && !hasUnit) return null;

    // 1. Quantity: first standalone integer in the whole prompt
    int quantity = 1;
    final qtyMatch = RegExp(r'\b(\d+)\b').firstMatch(lower);
    if (qtyMatch != null) {
      quantity = int.tryParse(qtyMatch.group(1)!) ?? 1;
    }

    // 2. Sorting intent (4-way, incl. descending price)
    String sortBy = 'distance_asc';
    if (lower.contains('chepest') ||
        lower.contains('cheapest') ||
        lower.contains('cheap') ||
        lower.contains(RegExp(r'\blow (price|cost)\b')) ||
        lower.contains('lowest price')) {
      sortBy = 'price_asc';
    } else if (lower.contains('highest price') ||
        lower.contains('most expensive') ||
        lower.contains('expensive')) {
      sortBy = 'price_desc';
    } else if (lower.contains('lowest rated') ||
        lower.contains('worst rated') ||
        lower.contains('low rating') ||
        RegExp(r'\blowest\b')
            .hasMatch(lower) &&
            (lower.contains('rated') || lower.contains('rating'))) {
      sortBy = 'rating_asc';
    } else if (lower.contains('rating') ||
        lower.contains('highest rating') ||
        lower.contains('best rated') ||
        lower.contains('top rated')) {
      sortBy = 'rating_desc';
    }

    // 3. Per-segment product extraction (supports comma-separated items)
    final items = <AgentOrderItem>[];
    for (final rawSeg in lower.split(',')) {
      // Key-value pairs carry their own quantity: "oil=10"
      String segText = rawSeg.trim();
      String? kvQty;
      if (segText.contains('=')) {
        final pieces = segText.split('=');
        segText = pieces[0].trim();
        kvQty = pieces.length > 1 ? pieces[1].trim() : null;
      }
      if (segText.isEmpty) continue;

      // Segment-local quantity: explicit "=N" wins, else first number in text,
      // else the prompt-level default.
      int segQty = quantity;
      final numInKv = kvQty != null ? double.tryParse(kvQty) : null;
      if (numInKv != null && numInKv > 0) {
        segQty = numInKv.round();
      } else {
        final numInSeg =
            RegExp(r'\b(\d+(?:\.\d+)?)\b').firstMatch(segText);
        final n = numInSeg != null ? double.tryParse(numInSeg.group(1)!) : null;
        if (n != null && n > 0) segQty = n.round();
      }

      var cleaned = segText
          .replaceAll(_fillerWords, ' ')
          .replaceAll(_unitWords, ' ')
          .replaceAll(RegExp(r'\d+'), ' ')
          .replaceAll(RegExp(r'[^a-z\s]'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();

      // Drop single-letter residue
      cleaned = cleaned
          .split(' ')
          .where((w) => w.length >= 2)
          .join(' ');

      if (cleaned.length < 3) continue;
      items.add(AgentOrderItem(name: cleaned, quantity: segQty));
    }

    return items.isNotEmpty ? AgentOrderIntent(items: items, sortBy: sortBy) : null;
  }

  /// Spec-compliant single-product extraction. Multi-item prompts are
  /// handled by [parseOrderIntent]; this wraps its first item.
  static ParsedUserIntent? parseUserMessage(String input) {
    final intent = parseOrderIntent(input);
    if (intent == null || intent.items.isEmpty) return null;
    return ParsedUserIntent(
      cleanSearchQuery: intent.items.first.name,
      quantity: intent.items.first.quantity,
      sortBy: intent.sortBy,
    );
  }

  /// Maps the 4-way sort values to backend-supported keys.
  /// Accepts BOTH vocabularies: regex parser ('price_asc', 'rating_desc')
  /// and LLM planner ('price', 'rating').
  static String mapSortForBackend(String sortBy) {
    switch (sortBy) {
      case 'price':
      case 'price_asc':
        return 'price';
      case 'price_desc':
        return 'price_desc';
      case 'rating':
      case 'rating_desc':
        return 'rating';
      case 'rating_asc':
        return 'rating_asc';
      case 'distance':
      case 'distance_asc':
      default:
        return 'distance';
    }
  }

  // ── The loop ──

  Future<AgentRunResult> runOrderTask(
    List<AgentOrderItem> items, {
    StepCallback? onStep,
    ConfirmOrderCallback? onConfirm,
    String sortBy = 'distance_asc',
  }) async {
    final backendSort = mapSortForBackend(sortBy);
    final steps = <AgentStep>[];
    final placed = <PlacedOrder>[];
    final failed = <String>[];
    final cancelled = <String>[];
    final queue = List<AgentOrderItem>.from(items);

    void emit(AgentStep s) {
      steps.add(s);
      onStep?.call(s);
    }

    var iteration = 0;
    while (queue.isNotEmpty && iteration < maxIterations) {
      iteration++;
      final item = queue.removeAt(0);

      // ── Thought ──
      emit(AgentStep(
        type: AgentStepType.thought,
        title: 'Round $iteration/$maxIterations — resolving "${item.name}"',
        detail: 'Need ${_fmtQ(item.quantity)} units. Searching nearby inventory…',
      ));

      // ── Tool: searchProducts ──
      emit(AgentStep(
        type: AgentStepType.tool,
        tool: 'searchProducts',
        title: 'searchProducts("${item.name}")',
        detail: 'Querying marketplace inventory…',
      ));

      List<MarketplaceProductModel> matches = [];
      try {
        final res = await MarketplaceService.searchProducts(
            query: item.name, sortBy: backendSort, limit: 5);
        matches = res.products;
      } catch (e) {
        emit(AgentStep(
          type: AgentStepType.result,
          title: 'searchProducts failed',
          detail: '$e — feeding error back into context',
        ));
        failed.add(item.name);
        continue;
      }

      if (matches.isEmpty) {
        // Resilient fallback: retry once with the first word only
        final relaxed = item.name.split(' ').first;
        if (relaxed.length >= 3 && relaxed != item.name) {
          emit(AgentStep(
            type: AgentStepType.thought,
            title: 'No exact match — relaxing query to "$relaxed"',
          ));
          try {
            final res = await MarketplaceService.searchProducts(
                query: relaxed, sortBy: backendSort, limit: 5);
            matches = res.products;
          } catch (_) {}
        }
        if (matches.isEmpty) {
          emit(AgentStep(
            type: AgentStepType.result,
            title: '"${item.name}" not available nearby',
            detail: 'Skipping this item and continuing.',
          ));
          failed.add(item.name);
          continue;
        }
      }

      final best = matches.first;

      // ── Tool: checkInventoryAndPrice ──
      emit(AgentStep(
        type: AgentStepType.tool,
        tool: 'checkInventoryAndPrice',
        title: 'checkInventoryAndPrice("${best.stockId}")',
        detail:
            '${best.supplierName} • ${best.distanceLabel} • listed ৳${best.pricePerUnit.toStringAsFixed(2)}/${best.unit}',
      ));

      var qty = item.quantity;
      if (!best.inStock || best.quantityAvailable <= 0) {
        emit(AgentStep(
          type: AgentStepType.result,
          title: 'outOfStock: true',
          detail: 'Evaluating next candidate item without crashing…',
        ));
        failed.add(item.name);
        continue;
      }
      if (qty > best.quantityAvailable) {
        emit(AgentStep(
          type: AgentStepType.thought,
          title:
              'Only ${best.quantityAvailable.toStringAsFixed(0)} ${best.unit} in stock — reducing quantity autonomously',
        ));
        qty = best.quantityAvailable.toInt();
      }

      // ── Confirmation gate: never order without explicit approval ──
      if (onConfirm != null) {
        final proposal = OrderProposal(
          productName: best.productName,
          supplierName: best.supplierName,
          pricePerUnit: best.pricePerUnit,
          unit: best.unit,
          quantity: qty,
          total: best.pricePerUnit * qty,
          distanceLabel: best.distanceLabel,
          rating: best.rating,
          ratingCount: best.ratingCount,
        );
        emit(AgentStep(
          type: AgentStepType.thought,
          title: 'Awaiting confirmation for "${best.productName}" ×$qty',
          detail:
              '৳${best.pricePerUnit.toStringAsFixed(2)}/${best.unit} → total ৳${proposal.total.toStringAsFixed(2)}',
        ));
        final confirmed = await onConfirm(proposal);
        if (!confirmed) {
          emit(AgentStep(
            type: AgentStepType.result,
            title: 'Cancelled by user',
            detail: '"${item.name}" was not ordered.',
          ));
          cancelled.add(item.name);
          continue;
        }
      }

      // ── Tool: placeOrder ──
      emit(AgentStep(
        type: AgentStepType.tool,
        tool: 'placeOrder',
        title: 'placeOrder(${best.productName}, $qty)',
        detail:
            '৳${best.pricePerUnit.toStringAsFixed(2)}/${best.unit} → total ৳${(best.pricePerUnit * qty).toStringAsFixed(2)}',
      ));

      try {
        final res = await ApiService.post('/orders/direct', body: {
          'stockId': best.stockId,
          'quantity': qty,
        });
        if (res == null) throw Exception('API rejected order');

        final orderId = res['order']?['id']?.toString() ?? '';
        placed.add(PlacedOrder(
          productName: best.productName,
          quantity: qty,
          unit: best.unit,
          totalPrice: best.pricePerUnit * qty,
          orderId: orderId,
        ));
        emit(AgentStep(
          type: AgentStepType.result,
          title: 'Order placed ✓',
          detail: 'Order ID: ${orderId.substring(0, 8.clamp(0, orderId.length))}…',
        ));
      } catch (e) {
        emit(AgentStep(
          type: AgentStepType.result,
          title: 'placeOrder failed',
          detail: '$e — will not retry automatically.',
        ));
        failed.add(item.name);
      }
    }

    if (iteration >= maxIterations && queue.isNotEmpty) {
      emit(AgentStep(
        type: AgentStepType.answer,
        title: 'Iteration limit reached ($maxIterations rounds)',
        detail: '${queue.length} item(s) deferred to keep the loop bounded.',
      ));
      for (final r in queue) {
        failed.add(r.name);
      }
    }

    return AgentRunResult(
      steps: steps,
      reply: _summarize(placed, failed, cancelled),
      placedOrders: placed,
      failedItems: failed,
      cancelledItems: cancelled,
    );
  }

  String _summarize(
      List<PlacedOrder> placed, List<String> failed, List<String> cancelled) {
    final parts = <String>[];
    if (placed.isNotEmpty) {
      parts.add(
          'Placed ${placed.length} order${placed.length > 1 ? 's' : ''}: ${placed.map((p) => p.productName).join(', ')}');
    }
    if (cancelled.isNotEmpty) {
      parts.add('Cancelled: ${cancelled.join(', ')}');
    }
    if (failed.isNotEmpty) {
      parts.add('Could not order: ${failed.join(', ')}');
    }
    return parts.join(' • ');
  }

  static String _fmtQ(num q) =>
      q == q.roundToDouble() ? q.toInt().toString() : q.toStringAsFixed(1);
}
