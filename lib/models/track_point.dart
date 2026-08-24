/// Ported 1:1 from apiService.js's getTrackPlayHistory() normalisation
/// step - the same status classification logic (speed/ignition-based,
/// no staleness check), used by StoppageReportScreen's clustering
/// algorithm and, later, a dedicated Track Play screen.
class TrackPoint {
  final String? name;
  final double? lat;
  final double? lng;
  final String? ts;
  final num speed;
  final num? disha;
  final String ign;
  final String status; // MOTION | IDLE | STOP

  TrackPoint({
    this.name,
    this.lat,
    this.lng,
    this.ts,
    this.speed = 0,
    this.disha,
    this.ign = '',
    required this.status,
  });

  factory TrackPoint.fromJson(Map<String, dynamic> item) {
    final speed = item['speed'] is num ? item['speed'] as num : num.tryParse('${item['speed']}') ?? 0;
    final ign = (item['ign'] ?? '').toString().toUpperCase();

    String status;
    if (speed > 5) {
      status = 'MOTION';
    } else if (speed > 0) {
      status = 'IDLE';
    } else if (ign == 'Y') {
      status = 'IDLE';
    } else {
      status = 'STOP';
    }

    return TrackPoint(
      name: (item['vehicleNumber'] ?? item['imei'])?.toString(),
      lat: item['latitude'] is num
          ? (item['latitude'] as num).toDouble()
          : double.tryParse('${item['latitude']}'),
      lng: item['longitude'] is num
          ? (item['longitude'] as num).toDouble()
          : double.tryParse('${item['longitude']}'),
      ts: item['deviceTime']?.toString(),
      speed: speed,
      disha: item['disha'] != null
          ? (item['disha'] is num ? item['disha'] as num : num.tryParse('${item['disha']}'))
          : null,
      ign: ign,
      status: status,
    );
  }
}