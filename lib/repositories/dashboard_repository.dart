import '../models/dashboard_summary_model.dart';
import '../models/device_item.dart';
import '../models/unreachable_device.dart';
import '../models/top_distance_item.dart';
import '../models/utilization_result.dart';
import '../models/db_alert.dart';
import '../services/dashboard_service.dart';

class DashboardRepository {
  final DashboardService _service;
  DashboardRepository(this._service);

  Future<DashboardSummary> getSummary({required String accountId}) async {
    final data = await _service.getDashboardData(accountId: accountId);
    return data.summary;
  }

  Future<List<DeviceItem>> getVtsDevices({required String accountId}) async {
    final data = await _service.getDashboardData(accountId: accountId);
    return data.vtsDevices;
  }

  Future<List<UnreachableDevice>> getUnreachableDevices({required String accountId}) =>
      _service.getUnreachableDevices(accountId: accountId);

  Future<List<DeviceItem>> getMapViewData({required String accountId}) =>
      _service.getMapViewData(accountId: accountId);

  Future<List<TopDistanceItem>> getTopDistanceDevices({required String accountId, int limit = 10}) =>
      _service.getTopDistanceDevices(accountId: accountId, limit: limit);

  Future<UtilizationResult> getUtilization({required String accountId}) =>
      _service.getUtilization(accountId: accountId);

  Future<DbAlertsResult> getDbAlerts({required String accountId}) =>
      _service.getDbAlerts(accountId: accountId);
}
