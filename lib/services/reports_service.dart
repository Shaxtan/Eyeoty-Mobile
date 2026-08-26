import 'api_client.dart';
import '../models/imei_option.dart';
import '../models/track_point.dart';
import '../models/distance_report_result.dart';
import '../models/working_hour_record.dart';
import '../models/account_summary_node.dart';

class ReportsService {
  final ApiClient _client;
  ReportsService(this._client);

  static const _dropdownPath = '/usage/reports/report/dropdown';
  static const _distancePath = '/usage/reports/distance-report';
  static const _trackPlayPath = '/usage/reports/trackPlayHistory';
  static const _workingHourPath = '/usage/reports/workinghourreport';
  static const _accountSummaryPath = '/usage/reports/account-summary-report';

  Future<List<ImeiOption>> getImeiDropdown(String accountId) async {
    final json = await _client.get(_dropdownPath, query: {'accid': accountId});
    final body = json as Map<String, dynamic>;
    final data = body['data'] as Map<String, dynamic>? ?? {};
    final list = (data['imeiVehnumList'] as List<dynamic>?) ?? [];
    return list
        .map((e) => ImeiOption.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<DistanceReportResult> getDistanceReport({
    required String imei,
    required String startDate,
    required String endDate,
  }) async {
    final json = await _client.post(_distancePath, body: {
      'imei': imei,
      'startDate': startDate,
      'endDate': endDate,
    });
    final body = json as Map<String, dynamic>;
    if (body['resultCode'] != 1) {
      throw Exception(
          body['message']?.toString() ?? 'Failed to fetch distance report');
    }
    return DistanceReportResult.fromJson(body['data'] as Map<String, dynamic>);
  }

  Future<List<TrackPoint>> getTrackPlayHistory({
    required String imei,
    required String startTime,
    required String endTime,
  }) async {
    final json = await _client.post(_trackPlayPath, body: {
      'imei': imei,
      'startTime': startTime,
      'endTime': endTime,
    });
    final body = json as Map<String, dynamic>;
    final list = (body['data'] as List<dynamic>?) ?? [];
    return list
        .map((e) => TrackPoint.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<WorkingHourRecord>> getWorkingHourReport({
    required String imei,
    required String startDate,
    required String endDate,
  }) async {
    final json = await _client.post(_workingHourPath, body: {
      'imei': imei,
      'startDate': startDate,
      'endDate': endDate,
    });
    final body = json as Map<String, dynamic>;
    if (body['resultCode'] != 1) {
      throw Exception(
          body['message']?.toString() ?? 'Failed to fetch working hour report');
    }
    final payload = body['data'];
    List<dynamic> list;
    if (payload is List) {
      list = payload;
    } else if (payload is Map<String, dynamic>) {
      list = (payload['data'] as List<dynamic>?) ?? [];
    } else {
      list = [];
    }
    return list
        .map((e) => WorkingHourRecord.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<AccountSummaryNode?> getAccountSummary({
    required String accountId,
    required String startDate,
    required String endDate,
  }) async {
    // NOTE: accid must go through `query:`, not be embedded in the path
    // string. See DashboardService.getUtilization() for the full
    // explanation — Uri.replace(path: ...) percent-encodes '?' when
    // embedded in the path, breaking the request.
    final json = await _client.post(
      _accountSummaryPath,
      body: {'startDate': startDate, 'endDate': endDate},
      query: {'accid': accountId},
    );
    final body = json as Map<String, dynamic>;
    if (body['resultCode'] != 1) return null;
    final list = body['data'] as List<dynamic>?;
    if (list == null || list.isEmpty) return null;
    return AccountSummaryNode.fromJson(list.first as Map<String, dynamic>);
  }
}
