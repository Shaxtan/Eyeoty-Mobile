import '../../models/fleet_scan_result.dart';
import 'agent_helpers.dart';
import 'data_quality_agent.dart';
import 'device_health_agent.dart';
import 'alert_priority_agent.dart';

/// Ported 1:1 from index.js's runFleetScan({devices, alerts}) — runs the
/// three batch agents (data-quality #6, device-health #8, alert-priority
/// #18) over one fleet snapshot and returns a consolidated result. GPS
/// Jump (#7) is intentionally NOT included here, matching the original —
/// it needs a single vehicle's ordered track, not a bulk device list.
FleetScanResult runFleetScan({
  required List<Map<String, dynamic>> devices,
  required List<Map<String, dynamic>> alertsData,
}) {
  final quality = runDataQualityAgent(devices);
  final health = runDeviceHealthAgent(devices);
  final priority = runAlertPriorityAgent(alertsData);

  final findings = sortFindings([
    ...quality.findings,
    ...health.findings,
    ...priority.findings,
  ]);

  final critical = findings.where((f) => f.severity == Severity.critical).length;
  final warning = findings.where((f) => f.severity == Severity.warning).length;
  final info = findings.where((f) => f.severity == Severity.info).length;

  return FleetScanResult(
    findings: findings,
    qualityStats: quality.stats,
    healthStats: health.stats,
    healthDevices: health.devices,
    priorityStats: priority.stats,
    priorityRanked: priority.ranked,
    summary: FleetScanSummary(
      totalFindings: findings.length,
      critical: critical,
      warning: warning,
      info: info,
      dataQualityScore: quality.stats.score,
      devicesScanned: devices.length,
    ),
  );
}