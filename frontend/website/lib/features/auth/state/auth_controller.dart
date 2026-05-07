import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/auth_models.dart';
import '../data/auth_repository.dart';

final authControllerProvider =
    AsyncNotifierProvider<AuthController, AuthSession?>(AuthController.new);

class AuthController extends AsyncNotifier<AuthSession?> {
  @override
  Future<AuthSession?> build() async {
    return null;
  }

  Future<void> login({
    required String email,
    required String password,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard<AuthSession?>(() async {
      return ref.read(authRepositoryProvider).login(
            email: email,
            password: password,
          );
    });
  }

  Future<void> signup({
    required String email,
    required String password,
    required String fullName,
    required String phone,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard<AuthSession?>(() async {
      return ref.read(authRepositoryProvider).signup(
            email: email,
            password: password,
            fullName: fullName,
            phone: phone,
          );
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
    state = const AsyncData(null);
  }
}
