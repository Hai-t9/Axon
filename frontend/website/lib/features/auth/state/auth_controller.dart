import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/auth_models.dart';
import '../data/auth_repository.dart';

const _storageKey = 'auth_session';

final authControllerProvider =
    AsyncNotifierProvider<AuthController, AuthSession?>(AuthController.new);

final navigateToVerifyProvider = StateProvider<String?>((ref) => null);

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
      await _save(session);
      return session;
    });
  }

  Future<void> signup({
    required String email,
    required String password,
    required String fullName,
  }) async {
    state = const AsyncLoading();
    try {
      final response = await ref.read(authRepositoryProvider).signup(
            email: email,
            password: password,
            fullName: fullName,
          );
      ref.read(navigateToVerifyProvider.notifier).state = response.email;
      state = const AsyncData(null);
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
    }
  }

  Future<void> resendVerification(String email) async {
    await ref.read(authRepositoryProvider).resendVerification(email);
  }

  Future<void> signOut() async {
    await _clear();
    state = const AsyncData(null);
  }

  Future<void> _save(AuthSession session) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = jsonEncode({
        'access_token': session.accessToken,
        'user': {
          'id': session.user.id,
          'fullname': session.user.fullname,
          'email': session.user.email,
        },
      });
      await prefs.setString(_storageKey, data);
    } catch (_) {
      // Storage unavailable
    }
  }

  Future<AuthSession?> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(_storageKey);
      if (stored == null) return null;
      final data = jsonDecode(stored) as Map<String, dynamic>;
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

  Future<void> _clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storageKey);
    } catch (_) {
      // Storage unavailable
    }
  }
}
