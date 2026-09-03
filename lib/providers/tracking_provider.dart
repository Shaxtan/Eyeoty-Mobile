import 'package:flutter/foundation.dart';
import '../core/utils/load_status.dart';
import '../models/device_item.dart';
import '../repositories/tracking_repository.dart';
import '../repositories/dashboard_repository.dart';

/// Fleet list is now sourced from DashboardRepository.getMapViewData()
/// - the SAME /usage/reports/report/mapview endpoint Map View already
/// uses correctly via DeviceItem - rather than TrackingRepository's own
/// separate LiveVehicle-based implementation, which read a `status`
/// field that doesn't exist in the raw payload and silently defaulted
/// every vehicle to "No Data" regardless of actual speed/ignition.
/// TrackingRepository is kept only for getLiveTrack() (the detail
/// sheet's 30s polling), which this change doesn't touch.
class TrackingProvider extends ChangeNotifier {
  final TrackingRepository _trackingRepo;
  final DashboardRepository _dashboardRepo;
  TrackingProvider(this._trackingRepo, this._dashboardRepo);

  LoadStatus status = LoadStatus.idle;
  List<DeviceItem> vehicles = [];
  DeviceItem? selected;
  String? errorMessage;

  Future<void> load(String accountId) async {
    status = LoadStatus.loading;
    notifyListeners();
    try {
      vehicles = await _dashboardRepo.getMapViewData(accountId: accountId);
      status = LoadStatus.loaded;
    } catch (e) {
      errorMessage = e.toString();
      status = LoadStatus.error;
    }
    notifyListeners();
  }

  void select(DeviceItem v) {
    selected = v;
    notifyListeners();
  }

  void clearSelection() {
    selected = null;
    notifyListeners();
  }

  /// One-off live-track lookup for a single vehicle — used by
  /// VehicleDetailSheet's 30s polling, distinct from `load()` which
  /// fetches the whole fleet's map-view snapshot.
  Future<Map<String, dynamic>?> fetchLiveTrackFor({
    required String accountId,
    required String imei,
  }) {
    return _trackingRepo.getLiveTrack(accountId: accountId, imei: imei);
  }
}