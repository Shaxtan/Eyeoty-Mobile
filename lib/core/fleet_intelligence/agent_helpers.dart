import 'dart:math' as math;
import '../../models/fleet_scan_result.dart';

/// Ported 1:1 from helpers.js — shared utilities for the Fleet
/// Intelligence agents. Framework-agnostic pure functions, same as the
/// original (these could move to a Node service untouched, same as the
/// JS comment says).

class Severity {
  static const critical = 'critical';
  static const warning = 'warning';
  static const info = 'info';
}

const Map<String, int> kSeverityRank = {'critical': 3, 'warning': 2, 'info': 1};

/// Coerces [v] to a non-null num, matching JS's num(v, fallback=0).
/// Named `numOf` (not `num`) since `num` is a reserved type name in Dart.
num numOf(dynamic v, [num fallback = 0]) {
  if (v == null) return fallback;
  if (v is num) return v;
  return num.tryParse(v.toString()) ?? fallback;
}

/// Matches JS call sites using num(v, null) — returns null instead of a
/// numeric fallback when [v] is missing/unparseable.
num? numOfOrNull(dynamic v) {
  if (v == null) return null;
  if (v is num) return v;
  return num.tryParse(v.toString());
}

/// Parses a backend timestamp leniently -> epoch ms, or null if
/// unparseable. Matches parseTs(): numbers > 1e12 are already ms,
/// smaller numbers are seconds; strings go through date parsing.
int? parseTs(dynamic v) {
  if (v == null) return null;
  if (v is num) {
    return v > 1e12 ? v.round() : (v * 1000).round();
  }
  final d = DateTime.tryParse(v.toString());
  return d?.millisecondsSinceEpoch;
}

const int _msDay = 86400000;

/// Is this timestamp implausible (far future / far past)? Returns the
/// reason string or null, matching timestampSanity() exactly.
String? timestampSanity(int? epochMs, int nowMs) {
  if (epochMs == null) return 'unparseable';
  if (epochMs > nowMs + _msDay) return 'future';
  if (epochMs < 946684800000) return 'ancient'; // before 2000-01-01
  return null;
}

bool isValidLat(num v) => v.isFinite && v >= -90 && v <= 90 && v != 0;
bool isValidLng(num v) => v.isFinite && v >= -180 && v <= 180 && v != 0;

const double _earthRadiusKm = 6371;
double _toRad(double d) => d * math.pi / 180;

/// Haversine distance in km between two points.
double haversineKm(double lat1, double lng1, double lat2, double lng2) {
  final dLat = _toRad(lat2 - lat1);
  final dLng = _toRad(lng2 - lng1);
  final sinDLat = math.sin(dLat / 2);
  final sinDLng = math.sin(dLng / 2);
  final a = sinDLat * sinDLat +
      math.cos(_toRad(lat1)) * math.cos(_toRad(lat2)) * sinDLng * sinDLng;
  return 2 * _earthRadiusKm * math.asin(math.sqrt(a));
}

/// Sort findings by severity (critical first), then most-recent.
List<FleetFinding> sortFindings(List<FleetFinding> findings) {
  final copy = [...findings];
  copy.sort((a, b) {
    final s = (kSeverityRank[b.severity] ?? 0) - (kSeverityRank[a.severity] ?? 0);
    return s != 0 ? s : b.ts.compareTo(a.ts);
  });
  return copy;
}