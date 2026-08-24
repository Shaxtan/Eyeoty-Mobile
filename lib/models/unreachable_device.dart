/// Matches FleetTableCard.jsx's `unreachableData` rows, sourced from
/// dashboard.service.js -> POST /usage/reports/report/unrechableDevices
class UnreachableDevice {
  final String imei;
  final String? accountName;
  final String? accountId;
  final String? vehicleNumber;
  final String? deviceType;
  final String? createdOn;

  UnreachableDevice({
    required this.imei,
    this.accountName,
    this.accountId,
    this.vehicleNumber,
    this.deviceType,
    this.createdOn,
  });

  String get displayName =>
      (vehicleNumber != null && vehicleNumber!.isNotEmpty) ? vehicleNumber! : imei;

  factory UnreachableDevice.fromJson(Map<String, dynamic> json) {
    return UnreachableDevice(
      imei: (json['imei'] ?? '').toString(),
      accountName: json['accountName']?.toString(),
      accountId: json['accid']?.toString(),
      vehicleNumber: json['vehnum']?.toString() ?? json['name']?.toString(),
      deviceType: json['deviceType']?.toString(),
      createdOn: json['createdOn']?.toString(),
    );
  }
}
