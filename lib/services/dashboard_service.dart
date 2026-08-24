import '../models/dashboard_summary_model.dart';
import '../models/device_item.dart';
import '../models/unreachable_device.dart';
import '../models/top_distance_item.dart';
import '../models/utilization_result.dart';
import '../models/db_alert.dart';
import 'api_client.dart';

/// Bundle returned by getDashboardData — mirrors dashboard.service.js's
/// { summary, VTS, ELK, raw } shape, but only exposes what DashboardPage.jsx
/// actually reads: summary + VTS.available (ELK is NOT used on the
/// dashboard page in the web app — only VTS feeds FleetTableCard there).
class DashboardData {
  final DashboardSummary summary;
  final List<DeviceItem> vtsDevices;
  DashboardData({required this.summary, required this.vtsDevices});
}

const _dayLabels = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

class DashboardService {
  final ApiClient _client;
  DashboardService(this._client);

  // CONFIRMED real paths from dashboard.service.js / apiService.js:
  static const _dashboardPath = '/usage/reports/report/dashboard';
  static const _unreachablePath = '/usage/reports/report/unrechableDevices';
  static const _mapViewPath = '/usage/reports/report/mapview';
  static const _topDistancePath = '/usage/reports/top-distance-devices';
  static const _accountSummaryPath = '/usage/reports/account-summary-report';
  static const _dbAlertsPath = '/usage/alerts/db-alerts';

  /// POST /usage/reports/report/dashboard?accid=<id>
  /// Response envelope may be double-nested (data.data) or single —
  /// both are checked, mirroring dashboard.service.js's own fallback.
  Future<DashboardData> getDashboardData({required String accountId}) async {
    final json = await _client.post(
      _dashboardPath,
      body: {'accid': accountId},
      query: {'accid': accountId},
    );
    final body = json as Map<String, dynamic>;
    final data = body['data'] as Map<String, dynamic>? ?? {};
    final inner = (data['data'] as Map<String, dynamic>?) ?? data;

    final summary = DashboardSummary.fromEnvelope(body);

    final vts = (inner['VTS'] as Map<String, dynamic>?)?['available'] as List<dynamic>? ?? [];
    final vtsDevices = vts.map((e) => DeviceItem.fromJson(e as Map<String, dynamic>)).toList();

    return DashboardData(summary: summary, vtsDevices: vtsDevices);
  }

