import 'api_client.dart';
import '../models/load_cell_reading.dart';

/// Endpoints confirmed from loadcell.service.js + apiService.js:
///   Historical : POST {BASE}/usage/reports/load-graph
///                body {imei, startDate, endDate} - dates formatted
///                "yyyy-MM-dd HH:mm:ss" (toLocalStr in the original),
///                a different format from every other report in this app.
///   Live       : POST {BASE}/usage/reports/live-load-graph
///                query param IMEI (capitalized - case-sensitive, not "imei")
///
/// getImeis() from the original is NOT ported here - it's just a thin
/// wrapper around apiService.getImeiDropdown(), already available as
/// ReportsRepository.getImeiDropdown() / ImeiOption.
class LoadCellService {
  final ApiClient _client;
  LoadCellService(this._client);

  static const _historyPath = '/usage/reports/load-graph';
  static const _livePath = '/usage/reports/live-load-graph';

  String _toLocalStr(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}:${two(d.second)}';
  }

  Future<List<LoadCellReading>> getHistoricalData({
    required String imei,
    required DateTime from,
    required DateTime to,
  }) async {
    final json = await _client.post(_historyPath, body: {
      'imei': imei,
      'startDate': _toLocalStr(from),
      'endDate': _toLocalStr(to),
    });
    final body = json as Map<String, dynamic>;
    if (body['resultCode'] != 1) return [];
    final list = body['data'] as List<dynamic>?;
    if (list == null) return [];
    return list.map((e) => LoadCellReading.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<LoadCellReading>> getLiveData(String imei) async {
    final json = await _client.post(_livePath, body: {}, query: {'IMEI': imei});
    final body = json as Map<String, dynamic>;
    if (body['resultCode'] != 1) return [];
    final list = body['data'] as List<dynamic>?;
    if (list == null) return [];
    return list.map((e) => LoadCellReading.fromJson(e as Map<String, dynamic>)).toList();
  }
}