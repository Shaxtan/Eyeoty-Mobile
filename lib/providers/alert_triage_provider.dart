import 'package:flutter/foundation.dart';

/// Ported from useAlertTriage.js's DOCUMENTED behavior (acknowledge /
/// resolve / reopen, scoped per account) - the hook's own source wasn't
/// shared, but its behavior is fully specified in AlertsPage.jsx's own
/// header comment: local-only state, since there's no backend
/// alert-workflow endpoint. Kept in-memory here (resets on app restart)
/// rather than guessing at the original's exact persistence mechanism
/// (localStorage vs sessionStorage vs plain React state) - the
/// confirmed, important part is that it's client-only and never synced
/// to the server, which this preserves exactly.
class AlertTriageProvider extends ChangeNotifier {
  final Map<String, String> _status = {}; // alertId -> 'acknowledged' | 'resolved'
  String? _accountId;

  /// Resets triage state on account switch, matching the original's
  /// per-account scoping (useAlertTriage(accountId)).
  void setAccount(String accountId) {
    if (_accountId == accountId) return;
    _accountId = accountId;
    _status.clear();
  }

  String getStatus(String alertId) => _status[alertId] ?? 'open';

  void acknowledge(String alertId) {
    _status[alertId] = 'acknowledged';
    notifyListeners();
  }

  void resolve(String alertId) {
    _status[alertId] = 'resolved';
    notifyListeners();
  }

  void reopen(String alertId) {
    _status.remove(alertId);
    notifyListeners();
  }
}