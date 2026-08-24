import '../models/alert_model.dart';
import '../services/alerts_service.dart';

class AlertsRepository {
  final AlertsService _service;
  AlertsRepository(this._service);

  Future<List<FleetAlert>> getAlerts({
    required String accountId,
    required DateTime start,
    required DateTime end,
  }) =>
      _service.getAlerts(accountId: accountId, startTime: start, endTime: end);
}
