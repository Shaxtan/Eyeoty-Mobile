import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../repositories/auth_repository.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthProvider extends ChangeNotifier {
  final AuthRepository _repo;
  AuthProvider(this._repo);

  AuthStatus status = AuthStatus.unknown;
  AppUser? user;
  String? errorMessage;
  bool isLoading = false;

  Future<void> bootstrap() async {
    final has = await _repo.hasSession();
    status = has ? AuthStatus.authenticated : AuthStatus.unauthenticated;
    notifyListeners();
  }

  Future<bool> login(String identifier, String password) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      final result = await _repo.login(identifier: identifier, password: password);
      user = result.user;
      status = AuthStatus.authenticated;
      return true;
    } catch (e) {
      errorMessage = e.toString().replaceFirst('Exception: ', '');
      status = AuthStatus.unauthenticated;
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await _repo.logout();
    user = null;
    status = AuthStatus.unauthenticated;
    notifyListeners();
  }
}
