import '../../models/fleet_scan_result.dart';
import 'agent_helpers.dart';

const _agent = 'device-health';

const _lowBatteryV = 3.6;
const _critBatteryV = 3.4;
const _minSatellites = 4;
const _staleMinutes = 30;
const _offlineMinutes = 120;

class DeviceHealthResult {
  final List<FleetFinding> findings;
  final List<DeviceHealthRecord> devices;
  final HealthStats stats;
  DeviceHealthResult({required this.findings, required this.devices, required this.stats});
}

/// Ported 1:1 from deviceHealth.agent.js (Agent #8).
DeviceHealthResult runDeviceHealthAgent(List<Map<String, dynamic>> records, {int? now}) {
  final nowMs = now ?? DateTime.now().millisecondsSinceEpoch;
  final findings = <FleetFinding>[];
  final devices = <DeviceHealthRecord>[];
  var healthy = 0, degraded = 0, critical = 0;

  for (final r in records) {
    final imei = r['imei']?.toString();
    final vehnum = (r['vehicleNumber'] ?? r['vehnum'] ?? r['name'])?.toString();
    final accId = (r['accId'] ?? r['accid'])?.toString();

    final issues = <DeviceHealthIssue>[];
    var score = 100;

    // Battery
    final battery = numOfOrNull(r['battery'] ?? r['batAmp']);
    if (battery != null && battery > 0) {
      if (battery < _critBatteryV) {
        issues.add(DeviceHealthIssue(key: 'battery', severity: Severity.critical, message: 'Battery critically low ($battery V)'));
        score -= 40;
      } else if (battery < _lowBatteryV) {
        issues.add(DeviceHealthIssue(key: 'battery', severity: Severity.warning, message: 'Battery low ($battery V)'));
        score -= 20;
      }
    }

    // GPS fix quality
    final gps = (r['gps'] ?? '').toString().toUpperCase();
    if (gps.isNotEmpty && gps != 'A') {
      issues.add(DeviceHealthIssue(key: 'gps', severity: Severity.warning, message: 'No GPS fix (gps="$gps")'));
      score -= 25;
    }

    // Satellite count
    final sats = numOfOrNull(r['satellite']);
    if (sats != null && sats < _minSatellites) {
      issues.add(DeviceHealthIssue(key: 'satellite', severity: Severity.warning, message: 'Weak satellite lock ($sats sats)'));
      score -= 15;
    }

    // Freshness / staleness
    final epoch = parseTs(r['deviceTime'] ?? r['devTs'] ?? r['createdOn']);
    if (epoch != null) {
      if (epoch > nowMs + 86400000) {
        // Future-dated (the 2041 bug) — can't trust freshness at all
        issues.add(DeviceHealthIssue(key: 'stale', severity: Severity.critical, message: 'Device clock is corrupt (future-dated)'));
        score -= 35;
      } else {
        final ageMin = (nowMs - epoch) / 60000;
        if (ageMin > _offlineMinutes) {
          issues.add(DeviceHealthIssue(
              key: 'stale', severity: Severity.critical, message: 'No data for ${ageMin.round()} min (possible offline)'));
          score -= 35;
        } else if (ageMin > _staleMinutes) {
          issues.add(DeviceHealthIssue(key: 'stale', severity: Severity.warning, message: 'Stale data (${ageMin.round()} min old)'));
          score -= 15;
        }
      }
    }

    score = score < 0 ? 0 : score;
    final status = score >= 80 ? 'healthy' : (score >= 50 ? 'degraded' : 'critical');
    if (status == 'healthy') {
      healthy++;
    } else if (status == 'degraded') {
      degraded++;
    } else {
      critical++;
    }

    devices.add(DeviceHealthRecord(
      imei: imei,
      vehnum: vehnum,
      accId: accId,
      score: score,
      status: status,
      battery: battery,
      gps: gps,
      satellites: sats,
      issues: issues,
    ));

    for (final iss in issues) {
      findings.add(FleetFinding.make(
        agent: _agent,
        severity: iss.severity,
        code: 'HEALTH_${iss.key.toUpperCase()}',
        title: 'Device health issue',
        detail: iss.message,
        imei: imei,
        vehnum: vehnum,
        accId: accId,
        value: '$score',
        expected: '\u2265 80 health score',
      ));
    }
  }

  return DeviceHealthResult(
    findings: findings,
    devices: devices,
    stats: HealthStats(total: records.length, healthy: healthy, degraded: degraded, critical: critical),
  );
}