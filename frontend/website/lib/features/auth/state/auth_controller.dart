import 'dart:convert';
import 'dart:html';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/auth_models.dart';
import '../data/auth_repository.dart';

const _storageKey = 'auth_session';

final authControllerProvider =
    AsyncNotifierProvider<AuthController, AuthSession?>(AuthController.new);

class AuthController extends AsyncNotifier<AuthSession?> {
  @override
  Future<AuthSession?> build() async {
    return _load();
  }

  Future<void> login({
    required String email,
    required String password,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard<AuthSession?>(() async {
      final session = await ref.read(authRepositoryProvider).login(
            email: email,
            password: password,
          );
      _save(session);
      return session;
    });
  }

  Future<void> signup({
    required String email,
    required String password,
    required String fullName,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard<AuthSession?>(() async {
      final session = await ref.read(authRepositoryProvider).signup(
            email: email,
            password: password,
            fullName: fullName,
          );
      _save(session);
      return session;
    });
  }

  Future<void> signInWithGoogle() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard<AuthSession?>(() async {
      return ref.read(authRepositoryProvider).signInWithGoogle();
    });
  }

  Future<void> signOut() async {
    await ref.read(authRepositoryProvider).signOutGoogle();
    _clear();
    state = const AsyncData(null);
  }

  void _save(AuthSession session) {
    try {
      final data = jsonEncode({
        'access_token': session.accessToken,
        'user': {
          'id': session.user.id,
          'fullname': session.user.fullname,
          'email': session.user.email,
        },
      });
      document.cookie =
          '$_storageKey=${Uri.encodeComponent(data)}; path=/; max-age=604800';
    } catch (_) {
      // Storage unavailable
    }
  }

  AuthSession? _load() {
    try {
      final cookies = document.cookie ?? '';
      final match = RegExp('$_storageKey=([^;]+)').firstMatch(cookies);
      if (match == null) return null;
      final data =
          jsonDecode(Uri.decodeComponent(match.group(1)!)) as Map<String, dynamic>;
      final accessToken = data['access_token'] as String?;
      final userData = data['user'] as Map<String, dynamic>?;
      if (accessToken == null || userData == null) return null;
      final user = AuthUser.fromJson(userData);
      return AuthSession(
        provider: AuthProvider.password,
        accessToken: accessToken,
        user: user,
      );
    } catch (_) {
      return null;
    }
  }

  void _clear() {
    try {
      document.cookie = '$_storageKey=; path=/; max-age=0';
    } catch (_) {
      // Storage unavailable
    }
  }
}
