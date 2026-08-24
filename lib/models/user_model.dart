/// Field names match the REAL login response (confirmed against
/// auth.service.js / apiService.js).
class AppUser {
  final String id;
  final String name;
  final String? email;
  final String role;
  final String accountId;

  AppUser({
    required this.id,
    required this.name,
    this.email,
    required this.role,
    required this.accountId,
  });
}