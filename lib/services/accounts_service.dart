import '../models/account_model.dart';
import '../models/account_status.dart';
import 'api_client.dart';

/// Mirrors apiService.getAccountDropdown() / getAccountStatus() —
/// used to resolve an account NAME (shown in device tables) back to an
/// ID, then fetch that account's status. On mobile this backs a tap
/// dialog rather than the web app's hover popup (Desktop hover
/// interaction -> tap interaction, per conversion guidelines).
class AccountsService {
  final ApiClient _client;
  AccountsService(this._client);

  static const _dropdownPath = '/accounts/accountDropdown';
  static const _statusPath = '/accounts/account-status';

  /// GET /accounts/accountDropdown — only status === 'A' accounts.
  Future<List<Account>> getAccountDropdown() async {
    final json = await _client.get(_dropdownPath);
    final body = json as Map<String, dynamic>;
    if (body['resultCode'] != 1) {
      throw Exception(body['message']?.toString() ?? 'Failed to fetch account list');
    }
    final list = (body['data'] as List<dynamic>?) ?? [];
    return list
        .cast<Map<String, dynamic>>()
        .where((a) => a['status'] == 'A')
        .map((a) => Account.fromJson(a))
        .toList();
  }

  /// GET /accounts/account-status?accountId=<id>
  Future<AccountStatus> getAccountStatus(String accountId) async {
    final json = await _client.get(_statusPath, query: {'accountId': accountId});
    final body = json as Map<String, dynamic>;
    if (body['resultCode'] != 1) {
      throw Exception(body['message']?.toString() ?? 'Failed to fetch account status');
    }
    return AccountStatus.fromJson(body['data'] as Map<String, dynamic>);
  }
}
