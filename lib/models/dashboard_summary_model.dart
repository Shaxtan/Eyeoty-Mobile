/// CONFIRMED real field names from dashboard.service.js:
///   { offline, onlineIdle, unreachable, totalDevices, onlineStopped, onlineMotion }
/// The envelope may be double-nested (data.data) or single (data) —
/// both are checked, mirroring dashboard.service.js's own fallback.
class DashboardSummary {
  final int totalVehicles;
  final int moving;
  final int stopped;
  final int idle;
  final int offline;
  final int unreachable;

  DashboardSummary({
    required this.totalVehicles,
    required this.moving,
    required this.stopped,
    required this.idle,
    required this.offline,
    required this.unreachable,
  });

  /// [body] is the raw decoded envelope: { resultCode, message, data: {...} }
  factory DashboardSummary.fromEnvelope(Map<String, dynamic> body) {
    final data = body['data'] as Map<String, dynamic>? ?? {};
    final inner = (data['data'] as Map<String, dynamic>?) ?? data;
    final summary = (inner['summary'] as Map<String, dynamic>?) ?? {};

    return DashboardSummary(
      totalVehicles: _toInt(summary['totalDevices']),
      moving: _toInt(summary['onlineMotion']),
      stopped: _toInt(summary['onlineStopped']),
      idle: _toInt(summary['onlineIdle']),
      offline: _toInt(summary['offline']),
      unreachable: _toInt(summary['unreachable']),
    );
  }

  static int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }
}