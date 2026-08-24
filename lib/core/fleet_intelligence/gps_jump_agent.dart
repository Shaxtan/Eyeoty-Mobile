import '../../models/fleet_scan_result.dart';
import 'agent_helpers.dart';

const _agent = 'gps-jump';
const _maxPlausibleKmh = 200;
const _minDtSeconds = 2;

class GpsJumpResult {
  final List<FleetFinding> findings;
  final Map<String, dynamic> stats;
  GpsJumpResult({required this.findings, required this.stats});
}

class _GpsPoint {
  final double lat;
  final double lng;
  final int t;
  final num? speed;
  final String? imei;
  final String? vehnum;
  _GpsPoint({required this.lat, required this.lng, required this.t, this.speed, this.imei, this.vehnum});
}

/// Ported 1:1 from gpsJump.agent.js (Agent #7). NOT called by
/// runFleetScan (same as the original web app) — it takes ONE vehicle's
/// ordered track points, a different shape from the bulk device list the
/// other three agents consume. Kept here for parity and for future
/// wiring into TrackPlay.
GpsJumpResult runGpsJumpAgent(List<Map<String, dynamic>> points, {bool sort = false}) {
  final findings = <FleetFinding>[];
  var jumps = 0;
  var maxImpliedKmh = 0.0;
  var totalGapKm = 0.0;

  var pts = <_GpsPoint>[];
  for (final p in points) {
    final lat = numOf(p['lat'] ?? p['latitude'], double.nan).toDouble();
    final lng = numOf(p['lng'] ?? p['longitude'], double.nan).toDouble();
    final t = parseTs(p['ts'] ?? p['deviceTime'] ?? p['devTs']);
    if (isValidLat(lat) && isValidLng(lng) && t != null) {
      pts.add(_GpsPoint(
        lat: lat,
        lng: lng,
        t: t,
        speed: numOfOrNull(p['speed']),
        imei: p['imei']?.toString(),
        vehnum: (p['vehicleNumber'] ?? p['vehnum'] ?? p['name'])?.toString(),
      ));
    }
  }

  if (sort) pts.sort((a, b) => a.t.compareTo(b.t));

  if (pts.length < 2) {
    return GpsJumpResult(
      findings: findings,
      stats: {'total': points.length, 'jumps': 0, 'maxImpliedKmh': 0, 'totalGapKm': 0.0},
    );
  }

  for (var i = 1; i < pts.length; i++) {
    final a = pts[i - 1];
    final b = pts[i];
    final dtSec = (b.t - a.t) / 1000;
    if (dtSec < _minDtSeconds) continue; // too close in time to judge

    final distKm = haversineKm(a.lat, a.lng, b.lat, b.lng);
    final impliedKmh = (distKm / dtSec) * 3600;

    if (impliedKmh > _maxPlausibleKmh) {
      jumps++;
      totalGapKm += distKm;
      if (impliedKmh > maxImpliedKmh) maxImpliedKmh = impliedKmh;

      final severity = impliedKmh > _maxPlausibleKmh * 3 ? Severity.critical : Severity.warning;

      findings.add(FleetFinding.make(
        agent: _agent,
        severity: severity,
        code: 'GPS_JUMP',
        title: 'Impossible GPS jump',
        detail: 'Vehicle appears to move ${distKm.toStringAsFixed(1)} km in ${dtSec.toStringAsFixed(0)}s '
            '(implied ${impliedKmh.round()} km/h). Likely a GPS glitch or spoofed fix.',
        imei: b.imei,
        vehnum: b.vehnum,
        value: '${impliedKmh.round()} km/h',
        expected: '\u2264 $_maxPlausibleKmh km/h',
        raw: {
          'from': {'lat': a.lat, 'lng': a.lng, 't': a.t},
          'to': {'lat': b.lat, 'lng': b.lng, 't': b.t},
          'distKm': double.parse(distKm.toStringAsFixed(3)),
          'dtSec': double.parse(dtSec.toStringAsFixed(1)),
        },
      ));
    }
  }

  return GpsJumpResult(
    findings: findings,
    stats: {
      'total': points.length,
      'jumps': jumps,
      'maxImpliedKmh': maxImpliedKmh.round(),
      'totalGapKm': double.parse(totalGapKm.toStringAsFixed(1)),
    },
  );
}