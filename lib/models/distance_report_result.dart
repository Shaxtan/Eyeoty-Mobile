/// Ported from DistanceReportPage.jsx's report shape.
class DistanceRecord {
  final String? repDate;
  final int? hr;
  final num distance;
  final num speed;
  final String? vehNum;

  DistanceRecord({this.repDate, this.hr, this.distance = 0, this.speed = 0, this.vehNum});

  factory DistanceRecord.fromJson(Map<String, dynamic> json) {
    return DistanceRecord(
      repDate: json['repDate']?.toString(),
      hr: json['hr'] is num ? (json['hr'] as num).toInt() : int.tryParse('${json['hr']}'),
      distance: json['distance'] is num ? json['distance'] as num : num.tryParse('${json['distance']}') ?? 0,
      speed: json['speed'] is num ? json['speed'] as num : num.tryParse('${json['speed']}') ?? 0,
      vehNum: json['vehNum']?.toString(),
    );
  }
}

class DistanceReportResult {
  final List<DistanceRecord> vehicleDistances;
  final num totalDistanceKm;
  final num avgSpeed;
  final String? imei;

  DistanceReportResult({
    required this.vehicleDistances,
    required this.totalDistanceKm,
    required this.avgSpeed,
    this.imei,
  });

  /// vehNum lives on the first RECORD, not the top-level report object
  /// (matches DistanceReportPage.jsx's `firstRow?.vehNum` exactly).
  String? get vehNum => vehicleDistances.isNotEmpty ? vehicleDistances.first.vehNum : null;

  factory DistanceReportResult.fromJson(Map<String, dynamic> json) {
    final list = (json['vehicleDistances'] as List<dynamic>?) ?? [];
    return DistanceReportResult(
      vehicleDistances: list.map((e) => DistanceRecord.fromJson(e as Map<String, dynamic>)).toList(),
      totalDistanceKm:
          json['totalDistanceKm'] is num ? json['totalDistanceKm'] as num : num.tryParse('${json['totalDistanceKm']}') ?? 0,
      avgSpeed: json['avgSpeed'] is num ? json['avgSpeed'] as num : num.tryParse('${json['avgSpeed']}') ?? 0,
      imei: json['imei']?.toString(),
    );
  }
}