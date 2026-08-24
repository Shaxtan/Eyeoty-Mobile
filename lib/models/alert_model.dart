enum AlertSeverity { critical, high, medium, low }

/// Mirrors the alert shape returned by POST /usage/alerts/by-account in
/// the existing web app (confirmed endpoint - see AlertsService).
class FleetAlert {
  final String id;
  final String imei;
  final String? vehicleNumber;
  final String type;
  final String? message;
  final String? address;
  final double? lat;
  final double? lng;
  final String createdOn;
  final String? deviceTime;
  final num? speed; // used by OverspeedReportScreen

  FleetAlert({
    required this.id,
    required this.imei,
    this.vehicleNumber,
    required this.type,
    this.message,
    this.address,
    this.lat,
    this.lng,
    required this.createdOn,
    this.deviceTime,
    this.speed,
  });

  factory FleetAlert.fromJson(Map<String, dynamic> json) {
    return FleetAlert(
      id: (json['id'] ?? '').toString(),
      imei: (json['imei'] ?? '').toString(),
      vehicleNumber: json['vehicleNumber']?.toString(),
      type: json['type']?.toString() ?? 'General',
      message: json['message']?.toString(),
      address: json['address']?.toString(),
      lat: json['latitude'] is num ? (json['latitude'] as num).toDouble() : null,
      lng: json['longitude'] is num ? (json['longitude'] as num).toDouble() : null,
      createdOn: json['createdOn']?.toString() ?? '',
      deviceTime: json['deviceTime']?.toString(),
      speed: json['speed'] is num ? json['speed'] as num : num.tryParse('${json['speed']}'),
    );
  }

  /// NOTE: this is a simplified, best-effort mirror of the web app's
  /// utils/alertSeverity.js classifyAlert() logic, which was not
  /// included in the source shared during this conversion. Replace
  /// with the exact rules from that file once you paste it.
  AlertSeverity get severity {
    final t = type.toLowerCase();
    if (t.contains('overspeed') ||
        t.contains('harsh') ||
        t.contains('panic') ||
        t.contains('sos')) {
      return AlertSeverity.critical;
    }
    if (t.contains('geofence') ||
        t.contains('offline') ||
        t.contains('temperature')) {
      return AlertSeverity.high;
    }
    if (t.contains('battery') || t.contains('ignition')) {
      return AlertSeverity.medium;
    }
    return AlertSeverity.low;
  }
}