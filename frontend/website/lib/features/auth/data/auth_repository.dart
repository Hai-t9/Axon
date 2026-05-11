import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import 'auth_models.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(apiClient: ref.watch(apiClientProvider));
});

class AuthRepository {
  AuthRepository({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

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

  Future<SignupResponse> signup({
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
    return SignupResponse.fromJson(response);
  }

  Future<Map<String, dynamic>> resendVerification(String email) async {
    return await _apiClient.postJson(
      '/register/resend-verification',
      {'email': email.trim()},
    );
  }
}
