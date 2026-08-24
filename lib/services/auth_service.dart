import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../config/env.dart';
import '../models/user_model.dart';

class AuthResult {
  final AppUser user;
  final String token;
  AuthResult(this.user, this.token);
}

class AuthException implements Exception {
  final String message;
  final int? code;
  AuthException(this.message, {this.code});
  @override
  String toString() => message;
}

/// CONFIRMED against the real auth.service.js / apiService.js:
///   POST {BASE}/users/users/signin
///   body: { username, password, signInHere: true }   (no auth header)
///   response: { resultCode, message, data: {
///       jwtToken | token, username, firstName, lastName, email,
///       roles: ["ROLE_XXX", ...], roleId, role, accountId | accid,
///       expiresIn
///   }}
///   resultCode 208 = "already signed in elsewhere" — surfaced as its own error.
class AuthService {
  static const _loginPath = '/users/users/signin';

  final _storage = const FlutterSecureStorage();

  Future<AuthResult> login({
    required String identifier,
    required String password,
  }) async {
    final res = await http.post(
      Uri.parse('${Env.apiBaseUrl}$_loginPath'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': identifier,
        'password': password,
        'signInHere': true,
      }),
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw AuthException('Login failed. Please check your credentials.');
    }

    final body = jsonDecode(res.body) as Map<String, dynamic>;

    if (body['resultCode'] == 208) {
      throw AuthException(
        body['message']?.toString() ?? 'Already signed in elsewhere.',
        code: 208,
      );
    }

    final tokenDetails = body['data'] as Map<String, dynamic>?;
    if (tokenDetails == null) {
      throw AuthException(
        body['message']?.toString() ?? 'Login failed. Please check your credentials.',
      );
    }

    final token = (tokenDetails['jwtToken'] ?? tokenDetails['token'] ?? '').toString();
    if (token.isEmpty) {
      throw AuthException('Login succeeded but no token was returned.');
    }
    await _storage.write(key: Env.authTokenStorageKey, value: token);

    final firstName = tokenDetails['firstName']?.toString() ?? '';
    final lastName = tokenDetails['lastName']?.toString() ?? '';
    final fullName = [firstName, lastName].where((s) => s.isNotEmpty).join(' ').trim();

    final username = tokenDetails['username']?.toString();
    final email = tokenDetails['email']?.toString();

    final displayName = fullName.isNotEmpty ? fullName : (username ?? email ?? identifier);

    String roleLabel = 'Member';
    final roles = tokenDetails['roles'];
    if (roles is List && roles.isNotEmpty) {
      roleLabel = roles.first.toString().replaceFirst(RegExp(r'^ROLE_'), '');
    } else if (tokenDetails['roleId'] != null) {
      roleLabel = tokenDetails['roleId'].toString();
    } else if (tokenDetails['role'] != null) {
      roleLabel = tokenDetails['role'].toString();
    }

    final accountId = (tokenDetails['accountId'] ?? tokenDetails['accid'] ?? 1).toString();

    final user = AppUser(
      id: username ?? identifier,
      name: displayName,
      email: email ?? identifier,
      role: roleLabel,
      accountId: accountId,
    );

    return AuthResult(user, token);
  }

  Future<void> logout() async {
    await _storage.delete(key: Env.authTokenStorageKey);
  }

  Future<String?> readToken() => _storage.read(key: Env.authTokenStorageKey);

  Future<bool> hasSession() async {
    final t = await readToken();
    return t != null && t.isNotEmpty;
  }
}