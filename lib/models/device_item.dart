/// A live "VTS" device row, matching FleetTableCard.jsx's `vtsData`
/// (sourced from dashboard.service.js's `VTS.available` list). Also
/// used by Map View, which fetches the same POST
/// /usage/reports/report/mapview?accid=<id> endpoint.
///
/// Status classification is ported EXACTLY from FleetTableCard.jsx's
/// getVtsStatus(): staleness (>1hr since last update -> offline) takes
/// priority, then ignition off -> stopped, then speed>5 -> motion,
/// else idle. Map View uses a DIFFERENT classification (no staleness
/// check, adds a "Locked" state) - see lib/core/map_view/map_view_status.dart
/// for that one; it's a genuinely separate function in the original app
/// too (MapPage.jsx's own getStatus(), distinct from FleetTableCard's).
class DeviceItem {
  final String imei;
  final String? accountName;
  final String? accountId; // accid - used for tracking nav / account popup
  final String? vehicleNumber;
  final String? powerStatus; // powsts: 'Y' | other
  final String? deviceTime; // devTs
  final String? cts;
  final String? address;
  final double? lat;
  final double? lng;
  final String? gps; // 'A' = active
  final String? ignition; // 'Y' | 'N'
  final num speed;
  final String? lock; // '1'/'0' or 'true'/'false' depending on device type - used by Map View only

  DeviceItem({
    required this.imei,
    this.accountName,
    this.accountId,
    this.vehicleNumber,
    this.powerStatus,
    this.deviceTime,
    this.cts,
    this.address,
    this.lat,
    this.lng,
    this.gps,
    this.ignition,
    this.speed = 0,
    this.lock,
  });

  String get displayName =>
      (vehicleNumber != null && vehicleNumber!.isNotEmpty) ? vehicleNumber! : imei;

  String? get lastUpdate => deviceTime ?? cts;

  /// 'motion' | 'idle' | 'stopped' | 'offline' - ported 1:1 from
  /// FleetTableCard.jsx's getVtsStatus(). Used by FleetDevicesScreen and
  /// the Dashboard's mini live map.
  String get status {
    final ignOn = (ignition ?? '').toUpperCase() == 'Y';
    final sp = speed.toDouble();
    final rawTs = deviceTime ?? cts;
    if (rawTs != null && rawTs.isNotEmpty) {
      final ts = DateTime.tryParse(rawTs.replaceFirst(' ', 'T'));
      if (ts != null) {
        final diff = DateTime.now().difference(ts);
        if (diff.inMinutes > 60) return 'offline';
      }
    }
    if (!ignOn) return 'stopped';
    if (sp > 5) return 'motion';
    return 'idle';
  }

  factory DeviceItem.fromJson(Map<String, dynamic> json) {
    return DeviceItem(
      imei: (json['imei'] ?? '').toString(),
      accountName: json['accountName']?.toString(),
      accountId: json['accid']?.toString() ?? json['accountId']?.toString(),
      vehicleNumber: json['vehnum']?.toString() ?? json['name']?.toString(),
      powerStatus: json['powsts']?.toString(),
      deviceTime: json['devTs']?.toString(),
      cts: json['cts']?.toString(),
      address: json['address']?.toString(),
      lat: _toDouble(json['lat']),
      lng: _toDouble(json['lng']),
      gps: json['gps']?.toString(),
      ignition: json['ign']?.toString(),
      speed: json['speed'] is num
          ? json['speed'] as num
          : num.tryParse('${json['speed']}') ?? 0,
      lock: json['lock']?.toString(),
    );
  }

  static double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }
}