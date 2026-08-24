/// One day's utilization point on the trend chart.
class UtilizationPoint {
  final String dayLabel; // 'Sun'..'Sat'
  final int utilization; // 0-100

  UtilizationPoint({required this.dayLabel, required this.utilization});
}

/// Result of useFleetUtilization() in useDashboard.js — derived (not a
/// direct endpoint) from 7 days of getAccountSummaryReport calls: the
/// % of fleet accounts that moved (totalDistance > 0) each day.
class UtilizationResult {
  final List<UtilizationPoint> points;
  final int avg;
  final int trend;

  UtilizationResult({required this.points, required this.avg, required this.trend});

  factory UtilizationResult.empty() => UtilizationResult(points: [], avg: 0, trend: 0);
}
