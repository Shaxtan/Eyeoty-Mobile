import 'package:flutter/foundation.dart';
import '../core/utils/load_status.dart';
import '../models/dashboard_summary_model.dart';
import '../models/device_item.dart';
import '../models/unreachable_device.dart';
import '../models/top_distance_item.dart';
import '../models/utilization_result.dart';
import '../models/db_alert.dart';
import '../repositories/dashboard_repository.dart';

/// Mirrors useDashboard.js's several independent useQuery hooks — each
/// section has its own LoadStatus, exactly like each hook has its own
/// isLoading/error, rather than one big all-or-nothing loading flag.
class DashboardProvider extends ChangeNotifier {
  final DashboardRepository _repo;
  DashboardProvider(this._repo);

  // Summary + VTS devices (single dashboard-data call)
  LoadStatus summaryStatus = LoadStatus.idle;
  DashboardSummary? summary;
  List<DeviceItem> vtsDevices = [];
  String? summaryError;

  // Unreachable devices
  LoadStatus unreachableStatus = LoadStatus.idle;
  List<UnreachableDevice> unreachableDevices = [];
  String? unreachableError;

  // Mini live map data
  LoadStatus mapStatus = LoadStatus.idle;
  List<DeviceItem> mapDevices = [];
  String? mapError;

  // Top by distance
  LoadStatus topDistanceStatus = LoadStatus.idle;
  List<TopDistanceItem> topDistance = [];
  String? topDistanceError;

  // Fleet utilization (7-day trend)
  LoadStatus utilizationStatus = LoadStatus.idle;
  UtilizationResult? utilization;
  String? utilizationError;

  // Recent / dashboard alerts (db-alerts feed)
  LoadStatus dbAlertsStatus = LoadStatus.idle;
  DbAlertsResult? dbAlerts;
  String? dbAlertsError;

  /// Kicks off every section's fetch independently — matches the web
  /// app's several parallel useQuery hooks rather than one sequential
  /// waterfall.
  void loadAll(String accountId) {
    _loadSummary(accountId);
    _loadUnreachable(accountId);
    _loadMap(accountId);
    _loadTopDistance(accountId);
    _loadUtilization(accountId);
    _loadDbAlerts(accountId);
  }

  Future<void> _loadSummary(String accountId) async {
    summaryStatus = LoadStatus.loading;
    notifyListeners();
    try {
      summary = await _repo.getSummary(accountId: accountId);
      vtsDevices = await _repo.getVtsDevices(accountId: accountId);
      summaryStatus = LoadStatus.loaded;
    } catch (e) {
      summaryError = e.toString();
      summaryStatus = LoadStatus.error;
    }
    notifyListeners();
  }

  Future<void> _loadUnreachable(String accountId) async {
    unreachableStatus = LoadStatus.loading;
    notifyListeners();
    try {
      unreachableDevices = await _repo.getUnreachableDevices(accountId: accountId);
      unreachableStatus = LoadStatus.loaded;
    } catch (e) {
      unreachableError = e.toString();
      unreachableStatus = LoadStatus.error;
    }
    notifyListeners();
  }

  Future<void> _loadMap(String accountId) async {
    mapStatus = LoadStatus.loading;
    notifyListeners();
    try {
      mapDevices = await _repo.getMapViewData(accountId: accountId);
      mapStatus = LoadStatus.loaded;
    } catch (e) {
      mapError = e.toString();
      mapStatus = LoadStatus.error;
    }
    notifyListeners();
  }

  Future<void> _loadTopDistance(String accountId) async {
    topDistanceStatus = LoadStatus.loading;
    notifyListeners();
    try {
      topDistance = await _repo.getTopDistanceDevices(accountId: accountId);
      topDistanceStatus = LoadStatus.loaded;
    } catch (e) {
      topDistanceError = e.toString();
      topDistanceStatus = LoadStatus.error;
    }
    notifyListeners();
  }

  Future<void> _loadUtilization(String accountId) async {
    utilizationStatus = LoadStatus.loading;
    notifyListeners();
    try {
      utilization = await _repo.getUtilization(accountId: accountId);
      utilizationStatus = LoadStatus.loaded;
    } catch (e) {
      utilizationError = e.toString();
      utilizationStatus = LoadStatus.error;
    }
    notifyListeners();
  }

  Future<void> _loadDbAlerts(String accountId) async {
    dbAlertsStatus = LoadStatus.loading;
    notifyListeners();
    try {
      dbAlerts = await _repo.getDbAlerts(accountId: accountId);
      dbAlertsStatus = LoadStatus.loaded;
    } catch (e) {
      dbAlertsError = e.toString();
      dbAlertsStatus = LoadStatus.error;
    }
    notifyListeners();
  }
}
