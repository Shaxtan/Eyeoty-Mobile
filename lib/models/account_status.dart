/// Matches the AccountPopup's `data` shape in FleetTableCard.jsx, sourced
/// from GET /accounts/account-status?accountId=<id>.
class AccountStatus {
  final String? name;
  final String? id;
  final String? type;
  final String? parentAccountId;
  final String? status; // 'A' = Active, 'I' = Inactive

  AccountStatus({this.name, this.id, this.type, this.parentAccountId, this.status});

  bool get isActive => status == 'A';
  String get statusLabel =>
      status == 'A' ? 'Active' : (status == 'I' ? 'Inactive' : (status ?? '\u2014'));

  factory AccountStatus.fromJson(Map<String, dynamic> json) {
    return AccountStatus(
      name: json['name']?.toString(),
      id: json['id']?.toString(),
      type: json['type']?.toString(),
      parentAccountId: json['parentAccountId']?.toString(),
      status: json['status']?.toString(),
    );
  }
}
