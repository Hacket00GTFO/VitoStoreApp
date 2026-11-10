/// Modelo de usuario. Refleja el `User` de Prisma consumido via `/api/account/me`.
///
/// Solo campos no sensibles (el password nunca llega al cliente).
class User {
  User({
    required this.id,
    required this.email,
    required this.role,
    this.firstName,
    this.lastName,
    this.phone,
    this.emailVerified,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    // GET /account/me anida el telefono en `profile.phone` (UserProfile).
    final profile = json['profile'];
    return User(
      id: json['id'] as String,
      email: json['email'] as String,
      role: (json['role'] as String?) ?? 'USER',
      firstName: json['firstName'] as String?,
      lastName: json['lastName'] as String?,
      phone: (json['phone'] as String?) ??
          (profile is Map<String, dynamic> ? profile['phone'] as String? : null),
      emailVerified: json['emailVerified'] as bool?,
    );
  }

  final String id;
  final String email;
  final String role;
  final String? firstName;
  final String? lastName;
  final String? phone;
  final bool? emailVerified;

  String get fullName => [firstName, lastName].whereType<String>().join(' ').trim();

  bool get isAdmin => role == 'ADMIN';
  bool get isModerator => role == 'MODERATOR';

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'role': role,
        'firstName': firstName,
        'lastName': lastName,
        'phone': phone,
        'emailVerified': emailVerified,
      };
}
