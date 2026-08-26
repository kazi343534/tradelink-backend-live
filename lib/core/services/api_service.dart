import 'dart:convert';
import '../../core/config/api_config.dart';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static String get _baseUrl {
    // Web always runs on the same machine, so localhost works.
    // Android emulator needs 10.0.2.2.
    if (kIsWeb) {
      return ApiConfig.baseUrl;
    }
    return ApiConfig.baseUrl;
  }

  static Future<Map<String, String>> _headers() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id') ?? '';
    final role = prefs.getString('user_role') ?? 'supplier';
    debugPrint('[ApiService] userId=$userId role=$role');
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'X-User-Id': '$userId::$role',
    };
  }

  static Future<dynamic> get(String path) async {
    try {
      final headers = await _headers();
      final url = '$_baseUrl$path';
      debugPrint('[ApiService] GET $url');
      final response = await http.get(Uri.parse(url), headers: headers);
      debugPrint('[ApiService] GET ${response.statusCode} ${response.body}');
      final body = json.decode(response.body);
      if ((response.statusCode == 200 || response.statusCode == 201) && body['success'] == true) {
        return body['data'] ?? body;
      }
      return null;
    } catch (e) {
      debugPrint('[ApiService] GET ERROR: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> post(String path, {Map<String, dynamic>? body}) async {
    try {
      final headers = await _headers();
      final url = '$_baseUrl$path';
      debugPrint('[ApiService] POST $url body=$body');
      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: body != null ? json.encode(body) : null,
      );
      debugPrint('[ApiService] POST ${response.statusCode} ${response.body}');
      final respBody = json.decode(response.body);
      if ((response.statusCode == 200 || response.statusCode == 201) && respBody['success'] == true) {
        return respBody['data'];
      }
      return null;
    } catch (e) {
      debugPrint('[ApiService] POST ERROR: $e');
      return null;
    }
  }

  static Future<dynamic> patch(String path, {Map<String, dynamic>? body}) async {
    try {
      final headers = await _headers();
      final url = '$_baseUrl$path';
      debugPrint('[ApiService] PATCH $url body=$body');
      final response = await http.patch(
        Uri.parse(url),
        headers: headers,
        body: body != null ? json.encode(body) : null,
      );
      debugPrint('[ApiService] PATCH ${response.statusCode} ${response.body}');
      final respBody = json.decode(response.body);
      if ((response.statusCode == 200 || response.statusCode == 201) && respBody['success'] == true) {
        return respBody['data'] ?? respBody;
      }
      return null;
    } catch (e) {
      debugPrint('[ApiService] PATCH ERROR: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> postMultipart(
    String path, {
    required Map<String, String> fields,
    Uint8List? imageBytes,
    String? imageFileName,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id') ?? '';
      final uri = Uri.parse('$_baseUrl$path');
      final request = http.MultipartRequest('POST', uri);
      request.headers['X-User-Id'] = '$userId::supplier';
      request.fields.addAll(fields);

      if (imageBytes != null && imageBytes.isNotEmpty) {
        final fileName = imageFileName ?? 'product.jpg';
        final ext = fileName.split('.').last.toLowerCase();
        final mime = ext == 'png' ? 'image/png' : ext == 'webp' ? 'image/webp' : 'image/jpeg';
        request.files.add(http.MultipartFile.fromBytes(
          'image',
          imageBytes,
          filename: fileName,
          contentType: MediaType.parse(mime),
        ));
      }

      debugPrint('[ApiService] POST multipart $uri fields=$fields hasImage=${imageBytes != null}');
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      debugPrint('[ApiService] POST multipart ${response.statusCode} ${response.body}');
      final respBody = json.decode(response.body);
      if ((response.statusCode == 200 || response.statusCode == 201) && respBody['success'] == true) {
        return respBody['data'] ?? respBody;
      }
      return null;
    } catch (e) {
      debugPrint('[ApiService] POST multipart ERROR: $e');
      return null;
    }
  }

  static Future<dynamic> delete(String path) async {
    try {
      final headers = await _headers();
      final url = '$_baseUrl$path';
      debugPrint('[ApiService] DELETE $url');
      final response = await http.delete(Uri.parse(url), headers: headers);
      debugPrint('[ApiService] DELETE ${response.statusCode} ${response.body}');
      final respBody = json.decode(response.body);
      if ((response.statusCode == 200 || response.statusCode == 201) && respBody['success'] == true) {
        return respBody['data'] ?? respBody;
      }
      return null;
    } catch (e) {
      debugPrint('[ApiService] DELETE ERROR: $e');
      return null;
    }
  }
}
