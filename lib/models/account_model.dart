/// Ported from useAccountStore.js's account shape:
///   { id, label, type, parentAccountId, status, vehicles }
class Account {
  final String id;
  final String label;
  final String? type;
  final String? parentAccountId;
  final String? status;
  /// NOTE: the real web app hardcodes this to 0 (see useAccountStore.js's
  /// `vehicles: 0` in loadAccounts()) - it is NOT populated from the
  /// dropdown endpoint. Kept here for UI parity with the desktop app,
  /// which also always shows "0 vehicles" for this reason - not a gap
  /// in this port, a gap in the source app itself.
  final int vehicles;

  Account({
    required this.id,
    required this.label,
    this.type,
    this.parentAccountId,
    this.status,
    this.vehicles = 0,
  });

  factory Account.fromJson(Map<String, dynamic> json) {
    return Account(
      id: json['id']?.toString() ?? '',
      label: json['label']?.toString() ?? json['name']?.toString() ?? '',
      type: json['type']?.toString(),
      parentAccountId: json['parentAccountId']?.toString(),
      status: json['status']?.toString(),
      vehicles: 0,
    );
  }
}