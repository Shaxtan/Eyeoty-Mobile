import 'api_client.dart';
import '../models/fleet_scan_result.dart';
import '../core/fleet_intelligence/run_fleet_scan.dart';

/// Fetches the SAME raw snapshot the web app's useFleetSnapshot() does,
/// then runs the SAME batch-agent scan (ported 1:1 from
/// modules/agents/core/) locally — confirmed against the real
/// useFleetScan.js plus dataQuality.agent.js, deviceHealth.agent.js,
/// alertPriority.agent.js, helpers.js, and index.js:
///   devices : apiService.getAllDevices(accid) -> POST
///             /usage/reports/report/dashboard?accid=<id>, combining
///             VTS.available + ELK.available, RAW (unparsed) device JSON.
///   alerts  : apiService.getDbAlerts(accid) -> POST
///             /usage/alerts/db-alerts?accid=<id>
/// The scan itself (runFleetScan) now runs for real — no more stub.
class FleetIntelligenceService {
  final ApiClient _client;
  FleetIntelligenceService(this._client);

  static const _dashboardPath = '/usage/reports/report/dashboard';
  static const _dbAlertsPath = '/usage/alerts/db-alerts';

  Future<FleetScanResult> runScan({required String accountId}) async {
    // 1. Devices — combined VTS + ELK, RAW — matches
    //    apiService.getAllDevices()'s exact extraction path.
    final devicesJson = await _client.post(
      _dashboardPath,
      body: {'accid': accountId},
      query: {'accid': accountId},
    );
    final devicesBody = devicesJson as Map<String, dynamic>;
    final devicesData = devicesBody['data'] as Map<String, dynamic>? ?? {};
    final devicesInner = (devicesData['data'] as Map<String, dynamic>?) ?? devicesData;
    final vts = (devicesInner['VTS'] as Map<String, dynamic>?)?['available'] as List<dynamic>? ?? [];
    final elk = (devicesInner['ELK'] as Map<String, dynamic>?)?['available'] as List<dynamic>? ?? [];
    final rawDevices = [...vts, ...elk].cast<Map<String, dynamic>>();

    // 2. Alerts — same endpoint/shape as DashboardService.getDbAlerts().
    final alertsJson = await _client.post(
      _dbAlertsPath,
      body: {},
      query: {'accid': accountId},
    );
    final alertsBody = alertsJson as Map<String, dynamic>;
    var rawAlerts = <Map<String, dynamic>>[];
    if (alertsBody['resultCode'] == 1) {
      final data = alertsBody['data'] as Map<String, dynamic>? ?? {};
      rawAlerts = ((data['data'] as List<dynamic>?) ?? []).cast<Map<String, dynamic>>();
    }

    // 3. Run the real scan — ported 1:1 from index.js's runFleetScan().
    return runFleetScan(devices: rawDevices, alertsData: rawAlerts);
  }
}