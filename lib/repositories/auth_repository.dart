import '../services/auth_service.dart';

class AuthRepository {
  final AuthService _service;
  AuthRepository(this._service);

  Future<bool> hasSession() => _service.hasSession();
  Future<void> logout() => _service.logout();
  Future<AuthResult> login({required String identifier, required String password}) =>
      _service.login(identifier: identifier, password: password);
}
