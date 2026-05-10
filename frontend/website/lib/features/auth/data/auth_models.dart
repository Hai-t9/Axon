enum AuthProvider { password }

class AuthUser {
  const AuthUser({
    this.id,
    required this.fullname,
    required this.email,
    this.phone,
  });

  final String? id;
  final String fullname;
  final String email;
  final String? phone;

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    final rawId = json['id'];
    return AuthUser(
      id: rawId == null ? null : rawId.toString(),
      fullname: (json['fullname'] ?? '') as String,
      email: (json['email'] ?? '') as String,
      phone: json['phone'] as String?,
    );
  }
}

class AuthSession {
  const AuthSession({
    required this.provider,
    required this.user,
    this.accessToken,
    this.tokenType,
  });

  final AuthProvider provider;
  final String? accessToken;
  final String? tokenType;
  final AuthUser user;

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    return AuthSession(
      provider: AuthProvider.password,
      accessToken: json['access_token'] as String?,
      tokenType: json['token_type'] as String?,
      user: AuthUser.fromJson(json['user'] as Map<String, dynamic>),
    );
  }
}
