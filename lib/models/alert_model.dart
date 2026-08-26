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
      lat:
          json['latitude'] is num ? (json['latitude'] as num).toDouble() : null,
      lng: json['longitude'] is num
          ? (json['longitude'] as num).toDouble()
          : null,
      createdOn: json['createdOn']?.toString() ?? '',
      deviceTime: json['deviceTime']?.toString(),
      speed: json['speed'] is num
          ? json['speed'] as num
          : num.tryParse('${json['speed']}'),
    );
  }

  /// Human-readable label for the alert type, derived by scanning the
  /// backend's own `message` text (which describes what actually
  /// happened) rather than trusting the raw `type` code. The backend
  /// sometimes reuses a single code (e.g. "HAR") for multiple event
  /// kinds — the React web app's static ALERT_META map labels HAR as
  /// "Harsh Accel." even when the message says "Driver used Harsh
  /// Braking", so the label there disagrees with the message. This
  /// getter picks the label from the message itself so what you see
  /// matches what happened. Falls back to a title-cased version of the
  /// raw `type` code when the message doesn't match any known pattern.
  String get displayType {
    final m = (message ?? '').toLowerCase();
    if (m.contains('harsh braking') || m.contains('harsh brake')) {
      return 'Harsh Brake';
    }
    if (m.contains('harsh acceleration') || m.contains('harsh accel')) {
      return 'Harsh Accel.';
    }
    if (m.contains('harsh cornering') || m.contains('harsh turn')) {
      return 'Harsh Turn';
    }
    if (m.contains('ignition on')) {
      return 'Ignition On';
    }
    if (m.contains('ignition off')) {
      return 'Ignition Off';
    }
    if (m.contains('ignition')) {
      return 'Ignition';
    }
    if (m.contains('overspeed') ||
        m.contains('over speed') ||
        m.contains('speed limit')) {
      return 'Overspeed';
    }
    if (m.contains('geofence entry') ||
        m.contains('entered geofence') ||
        m.contains('geo-fence entry')) {
      return 'Geofence Entry';
    }
    if (m.contains('geofence exit') ||
        m.contains('exited geofence') ||
        m.contains('geo-fence exit')) {
      return 'Geofence Exit';
    }
    if (m.contains('geofence') || m.contains('geo-fence')) {
      return 'Geofence';
    }
    if (m.contains('low battery') || m.contains('battery low')) {
      return 'Low Battery';
    }
    if (m.contains('battery')) {
      return 'Battery';
    }
    if (m.contains('sos') || m.contains('panic')) {
      return 'SOS / Panic';
    }
    if (m.contains('tow') || m.contains('towed')) {
      return 'Tow';
    }
    if (m.contains('idle') || m.contains('idling')) {
      return 'Idle';
    }
    if (m.contains('tamper')) {
      return 'Tamper';
    }
    if (m.contains('offline') || m.contains('not reachable')) {
      return 'Offline';
    }
    if (m.contains('temperature')) {
      return 'Temperature';
    }

    // Fallback: title-case the raw type code (e.g. "HAR" -> "HAR",
    // "harsh_accel" -> "Harsh Accel") rather than showing an
    // all-caps three-letter code that means nothing to the user.
    if (type.trim().isEmpty) {
      return 'General';
    }
    return type
        .replaceAll('_', ' ')
        .split(' ')
        .where((w) => w.isNotEmpty)
        .map((w) => w.length <= 3
            ? w.toUpperCase()
            : w[0].toUpperCase() + w.substring(1).toLowerCase())
        .join(' ');
  }

  /// NOTE: this is a simplified, best-effort mirror of the web app's
  /// utils/alertSeverity.js classifyAlert() logic, which was not
  /// included in the source shared during this conversion. Replace
  /// with the exact rules from that file once you paste it.
  AlertSeverity get severity {
    // Classify from the derived display type (which is based on the
    // message) so severity matches what actually happened, not just the
    // raw code.
    final t = displayType.toLowerCase();
    if (t.contains('overspeed') ||
        t.contains('harsh') ||
        t.contains('panic') ||
        t.contains('sos')) {
      return AlertSeverity.critical;
    }
    if (t.contains('geofence') ||
        t.contains('offline') ||
        t.contains('temperature') ||
        t.contains('tamper')) {
      return AlertSeverity.high;
    }
    if (t.contains('battery') || t.contains('ignition')) {
      return AlertSeverity.medium;
    }
    return AlertSeverity.low;
  }
}
