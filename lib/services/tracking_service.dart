import '../models/vehicle_model.dart';
import 'api_client.dart';

/// CONFIRMED:
///   Map view : POST {BASE}/usage/reports/report/mapview?accid=<id>  body:{accid}
///   Live track: POST {BASE}/usage/reports/livetrack?accountId=<id>&imei=<imei>  body:{}
class TrackingService {
  final ApiClient _client;
  TrackingService(this._client);

  static const _mapViewPath = '/usage/reports/report/mapview';
  static const _liveTrackPath = '/usage/reports/livetrack';

  Future<List<LiveVehicle>> getMapViewData({required String accountId}) async {
    final json = await _client.post(
      _mapViewPath,
      body: {'accid': accountId},
      query: {'accid': accountId},
    );
    final map = json as Map<String, dynamic>;
    final list = (map['data'] as List<dynamic>?) ?? [];
    return list.map((e) => LiveVehicle.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Map<String, dynamic>?> getLiveTrack({
    required String accountId,
    required String imei,
  }) async {
    final json = await _client.post(
      _liveTrackPath,
      body: {},
      query: {'accountId': accountId, 'imei': imei},
    );
    final map = json as Map<String, dynamic>;
    if (map['resultCode'] == 1) {
      return map['data'] as Map<String, dynamic>?;
    }
    return null;
  }
}