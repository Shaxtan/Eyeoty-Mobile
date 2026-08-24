import 'package:flutter/foundation.dart';
import '../models/account_model.dart';
import '../repositories/accounts_repository.dart';
import 'auth_provider.dart';

/// Ported from useAccountStore.js. The app-wide "currently selected
/// account" - distinct from AccountsProvider, which caches the same
/// dropdown for a different purpose (resolving an account NAME back to
/// an ID for Fleet Devices' status popup).
///
/// Every screen that currently defaults to
/// `AuthProvider.user?.accountId` (Dashboard, Fleet Intelligence, Map
/// View, Tracking, Fleet Devices, and all 5 Reports) is NOT yet wired
/// to react to this provider - that's a deliberate separate follow-up
/// pass, not done here. This turn is the foundation: the selector UI
/// and the global state it reads from.
class SelectedAccountProvider extends ChangeNotifier {
  final AccountsRepository _repo;
  final AuthProvider _authProvider;
  SelectedAccountProvider(this._repo, this._authProvider);

  List<Account> accounts = [];
  Account? selectedAccount;
  bool loading = false;
  bool _loaded = false;

  /// Fetch-once, matching the JS store's `if (loading || loaded) return;`
  /// guard. Selects the LOGGED-IN user's own account by ID (not
  /// accounts[0]) - same reasoning as the original: prevents the
  /// dropdown snapping to whichever account happens to be first.
  Future<void> loadAccounts() async {
    if (loading || _loaded) return;
    loading = true;
    notifyListeners();
    try {
      final list = await _repo.getAccountDropdown();
      accounts = list;

      final myId = _authProvider.user?.accountId;
      Account? mine;
      if (myId != null) {
        for (final a in list) {
          if (a.id == myId) {
            mine = a;
            break;
          }
        }
      }
      selectedAccount = mine ?? (list.isNotEmpty ? list.first : null);
      _loaded = true;
    } catch (e) {
      // Matches the JS store: still mark loaded on failure so it
      // doesn't retry endlessly; the selector just won't have options.
      debugPrint('SelectedAccountProvider.loadAccounts failed: $e');
      _loaded = true;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  void setAccount(String id) {
    for (final a in accounts) {
      if (a.id == id) {
        selectedAccount = a;
        notifyListeners();
        return;
      }
    }
  }

  /// Clears everything - call on logout so a different account logging
  /// in next doesn't briefly show the previous one, matching the JS
  /// store's own reset() + its call site in the logout flow.
  void reset() {
    accounts = [];
    selectedAccount = null;
    loading = false;
    _loaded = false;
    notifyListeners();
  }
}