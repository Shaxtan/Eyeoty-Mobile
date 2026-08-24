/// Matches the /usage/alerts/db-alerts response shape:
///   { summary: [{ type, count }], data: [ {...alert} ] }
/// This is a DIFFERENT endpoint/data source from /usage/alerts/by-account
/// (used by the full Alert Dashboard screen) — kept separate on purpose,
/// exactly like the web app keeps useDashboardAlerts and AlertsPage's own
/// fetch logic separate.
class DbAlert {
  final String? id;
  final String type; // short code: BAT, HAR, OVS, GEO, IGN, SOS, TOW, IDL, HBR
  final String? vehicleNumber;
  final String? imei;
  final String? address;
  final String? message;
  final num? speed;
  final num? battery;
  final String? createdOn;

  DbAlert({
    this.id,
    required this.type,
    this.vehicleNumber,
    this.imei,
    this.address,
    this.message,
    this.speed,
    this.battery,
    this.createdOn,
  });

  factory DbAlert.fromJson(Map<String, dynamic> json) {
    return DbAlert(
      id: json['id']?.toString(),
      type: (json['type'] ?? '').toString(),
      vehicleNumber: json['vehicleNumber']?.toString(),
      imei: json['imei']?.toString(),
      address: json['address']?.toString(),
      message: json['message']?.toString(),
      speed: json['speed'] is num ? json['speed'] as num : null,
      battery: json['battery'] is num ? json['battery'] as num : null,
      createdOn: json['createdOn']?.toString(),
    );
  }
}

class AlertTypeCount {
  final String type;
  final int count;
  AlertTypeCount({required this.type, required this.count});

  factory AlertTypeCount.fromJson(Map<String, dynamic> json) {
    return AlertTypeCount(
      type: (json['type'] ?? '').toString(),
      count: json['count'] is num ? (json['count'] as num).toInt() : 0,
    );
  }
}

class DbAlertsResult {
  final List<AlertTypeCount> summary;
  final List<DbAlert> alerts;
  DbAlertsResult({required this.summary, required this.alerts});
  factory DbAlertsResult.empty() => DbAlertsResult(summary: [], alerts: []);
}
