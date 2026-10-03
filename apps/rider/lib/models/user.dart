/// Authenticated user, from POST /api/v1/auth/otp/verify.
class AppUser {
  AppUser({
    required this.id,
    required this.name,
    required this.phone,
    required this.role,
    this.avatar,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      role: json['role'] as String? ?? 'customer',
      avatar: json['avatar'] as String?,
    );
  }

  final int id;
  final String name;
  final String phone;
  final String role;
  final String? avatar;

  bool get isRider => role == 'rider';
}
