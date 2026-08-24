import 'package:flutter/foundation.dart';
import '../core/utils/load_status.dart';
import '../models/alert_model.dart';
import '../repositories/alerts_repository.dart';

class AlertsProvider extends ChangeNotifier {
  final AlertsRepository _repo;
  AlertsProvider(this._repo);

  LoadStatus status = LoadStatus.idle;
  List<FleetAlert> alerts = [];
  String? errorMessage;

  Future<void> load({
    required String accountId,
    required DateTime start,
    required DateTime end,
  }) async {
    status = LoadStatus.loading;
    notifyListeners();
    try {
      alerts = await _repo.getAlerts(accountId: accountId, start: start, end: end);
      status = LoadStatus.loaded;
    } catch (e) {
      errorMessage = e.toString();
      status = LoadStatus.error;
    }
    notifyListeners();
  }
}
