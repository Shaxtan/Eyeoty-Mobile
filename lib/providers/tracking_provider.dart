import 'package:flutter/foundation.dart';
import '../core/utils/load_status.dart';
import '../models/vehicle_model.dart';
import '../repositories/tracking_repository.dart';

class TrackingProvider extends ChangeNotifier {
  final TrackingRepository _repo;
  TrackingProvider(this._repo);

  LoadStatus status = LoadStatus.idle;
  List<LiveVehicle> vehicles = [];
  LiveVehicle? selected;
  String? errorMessage;

  Future<void> load(String accountId) async {
    status = LoadStatus.loading;
    notifyListeners();
    try {
      vehicles = await _repo.getMapViewData(accountId: accountId);
      status = LoadStatus.loaded;
    } catch (e) {
      errorMessage = e.toString();
      status = LoadStatus.error;
    }
    notifyListeners();
  }

  void select(LiveVehicle v) {
    selected = v;
    notifyListeners();
  }

  /// One-off live-track lookup for a single vehicle — used by
  /// VehicleDetailSheet's 30s polling, distinct from `load()` which
  /// fetches the whole fleet's map-view snapshot.
  Future<Map<String, dynamic>?> fetchLiveTrackFor({
    required String accountId,
    required String imei,
  }) {
    return _repo.getLiveTrack(accountId: accountId, imei: imei);
  }
}
