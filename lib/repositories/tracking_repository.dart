import '../models/vehicle_model.dart';
import '../services/tracking_service.dart';

class TrackingRepository {
  final TrackingService _service;
  TrackingRepository(this._service);

  Future<List<LiveVehicle>> getMapViewData({required String accountId}) =>
      _service.getMapViewData(accountId: accountId);

  Future<Map<String, dynamic>?> getLiveTrack({
    required String accountId,
    required String imei,
  }) =>
      _service.getLiveTrack(accountId: accountId, imei: imei);
}
