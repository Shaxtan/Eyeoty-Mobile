import 'dart:math' as math;

/// Data shapes produced by the LOCALLY-COMPUTED Fleet Intelligence scan —
/// ported 1:1 from the real agent files (dataQuality.agent.js,
/// deviceHealth.agent.js, alertPriority.agent.js, index.js's
/// runFleetScan). No longer API-response shapes (there's no scan
/// endpoint — this is client-side computation, same as the web app),
/// so these are plain constructors, not fromJson factories.

class FleetFinding {
  final String id;
  final String agent;
  final String severity; // 'critical' | 'warning' | 'info'
  final String code;
  final String title;
  final String detail;
  final String? imei;
  final String? vehnum;
  final String? accId;
  final String? value;
  final String? expected;
  final Map<String, dynamic>? raw;
  final int ts;

  FleetFinding._({
    required this.id,
    required this.agent,
    required this.severity,
    required this.code,
    required this.title,
    required this.detail,
    this.imei,
    this.vehnum,
    this.accId,
    this.value,
    this.expected,
    this.raw,
    required this.ts,
  });

  /// Ported from helpers.js's makeFinding() — same id-generation shape.
  factory FleetFinding.make({
    required String agent,
    required String severity,
    required String code,
    required String title,
    required String detail,
    String? imei,
    String? vehnum,
    String? accId,
    String? value,
    String? expected,
    Map<String, dynamic>? raw,
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final rand = math.Random();
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final suffix = List.generate(5, (_) => chars[rand.nextInt(chars.length)]).join();
    return FleetFinding._(
      id: '$agent:$code:${imei ?? 'fleet'}:${value ?? ''}:$now-$suffix',
      agent: agent,
      severity: severity,
      code: code,
      title: title,
      detail: detail,
      imei: imei,
      vehnum: vehnum,
      accId: accId,
      value: value,
      expected: expected,
      raw: raw,
      ts: now,
    );
  }
}

/// Ported from dataQuality.agent.js's stats object.
class QualityStats {
  final int total;
  final int corruptTimestamp;
  final int ignContradiction;
  final int missingFields;
  final int invalidCoords;
  final int duplicates;
  final int clean;
  final int score;

  QualityStats({
    required this.total,
    required this.corruptTimestamp,
    required this.ignContradiction,
    required this.missingFields,
    required this.invalidCoords,
    required this.duplicates,
    required this.clean,
    required this.score,
  });
}

/// Ported from deviceHealth.agent.js's per-issue shape.
class DeviceHealthIssue {
  final String key;
  final String severity;
  final String message;
  DeviceHealthIssue({required this.key, required this.severity, required this.message});
}

/// Ported from deviceHealth.agent.js's per-device `devices` entries.
class DeviceHealthRecord {
  final String? imei;
  final String? vehnum;
  final String? accId;
  final int score;
  final String status; // healthy | degraded | critical
  final num? battery;
  final String? gps;
  final num? satellites;
  final List<DeviceHealthIssue> issues;

  DeviceHealthRecord({
    this.imei,
    this.vehnum,
    this.accId,
    required this.score,
    required this.status,
    this.battery,
    this.gps,
    this.satellites,
    required this.issues,
  });
}

/// Ported from deviceHealth.agent.js's stats object.
class HealthStats {
  final int total;
  final int healthy;
  final int degraded;
  final int critical;
  HealthStats({required this.total, required this.healthy, required this.degraded, required this.critical});
}

/// Ported from alertPriority.agent.js's `ranked` entries.
class RankedAlert {
  final String id;
  final String type;
  final String? imei;
  final String? vehnum;
  final String? accId;
  final int count;
  final int score;
  final int? firstAt;
  final int? lastAt;
  final String? address;
  final num? speed;

  RankedAlert({
    required this.id,
    required this.type,
    this.imei,
    this.vehnum,
    this.accId,
    required this.count,
    required this.score,
    this.firstAt,
    this.lastAt,
    this.address,
    this.speed,
  });
}

/// Ported from alertPriority.agent.js's stats object.
class PriorityStats {
  final int rawAlerts;
  final int bursts;
  final int critical;
  final int high;
  final int collapsed;

  PriorityStats({
    required this.rawAlerts,
    required this.bursts,
    required this.critical,
    required this.high,
    required this.collapsed,
  });
}

/// Ported from index.js's runFleetScan() summary object.
class FleetScanSummary {
  final int totalFindings;
  final int critical;
  final int warning;
  final int info;
  final int dataQualityScore;
  final int devicesScanned;

  FleetScanSummary({
    required this.totalFindings,
    required this.critical,
    required this.warning,
    required this.info,
    required this.dataQualityScore,
    required this.devicesScanned,
  });
}

/// Ported from index.js's runFleetScan() return value.
class FleetScanResult {
  final List<FleetFinding> findings;
  final QualityStats qualityStats;
  final HealthStats healthStats;
  final List<DeviceHealthRecord> healthDevices;
  final PriorityStats priorityStats;
  final List<RankedAlert> priorityRanked;
  final FleetScanSummary summary;

  FleetScanResult({
    required this.findings,
    required this.qualityStats,
    required this.healthStats,
    required this.healthDevices,
    required this.priorityStats,
    required this.priorityRanked,
    required this.summary,
  });
}