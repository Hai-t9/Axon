enum AuthProvider { password, google }

class AuthUser {
  const AuthUser({
    this.id,
    required this.fullname,
    required this.email,
    this.phone,
  });

  final int? id;
  final String fullname;
  final String email;
  final String? phone;

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: json['id'] as int?,
      fullname: (json['fullname'] ?? '') as String,
      email: (json['email'] ?? '') as String,
      phone: json['phone'] as String?,
    );
  }

  factory AuthUser.google({required String email, String? displayName}) {
    final fallbackName = email.split('@').first;
    return AuthUser(
      fullname: (displayName == null || displayName.trim().isEmpty)
          ? fallbackName
          : displayName.trim(),
      email: email,
    );
  }
}

class AuthSession {
  const AuthSession({
    required this.provider,
    required this.user,
    this.accessToken,
    this.tokenType,
    this.googleAccessToken,
    this.googleIdToken,
  });

  final AuthProvider provider;
  final String? accessToken;
  final String? tokenType;
  final AuthUser user;
  final String? googleAccessToken;
  final String? googleIdToken;

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    return AuthSession(
      provider: AuthProvider.password,
      accessToken: json['access_token'] as String?,
      tokenType: json['token_type'] as String?,
      user: AuthUser.fromJson(json['user'] as Map<String, dynamic>),
    );
  }

  factory AuthSession.google({
    required String email,
    String? displayName,
    String? accessToken,
    String? idToken,
  }) {
    return AuthSession(
      provider: AuthProvider.google,
      googleAccessToken: accessToken,
      googleIdToken: idToken,
      user: AuthUser.google(email: email, displayName: displayName),
    );
  }

  bool get isGoogle => provider == AuthProvider.google;
}
