/// Ported from HourlyReportPage.jsx's session/record shape (Working
/// Hour Report - POST /usage/reports/workinghourreport, per its own
/// header-comment documentation).
class WorkingHourSession {
  final String? startTime;
  final String? endTime;
  final dynamic duration; // string "H:MM" or a number of minutes - kept dynamic to match fmtDuration()'s flexible handling
  final num distance;
  final num gpsDistance;
  final num avgSpeed;
  final String? status;
  final String? startLocation;
  final String? endLocation;

  WorkingHourSession({
    this.startTime,
    this.endTime,
    this.duration,
    this.distance = 0,
    this.gpsDistance = 0,
    this.avgSpeed = 0,
    this.status,
    this.startLocation,
    this.endLocation,
  });

  factory WorkingHourSession.fromJson(Map<String, dynamic> json) {
    return WorkingHourSession(
      startTime: json['startTime']?.toString(),
      endTime: json['endTime']?.toString(),
      duration: json['duration'],
      distance: json['distance'] is num ? json['distance'] as num : num.tryParse('${json['distance']}') ?? 0,
      gpsDistance: json['gpsDistance'] is num ? json['gpsDistance'] as num : num.tryParse('${json['gpsDistance']}') ?? 0,
      avgSpeed: json['avgSpeed'] is num ? json['avgSpeed'] as num : num.tryParse('${json['avgSpeed']}') ?? 0,
      status: json['status']?.toString(),
      startLocation: json['startLocation']?.toString(),
      endLocation: json['endLocation']?.toString(),
    );
  }
}

class WorkingHourRecord {
  final String? id;
  final String imei;
  final String? vehNum;
  final String? repDate;
  final num totalDistance;
  final dynamic totalDuration;
  final List<WorkingHourSession> sessions;

  WorkingHourRecord({
    this.id,
    required this.imei,
    this.vehNum,
    this.repDate,
    this.totalDistance = 0,
    this.totalDuration,
    this.sessions = const [],
  });

  factory WorkingHourRecord.fromJson(Map<String, dynamic> json) {
    final sessionsList = (json['sessions'] as List<dynamic>?) ?? [];
    return WorkingHourRecord(
      id: json['id']?.toString(),
      imei: (json['imei'] ?? '').toString(),
      vehNum: json['vehNum']?.toString(),
      repDate: json['repDate']?.toString(),
      totalDistance: json['totalDistance'] is num ? json['totalDistance'] as num : num.tryParse('${json['totalDistance']}') ?? 0,
      totalDuration: json['totalDuration'],
      sessions: sessionsList.map((e) => WorkingHourSession.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}