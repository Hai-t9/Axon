import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import 'auth_models.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(apiClient: ref.watch(apiClientProvider));
});

class AuthRepository {
  AuthRepository({required ApiClient apiClient, GoogleSignIn? googleSignIn})
      : _apiClient = apiClient,
        _googleSignIn = googleSignIn;

  final ApiClient _apiClient;
  GoogleSignIn? _googleSignIn;

  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    final payload = {
      'email': email.trim(),
      'password': password,
    };
    final response = await _apiClient.postJson('/register/login', payload);
    return AuthSession.fromJson(response);
  }

  Future<AuthSession> signup({
    required String email,
    required String password,
    required String fullName,
  }) async {
    final payload = {
      'email': email.trim(),
      'password': password,
      'full_name': fullName.trim(),
    };
    final response = await _apiClient.postJson('/register/signup', payload);
    return AuthSession.fromJson(response);
  }

  Future<AuthSession> signInWithGoogle() async {
    final googleSignIn = _ensureGoogleSignIn();
    final account = await googleSignIn.signIn();
    if (account == null) {
      throw const AuthCancelledException();
    }

    final auth = await account.authentication;
    // TODO: exchange auth.idToken with backend when a Google auth endpoint exists.
    return AuthSession.google(
      email: account.email,
      displayName: account.displayName,
      accessToken: auth.accessToken,
      idToken: auth.idToken,
    );
  }

  Future<void> signOutGoogle() async {
    final googleSignIn = _googleSignIn;
    if (googleSignIn == null) {
      return;
    }
    await googleSignIn.signOut();
  }

  GoogleSignIn _ensureGoogleSignIn() {
    final existing = _googleSignIn;
    if (existing != null) {
      return existing;
    }

    final clientId = AppConfig.googleClientId.trim();
    if (kIsWeb && clientId.isEmpty) {
      throw const MissingGoogleClientIdException();
    }

    final created = clientId.isEmpty
        ? GoogleSignIn(scopes: const ['email', 'profile'])
        : GoogleSignIn(clientId: clientId, scopes: const ['email', 'profile']);
    _googleSignIn = created;
    return created;
  }
}

class AuthCancelledException implements Exception {
  const AuthCancelledException();

  @override
  String toString() => 'Sign-in was canceled.';
}

class MissingGoogleClientIdException implements Exception {
  const MissingGoogleClientIdException();

  @override
  String toString() =>
      'Google sign-in needs a client ID. Set GOOGLE_CLIENT_ID and restart.';
}
