import '../models/alert_model.dart';
import 'api_client.dart';

/// Mirrors apiService.getAlertsByAccount() from the existing web app —
/// this endpoint WAS confirmed during earlier work on this project:
/// POST /usage/alerts/by-account  { accid, startTime, endTime, pageSize }
class AlertsService {
  final ApiClient _client;
  AlertsService(this._client);

  Future<List<FleetAlert>> getAlerts({
    required String accountId,
    required DateTime startTime,
    required DateTime endTime,
  }) async {
    final json = await _client.post(
      '/usage/alerts/by-account',
      body: {
        'accid': accountId,
        'startTime': _fmt(startTime),
        'endTime': _fmt(endTime),
        'pageSize': 0,
      },
    );
    final map = json as Map<String, dynamic>;
    if (map['resultCode'] != 1) {
      throw Exception(map['message']?.toString() ?? 'Failed to fetch alerts.');
    }
    final list = (map['data'] as List<dynamic>? ?? []);
    return list
        .map((e) => FleetAlert.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  String _fmt(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)} '
        '${two(d.hour)}:${two(d.minute)}:${two(d.second)}';
  }
}
