import 'dart:math' as math;
import '../../models/fleet_scan_result.dart';
import 'agent_helpers.dart';

const _agent = 'alert-priority';

const Map<String, int> _typeWeight = {
  'SOS': 100,
  'PANIC': 100,
  'ACC': 90,
  'CRASH': 90,
  'HBR': 60,
  'HAR': 55,
  'OVS': 50,
  'TOW': 45,
  'TAMPER': 70,
  'GEO': 40,
  'BAT': 30,
  'IGN': 20,
  'IDL': 15,
};
const _defaultWeight = 25;
const _burstWindowMin = 10;

class AlertPriorityResult {
  final List<RankedAlert> ranked;
  final List<FleetFinding> findings;
  final PriorityStats stats;
  AlertPriorityResult({required this.ranked, required this.findings, required this.stats});
}

class _TimedAlert {
  final Map<String, dynamic> raw;
  final int? epoch;
  _TimedAlert(this.raw, this.epoch);
}

/// Ported 1:1 from alertPriority.agent.js (Agent #18).
/// [alertsData] is the `data` array from the db-alerts response.
AlertPriorityResult runAlertPriorityAgent(List<Map<String, dynamic>> alertsData, {int? now}) {
  final nowMs = now ?? DateTime.now().millisecondsSinceEpoch;
  final findings = <FleetFinding>[];

  // Group into bursts: key = imei|type
  final groups = <String, List<_TimedAlert>>{};

  for (final a in alertsData) {
    final imei = a['imei']?.toString();
    final type = (a['type'] ?? 'UNK').toString().toUpperCase();
    final epoch = parseTs(a['createdOn'] ?? a['dateTime'] ?? a['deviceTime']);
    final key = '$imei|$type';
    groups.putIfAbsent(key, () => []).add(_TimedAlert(a, epoch));
  }

  final ranked = <RankedAlert>[];

  groups.forEach((key, items) {
    items.sort((x, y) => (x.epoch ?? 0).compareTo(y.epoch ?? 0));

    var burst = <_TimedAlert>[items[0]];

    void flush() {
      final first = burst.first;
      final last = burst.last;
      final type = (first.raw['type'] ?? 'UNK').toString().toUpperCase();
      final base = _typeWeight[type] ?? _defaultWeight;

      final double ageMin =
          last.epoch != null ? math.max(0.0, (nowMs - last.epoch!) / 60000) : 9999.0;
      final double recency = math.max(0.0, 1 - ageMin / (24 * 60));
      final double freq = math.min(1.0, (burst.length - 1) / 10);

      final score = (base * (1 + 0.4 * recency + 0.3 * freq)).round();

      ranked.add(RankedAlert(
        id: '$key|${first.epoch}',
        type: type,
        imei: first.raw['imei']?.toString(),
        vehnum: (first.raw['vehicleNumber'] ?? first.raw['vehnum'])?.toString(),
        accId: first.raw['accId']?.toString(),
        count: burst.length,
        score: score,
        firstAt: first.epoch,
        lastAt: last.epoch,
        address: (last.raw['address'] ?? first.raw['address'])?.toString(),
        speed: numOfOrNull(last.raw['speed']),
      ));
    }

    for (var i = 1; i < items.length; i++) {
      final prevEpoch = burst.last.epoch;
      final curEpoch = items[i].epoch;
      final gapMin =
          (prevEpoch != null && curEpoch != null) ? (curEpoch - prevEpoch) / 60000 : double.nan;
      if (gapMin.isFinite && gapMin <= _burstWindowMin) {
        burst.add(items[i]);
      } else {
        flush();
        burst = [items[i]];
      }
    }
    flush();
  });

  // Rank by score desc
  ranked.sort((a, b) => b.score.compareTo(a.score));

  // Emit findings for the top critical alerts
  for (final r in ranked) {
    if (r.score < 60) continue; // only surface high-urgency ones as findings
    findings.add(FleetFinding.make(
      agent: _agent,
      severity: r.score >= 90 ? Severity.critical : Severity.warning,
      code: 'ALERT_${r.type}',
      title: 'High-priority ${r.type} alert',
      detail: r.count > 1
          ? '${r.count} ${r.type} alerts from ${r.vehnum ?? r.imei} in a short burst.'
          : '${r.type} alert from ${r.vehnum ?? r.imei}.',
      imei: r.imei,
      vehnum: r.vehnum,
      accId: r.accId,
      value: 'score ${r.score}',
      raw: {'address': r.address, 'lastAt': r.lastAt},
    ));
  }

  final stats = PriorityStats(
    rawAlerts: alertsData.length,
    bursts: ranked.length,
    critical: ranked.where((r) => r.score >= 90).length,
    high: ranked.where((r) => r.score >= 60 && r.score < 90).length,
    collapsed: alertsData.length - ranked.length,
  );

  return AlertPriorityResult(ranked: ranked, findings: findings, stats: stats);
}