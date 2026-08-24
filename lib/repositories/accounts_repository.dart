import '../models/account_model.dart';
import '../models/account_status.dart';
import '../services/accounts_service.dart';

class AccountsRepository {
  final AccountsService _service;
  AccountsRepository(this._service);

  Future<List<Account>> getAccountDropdown() => _service.getAccountDropdown();
  Future<AccountStatus> getAccountStatus(String accountId) => _service.getAccountStatus(accountId);
}
