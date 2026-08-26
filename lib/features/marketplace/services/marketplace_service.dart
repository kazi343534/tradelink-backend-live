import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/config/api_config.dart';
import '../models/marketplace_product_model.dart';

class MarketplaceService {
  static String get _baseUrl {
    if (kIsWeb) {
      return ApiConfig.baseUrl;
    }
    return ApiConfig.baseUrl;
  }

  static Future<Map<String, String>> _headers() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id') ?? '';
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'X-User-Id': '$userId::shop_owner',
    };
  }

  /// Search/browse products in the marketplace with spatial filtering.
  /// When query is empty, returns ALL nearby products (browse mode).
  /// When query is provided, filters by product name or category (search mode).
  static Future<MarketplaceSearchResponse> searchProducts({
    String? query,
    double? shopLat,
    double? shopLng,
    String? category,
    double maxDistance = 50,
    String sortBy = 'distance',
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final headers = await _headers();
      final url = '$_baseUrl/marketplace/search';

      final body = <String, dynamic>{};
      if (shopLat != null) body['shopLat'] = shopLat;
      if (shopLng != null) body['shopLng'] = shopLng;

      final queryParams = <String, String>{
        'maxDistance': maxDistance.toString(),
        'sortBy': sortBy,
        'limit': limit.toString(),
        'offset': offset.toString(),
      };

      if (query != null && query.trim().isNotEmpty) {
        queryParams['query'] = query.trim();
      }

      if (category != null && category.isNotEmpty && category != 'All') {
        queryParams['category'] = category;
      }

      final uri = Uri.parse(url).replace(queryParameters: queryParams);

      debugPrint('[MarketplaceService] POST $uri');
      final response = await http.post(
        uri,
        headers: headers,
        body: json.encode(body),
      );

      debugPrint('[MarketplaceService] Response: ${response.statusCode} ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final respBody = json.decode(response.body);
        if (respBody['success'] == true) {
          return MarketplaceSearchResponse.fromJson(respBody['data']);
        }
      }

      return const MarketplaceSearchResponse(products: [], total: 0, hasMore: false);
    } catch (e) {
      debugPrint('[MarketplaceService] Search error: $e');
      return const MarketplaceSearchResponse(products: [], total: 0, hasMore: false);
    }
  }

  /// Get product details with supplier info
  static Future<MarketplaceProductModel?> getProductDetail({
    required String stockId,
    double? shopLat,
    double? shopLng,
  }) async {
    try {
      final headers = await _headers();
      final url = '$_baseUrl/marketplace/products/$stockId';

      final body = <String, dynamic>{};
      if (shopLat != null) body['shopLat'] = shopLat;
      if (shopLng != null) body['shopLng'] = shopLng;

      debugPrint('[MarketplaceService] POST $url');
      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: json.encode(body),
      );

      debugPrint('[MarketplaceService] Response: ${response.statusCode} ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final respBody = json.decode(response.body);
        if (respBody['success'] == true) {
          return MarketplaceProductModel.fromJson(respBody['data']);
        }
      }

      return null;
    } catch (e) {
      debugPrint('[MarketplaceService] Get detail error: $e');
      return null;
    }
  }

  /// Get products by category with spatial filtering
  static Future<MarketplaceSearchResponse> getProductsByCategory({
    required String category,
    double? shopLat,
    double? shopLng,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final headers = await _headers();
      final url = '$_baseUrl/marketplace/category/$category';

      final body = <String, dynamic>{};
      if (shopLat != null) body['shopLat'] = shopLat;
      if (shopLng != null) body['shopLng'] = shopLng;

      final queryParams = <String, String>{
        'limit': limit.toString(),
        'offset': offset.toString(),
      };

      final uri = Uri.parse(url).replace(queryParameters: queryParams);

      debugPrint('[MarketplaceService] POST $uri');
      final response = await http.post(
        uri,
        headers: headers,
        body: json.encode(body),
      );

      debugPrint('[MarketplaceService] Response: ${response.statusCode} ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final respBody = json.decode(response.body);
        if (respBody['success'] == true) {
          return MarketplaceSearchResponse.fromJson(respBody['data']);
        }
      }

      return const MarketplaceSearchResponse(products: [], total: 0, hasMore: false);
    } catch (e) {
      debugPrint('[MarketplaceService] Get by category error: $e');
      return const MarketplaceSearchResponse(products: [], total: 0, hasMore: false);
    }
  }
}