  /// POST /usage/reports/report/unrechableDevices?accid=<id>
  Future<List<UnreachableDevice>> getUnreachableDevices({required String accountId}) async {
    final json = await _client.post(
      _unreachablePath,
      body: {'accid': accountId},
      query: {'accid': accountId},
    );
    final body = json as Map<String, dynamic>;
    final list = (body['data'] as List<dynamic>?) ?? [];
    return list.map((e) => UnreachableDevice.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// POST /usage/reports/report/mapview?accid=<id> — reused by the
  /// dashboard's mini live map (same source as the full Map View screen).
  Future<List<DeviceItem>> getMapViewData({required String accountId}) async {
    final json = await _client.post(
      _mapViewPath,
      body: {'accid': accountId},
      query: {'accid': accountId},
    );
    final body = json as Map<String, dynamic>;
    final list = (body['data'] as List<dynamic>?) ?? [];
    return list.map((e) => DeviceItem.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// POST /usage/reports/top-distance-devices?accid=<id>&limit=<n>
  Future<List<TopDistanceItem>> getTopDistanceDevices({
    required String accountId,
    int limit = 10,
  }) async {
    final json = await _client.post(
      '$_topDistancePath?accid=$accountId&limit=$limit',
      body: {},
    );
    final body = json as Map<String, dynamic>;
    if (body['resultCode'] != 1) return [];

    final list = (body['data'] as List<dynamic>?) ?? [];
    final items = list
        .map((e) => TopDistanceItem.fromJson(e as Map<String, dynamic>))
        .where((d) => d.valueKm > 0)
        .toList();
    items.sort((a, b) => b.valueKm.compareTo(a.valueKm));
    return items.take(limit).toList();
  }

  /// Derived (not a direct endpoint) — mirrors useFleetUtilization() in
  /// useDashboard.js exactly: 7 sequential-ish calls to
  /// /usage/reports/account-summary-report (one per day), each returning
  /// an account tree; % of LEAF accounts with totalDistance > 0 = that
  /// day's utilization.
  Future<UtilizationResult> getUtilization({required String accountId}) async {
    final today = DateTime.now();
    final days = List.generate(7, (i) => today.subtract(Duration(days: 6 - i)));

    final results = await Future.wait(days.map((d) async {
      final apiDate = _toApiDate(d);
      try {
        final json = await _client.post(
          '$_accountSummaryPath?accid=$accountId',
          body: {'startDate': apiDate, 'endDate': apiDate},
        );
        final body = json as Map<String, dynamic>;
        if (body['resultCode'] != 1) return _DayResult(d, 0);

        final dataList = body['data'] as List<dynamic>?;
        final root = (dataList != null && dataList.isNotEmpty)
            ? dataList.first as Map<String, dynamic>
            : null;
        final leaves = _collectLeafAccounts(root);
        final total = leaves.length;
        final active = leaves.where((a) {
          final v = a['totalDistance'];
          final num n = v is num ? v : num.tryParse('$v') ?? 0;
          return n > 0;
        }).length;
        final pct = total > 0 ? ((active / total) * 100).round() : 0;
        return _DayResult(d, pct);
      } catch (_) {
        return _DayResult(d, 0);
      }
    }));

    final points = results
        .map((r) => UtilizationPoint(dayLabel: _dayLabels[r.day.weekday % 7], utilization: r.pct))
        .toList();

    if (points.isEmpty) return UtilizationResult.empty();

    final avg = (points.map((p) => p.utilization).reduce((a, b) => a + b) / points.length).round();

    final half = (points.length ~/ 2).clamp(1, points.length);
    final earlyAvg =
        points.take(half).map((p) => p.utilization).reduce((a, b) => a + b) / half;
    final latest = points.last.utilization;
    final trend = earlyAvg > 0 ? (((latest - earlyAvg) / earlyAvg) * 100).round() : 0;

    return UtilizationResult(points: points, avg: avg, trend: trend);
  }

  /// POST /usage/alerts/db-alerts?accid=<id>
  /// Different endpoint from AlertsService.getAlerts() — feeds the
  /// dashboard's Recent Alerts widget, not the full Alert Dashboard screen.
  Future<DbAlertsResult> getDbAlerts({required String accountId}) async {
    final json = await _client.post(
      _dbAlertsPath,
      body: {},
      query: {'accid': accountId},
    );
    final body = json as Map<String, dynamic>;
    if (body['resultCode'] != 1) return DbAlertsResult.empty();

    final data = body['data'] as Map<String, dynamic>? ?? {};
    final summaryList = (data['summary'] as List<dynamic>?) ?? [];
    final dataList = (data['data'] as List<dynamic>?) ?? [];

    return DbAlertsResult(
      summary: summaryList.map((e) => AlertTypeCount.fromJson(e as Map<String, dynamic>)).toList(),
      alerts: dataList.map((e) => DbAlert.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }

  // ── helpers ──────────────────────────────────────────────────────────────

  /// yyyy-mm-dd -> d/MM/yyyy, matching useDashboard.js's toApiDate() exactly
  /// (day is NOT zero-padded, month/year are).
  String _toApiDate(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.day}/${two(d.month)}/${d.year}';
  }

  List<Map<String, dynamic>> _collectLeafAccounts(Map<String, dynamic>? node) {
    if (node == null) return [];
    final children = (node['childAccounts'] as List<dynamic>?) ?? [];
    if (children.isEmpty) return [node];
    return children
        .expand((c) => _collectLeafAccounts(c as Map<String, dynamic>?))
        .toList();
  }
}

class _DayResult {
  final DateTime day;
  final int pct;
  _DayResult(this.day, this.pct);
}
