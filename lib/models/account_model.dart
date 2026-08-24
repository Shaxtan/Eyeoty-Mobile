class Account {
  final String id;
  final String label;

  Account({required this.id, required this.label});

  factory Account.fromJson(Map<String, dynamic> json) {
    return Account(
      id: json['id']?.toString() ?? '',
      label: json['label']?.toString() ?? json['name']?.toString() ?? '',
    );
  }
}
