import 'package:flutter/foundation.dart';
import '../models/account_model.dart';
import '../models/account_status.dart';
import '../repositories/accounts_repository.dart';

/// Caches the account dropdown once (mirrors useAccountStore's already-
/// loaded `accounts` list, which FleetTableCard.jsx reads synchronously
/// without refetching), and fetches account status on demand — fresh
/// every time, matching the web app's popup behaviour.
class AccountsProvider extends ChangeNotifier {
  final AccountsRepository _repo;
  AccountsProvider(this._repo);

  List<Account> accounts = [];
  bool _loadedOnce = false;

  Future<void> ensureLoaded() async {
    if (_loadedOnce) return;
    try {
      accounts = await _repo.getAccountDropdown();
      _loadedOnce = true;
      notifyListeners();
    } catch (_) {
      // Silent — account-name resolution is a nice-to-have, not critical
      // path; a failed dropdown just means the status dialog will show
      // "not found" for a given name instead of the app breaking.
    }
  }

  String? resolveIdByName(String name) {
    for (final a in accounts) {
      if (a.label.toLowerCase() == name.toLowerCase()) return a.id;
    }
    return null;
  }

  Future<AccountStatus> fetchStatus(String accountId) => _repo.getAccountStatus(accountId);
}
