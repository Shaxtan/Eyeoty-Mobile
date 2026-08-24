import '../models/account_model.dart';
import '../models/account_status.dart';
import 'api_client.dart';

/// Mirrors apiService.getAccountDropdown() / getAccountStatus().
class AccountsService {
  final ApiClient _client;
  AccountsService(this._client);

  static const _dropdownPath = '/accounts/accountDropdown';
  static const _statusPath = '/accounts/account-status';

  /// GET /accounts/accountDropdown. Response is DOUBLE-nested
  /// (data.data) - confirmed directly from useAccountStore.js's own
  /// `res?.data?.data` unwrap. Corrected here from an earlier,
  /// single-level assumption. No client-side status filter either,
  /// matching the real store exactly - it maps every account the
  /// endpoint returns, without filtering by status.
  Future<List<Account>> getAccountDropdown() async {
    final json = await _client.get(_dropdownPath);
    final body = json as Map<String, dynamic>;
    final outer = body['data'];
    List<dynamic> list;
    if (outer is Map<String, dynamic>) {
      list = (outer['data'] as List<dynamic>?) ?? [];
    } else if (outer is List) {
      list = outer;
    } else {
      list = [];
    }
    return list.map((e) => Account.fromJson(e as Map<String, dynamic>)).toList();
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