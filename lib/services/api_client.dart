import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/env.dart';
import 'auth_service.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  ApiException(this.message, {this.statusCode});
  @override
  String toString() => message;
}

/// Thin wrapper around package:http that mirrors the existing web app's
/// apiClient (Authorization: Bearer <token> on every request, JSON in/out).
class ApiClient {
  final AuthService _authService;
  ApiClient(this._authService);

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    final base = Uri.parse(Env.apiBaseUrl);
    return base.replace(
      path: '${base.path}$path',
      queryParameters: query?.map((k, v) => MapEntry(k, '$v')),
    );
  }

  Future<Map<String, String>> _headers() async {
    final token = await _authService.readToken();
    return {
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    final res = await http.get(_uri(path, query), headers: await _headers());
    return _handle(res);
  }

  Future<dynamic> post(
    String path, {
    Map<String, dynamic>? body,
    Map<String, dynamic>? query,
  }) async {
    final res = await http.post(
      _uri(path, query),
      headers: await _headers(),
      body: jsonEncode(body ?? {}),
    );
    return _handle(res);
  }

  dynamic _handle(http.Response res) {
    if (res.statusCode == 401) {
      throw ApiException('Session expired. Please log in again.', statusCode: 401);
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw ApiException('Request failed (${res.statusCode}).', statusCode: res.statusCode);
    }
    if (res.body.isEmpty) return null;
    try {
      return jsonDecode(res.body);
    } catch (_) {
      throw ApiException('Received an invalid response from the server.');
    }
  }
}
