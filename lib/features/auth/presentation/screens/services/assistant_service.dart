import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../../core/config/api_config.dart';
import '../models/supplier_result.dart';
import 'agent_engine.dart';

/// One parsed line of a multi-item bulk order (e.g. "oil=10").
class PendingOrderItem {
  final String name;
  final double quantity;
  final SupplierResult? match;

  const PendingOrderItem({
    required this.name,
    required this.quantity,
    this.match,
  });

  factory PendingOrderItem.fromJson(Map<String, dynamic> json) {
    final matchJson = json['match'] as Map<String, dynamic>?;
    return PendingOrderItem(
      name: json['name']?.toString() ?? '',
      quantity:
          (json['quantity'] is num) ? (json['quantity'] as num).toDouble() : 0,
      match: matchJson != null ? SupplierResult.fromJson(matchJson) : null,
    );
  }

  double? get subtotal =>
      match != null ? match!.price * quantity : null;
}

/// Chat message model for the TradeLink Assistant.
class AssistantMessage {
  final String text;
  final bool isUser;
  final bool isTyping;
  final List<SupplierResult>? suppliers;
  final List<PendingOrderItem>? pendingItems;
  final List<AgentStep>? agentSteps;
  final bool isAgentLive;
  final List<PlacedOrder>? placedOrders;
  final DateTime time;

  AssistantMessage({
    required this.text,
    required this.isUser,
    this.isTyping = false,
    this.suppliers,
    this.pendingItems,
    this.agentSteps,
    this.isAgentLive = false,
    this.placedOrders,
    DateTime? time,
  }) : time = time ?? DateTime.now();
}

/// Serves the AI sourcing assistant.
///
/// Sends the user's message to the backend `/assistant/chat` endpoint which
/// performs intent classification, NLU parsing, and PostgreSQL search.
class AssistantService {
  static String get _baseUrl => ApiConfig.baseUrl;

  static Future<Map<String, String>> _headers() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id') ?? '';
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'X-User-Id': '$userId::shop_owner',
    };
  }

  /// Generates a reply by calling the backend assistant endpoint.
  Future<AssistantMessage> generateReply(String userText) async {
    try {
      final headers = await _headers();
      final uri = Uri.parse('$_baseUrl/assistant/chat');

      debugPrint('[AssistantService] Sending: "$userText"');

      final response = await http.post(
        uri,
        headers: headers,
        body: json.encode({'message': userText}),
      ).timeout(const Duration(seconds: 15));

      debugPrint('[AssistantService] Response ${response.statusCode}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final body = json.decode(response.body);
        if (body['success'] == true) {
          final data = body['data'] as Map<String, dynamic>;
          final reply = data['reply'] as String? ?? '';
          final intentType = data['intentType']?.toString();

          // Multi-item bulk order confirmation trigger
          if (intentType == 'MULTI_ITEM_ORDER') {
            final itemsJson = data['items'] as List<dynamic>? ?? [];
            final items = itemsJson
                .map((e) =>
                    PendingOrderItem.fromJson(e as Map<String, dynamic>))
                .toList();
            return AssistantMessage(
              text: reply,
              isUser: false,
              pendingItems: items,
            );
          }

          final suppliersJson = data['suppliers'] as List<dynamic>? ?? [];
          final suppliers = suppliersJson
              .map((s) => SupplierResult.fromJson(s as Map<String, dynamic>))
              .toList();

          return AssistantMessage(
            text: reply,
            isUser: false,
            suppliers: suppliers.isNotEmpty ? suppliers : null,
          );
        }
      }

      // If backend returns an error status, try to parse the error message
      String errorMsg = 'Sorry, I had trouble processing that. Please try again.';
      try {
        final body = json.decode(response.body);
        if (body['error'] != null) {
          errorMsg = 'Error: ${body['error']}';
        }
      } catch (_) {}

      return AssistantMessage(text: errorMsg, isUser: false);
    } on TimeoutException {
      debugPrint('[AssistantService] Timeout');
      return AssistantMessage(
        text: 'Request timed out. The server might be busy — please try again.',
        isUser: false,
      );
    } catch (e) {
      debugPrint('[AssistantService] Error: $e');
      return AssistantMessage(
        text: 'Network error — please check your connection and try again.',
        isUser: false,
      );
    }
  }
}
