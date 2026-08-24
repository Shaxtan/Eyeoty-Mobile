/// Mirrors the live-vehicle shape used by MapPage.jsx / TrackingPage.jsx
/// in the existing web app (imei, vehnum, lat, lng, status, speed, devTs).
class LiveVehicle {
  final String id; // imei
  final String? vehicleNumber;
  final double? lat;
  final double? lng;
  final String status; // Running | Idle | Stopped | Inactive | No Data
  final num speed;
  final String? lastUpdate;

  LiveVehicle({
    required this.id,
    this.vehicleNumber,
    this.lat,
    this.lng,
    required this.status,
    this.speed = 0,
    this.lastUpdate,
  });

  String get displayName =>
      (vehicleNumber != null && vehicleNumber!.isNotEmpty) ? vehicleNumber! : id;

  factory LiveVehicle.fromJson(Map<String, dynamic> json) {
    return LiveVehicle(
      id: (json['imei'] ?? json['id'] ?? '').toString(),
      vehicleNumber:
          json['vehnum']?.toString() ?? json['vehicleNumber']?.toString(),
      lat: _toDouble(json['lat']),
      lng: _toDouble(json['lng']),
      status: json['status']?.toString() ?? 'No Data',
      speed: json['speed'] is num
          ? json['speed'] as num
          : num.tryParse('${json['speed']}') ?? 0,
      lastUpdate: json['devTs']?.toString() ?? json['cts']?.toString(),
    );
  }

  static double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }
}
