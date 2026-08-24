/// Ported from getImeiDropdown()'s per-item shape.
class ImeiOption {
  final String imei;
  final String? vehnum;

  ImeiOption({required this.imei, this.vehnum});

  String get label => (vehnum != null && vehnum!.isNotEmpty) ? '$vehnum ($imei)' : imei;

  factory ImeiOption.fromJson(Map<String, dynamic> json) {
    return ImeiOption(
      imei: (json['imei'] ?? '').toString(),
      vehnum: json['vehnum']?.toString(),
    );
  }
}