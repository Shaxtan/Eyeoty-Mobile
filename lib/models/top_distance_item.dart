/// Matches useTopDistanceDevices() in useDashboard.js — one entry per
/// vehicle, ranked server-side by /usage/reports/top-distance-devices.
class TopDistanceItem {
  final String name;
  final int valueKm;
  final String? imei;
  final String? accountId;
  final String? accountName;

  TopDistanceItem({
    required this.name,
    required this.valueKm,
    this.imei,
    this.accountId,
    this.accountName,
  });

  factory TopDistanceItem.fromJson(Map<String, dynamic> json) {
    final distance = json['distance'] ?? json['gpsDistance'] ?? 0;
    final num distNum = distance is num ? distance : num.tryParse('$distance') ?? 0;
    return TopDistanceItem(
      name: (json['vehNum'] ?? json['id'] ?? 'Unknown').toString(),
      valueKm: distNum.round(),
      imei: json['id']?.toString(),
      accountId: json['accId']?.toString(),
      accountName: json['accName']?.toString(),
    );
  }
}
