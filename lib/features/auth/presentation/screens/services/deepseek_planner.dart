import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../../../../core/config/deepseek_config.dart';
import 'agent_engine.dart';

/// LLM-powered intent extraction (DeepSeek via OpenAI-compatible API).
///
/// Converts messy conversational input into structured order parameters,
/// fixing typos and stripping modifiers — no regex needed. Returns null
/// on ANY failure so callers can fall back to the local rule-based parser.
class DeepSeekPlanner {
  static const String _systemPrompt = '''
You are TradeLink AI, an intelligent order assistant for an e-commerce platform.
Your job is to extract user intent, fix typos, and return structured JSON.

CRITICAL RULES:
1. Do NOT include action verbs ("order", "buy", "oder"), filler words
   ("for me", "please"), or search modifiers ("cheapest", "expensive",
   "best", "nearest") in the "query" parameter.
2. Extract ONLY the core product noun into "query" (e.g., "oil", "rice", "salt").
3. Automatically correct common typos ("oder" -> "order", "chepest" ->
   "cheapest", "littter" -> "litre").
4. Extract numeric quantity into "quantity" (default: 1).
5. Map adjectives to "sortBy":
   - "cheapest", "lowest price", "cheap", "low price" -> "price"
   - "expensive", "highest price" -> "price_desc"
   - "best", "highest rating", "top rated" -> "rating"
   - "lowest rated", "worst rated", "low rating" -> "rating_asc"
   - "nearest", "closest", default -> "distance"

Output strictly one minified JSON object, no prose, no markdown fences:
{"items":[{"query":"<clean_product_name>","quantity":<int>}],"sortBy":"<sort_type>"}
''';

  /// Fallback chain — free models are aggressively rate-limited (HTTP 429),
  /// so we rotate through alternatives before giving up to the regex parser.
  static const List<String> _modelChain = [
    'google/gemma-4-31b-it:free',
    'nvidia/nemotron-3-nano-30b-a3b:free',
    'liquid/lfm-2.5-2.6b:free',
  ];

  /// Calls the LLM and returns parsed items + sort preference.
  /// Returns null on missing config, network error, or unparseable output.
  static Future<AgentOrderIntent?> extractIntent(String userInput) async {
    if (!DeepSeekConfig.isConfigured) return null;
    final text = userInput.trim();
    if (text.length < 3) return null;

    final models = <String>[
      if (!_modelChain.contains(DeepSeekConfig.model)) DeepSeekConfig.model,
      ..._modelChain,
    ];

    for (final model in models) {
      final result = await _callModel(model, text);
      if (result != null) return result;
    }
    return null;
  }

  static Future<AgentOrderIntent?> _callModel(
      String model, String text) async {
    try {
      final body = jsonEncode({
        'model': model,
        'temperature': 0,
        'max_tokens': 300,
        'messages': [
          {'role': 'system', 'content': _systemPrompt},
          {'role': 'user', 'content': text},
        ],
      });

      final headers = {
        'Content-Type': 'application/json',
        if (DeepSeekConfig.apiKey.isNotEmpty)
          'Authorization': 'Bearer ${DeepSeekConfig.apiKey}',
        if (DeepSeekConfig.baseUrl.contains('openrouter'))
          'HTTP-Referer': 'https://tradelink.app',
        if (DeepSeekConfig.baseUrl.contains('openrouter'))
          'X-Title': 'TradeLink',
      };

      final response = await http
          .post(Uri.parse(DeepSeekConfig.baseUrl),
              headers: headers, body: body)
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 429 || response.statusCode >= 500) {
        // Brief pause honors Retry-After when provided, then rotate models.
        final retryAfter =
            int.tryParse(response.headers['retry-after'] ?? '') ?? 1;
        await Future<void>.delayed(
            Duration(seconds: retryAfter.clamp(1, 3)));
        debugPrint('[DeepSeekPlanner] $model rate-limited, rotating');
        return null;
      }
      if (response.statusCode != 200) {
        debugPrint('[DeepSeekPlanner] $model HTTP ${response.statusCode}');
        return null;
      }

      final decoded = jsonDecode(response.body);
      final content =
          decoded['choices']?[0]?['message']?['content']?.toString() ?? '';
      return _parseJsonPayload(content);
    } on TimeoutException {
      debugPrint('[DeepSeekPlanner] $model timeout');
      return null;
    } catch (e) {
      debugPrint('[DeepSeekPlanner] $model error: $e');
      return null;
    }
  }

  /// Robustly extracts the first JSON object from model output,
  /// tolerating markdown fences and leading prose.
  static AgentOrderIntent? _parseJsonPayload(String content) {
    var c = content.trim();
    final fence = RegExp(r'```(?:json)?\s*([\s\S]*?)```', multiLine: true)
        .firstMatch(c);
    if (fence != null) c = fence.group(1)!.trim();

    final start = c.indexOf('{');
    final end = c.lastIndexOf('}');
    if (start < 0 || end <= start) return null;

    try {
      final obj = jsonDecode(c.substring(start, end + 1));
      final sortByRaw = obj['sortBy']?.toString() ?? 'distance';
      const allowed = ['price', 'price_desc', 'rating', 'rating_asc', 'distance'];
      final sortBy = allowed.contains(sortByRaw) ? sortByRaw : 'distance';

      final itemsJson = obj['items'];
      if (itemsJson is List && itemsJson.isNotEmpty) {
        final items = <AgentOrderItem>[];
        for (final e in itemsJson) {
          final name =
              (e['query'] ?? e['name'] ?? '').toString().trim();
          final q = double.tryParse(e['quantity']?.toString() ?? '') ?? 1;
          if (name.length >= 2 && q > 0) {
            items.add(AgentOrderItem(name: name, quantity: q.round()));
          }
        }
        if (items.isEmpty) return null;
        return AgentOrderIntent(items: items, sortBy: sortBy);
      }

      // Single-item shape fallback: {"query":..., "quantity":...}
      final singleQuery = obj['query']?.toString().trim() ?? '';
      if (singleQuery.length >= 2) {
        final q =
            double.tryParse(obj['quantity']?.toString() ?? '') ?? 1;
        return AgentOrderIntent(
          items: [AgentOrderItem(name: singleQuery, quantity: q.round())],
          sortBy: sortBy,
        );
      }
      return null;
    } catch (e) {
      debugPrint('[DeepSeekPlanner] JSON parse failed: $e');
      return null;
    }
  }
}
