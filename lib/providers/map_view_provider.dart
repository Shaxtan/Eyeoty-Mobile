import 'package:flutter/foundation.dart';
import '../core/utils/load_status.dart';
import '../models/device_item.dart';
import '../repositories/dashboard_repository.dart';

/// Dedicated provider for the Map View screen - reuses
/// DashboardRepository.getMapViewData() (same POST
/// /usage/reports/report/mapview endpoint MapPage.jsx calls, already
/// wired for the Dashboard's mini live map and confirmed working), but
/// kept separate from DashboardProvider since this screen has its own
/// lifecycle: a 3-minute auto-refresh timer (matching MapPage.jsx's
/// REFRESH_MS), independent of the Dashboard's manual-refresh-only cadence.
class MapViewProvider extends ChangeNotifier {
  final DashboardRepository _repo;
  MapViewProvider(this._repo);

  LoadStatus status = LoadStatus.idle;
  List<DeviceItem> vehicles = [];
  String? errorMessage;

  /// Matches MapPage.jsx's fetchMapData(): sets loading=true on EVERY
  /// call, including periodic auto-refreshes, not just the first load -
  /// ported as-is for fidelity even though it means the loading overlay
  /// briefly reappears every 3 minutes.
  Future<void> load(String accountId) async {
    status = LoadStatus.loading;
    notifyListeners();
    try {
      vehicles = await _repo.getMapViewData(accountId: accountId);
      status = LoadStatus.loaded;
      errorMessage = null;
    } catch (e) {
      errorMessage = e.toString();
      status = LoadStatus.error;
    }
    notifyListeners();
  }
}