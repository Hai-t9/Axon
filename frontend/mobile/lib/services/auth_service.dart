import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_model.dart';
import 'api_client.dart';

class AuthState {
  final bool isAuthenticated;
  final String? token;
  final UserModel? user;
  final bool isLoading;
  final String? error;

  const AuthState({
    this.isAuthenticated = false,
    this.token,
    this.user,
    this.isLoading = false,
    this.error,
  });

  AuthState copyWith({
    bool? isAuthenticated,
    String? token,
    UserModel? user,
    bool? isLoading,
    String? error,
  }) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      token: token ?? this.token,
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  factory AuthState.initial() => const AuthState();
}

class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() => AuthState.initial();

  Future<void> login(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final dio = ref.read(dioProvider);
      final response = await dio.post(
        '/api/v1/register/login',
        data: {'email': email.trim(), 'password': password},
      );
      final data = response.data as Map<String, dynamic>;
      final token = data['access_token'] as String;
      final user = UserModel.fromJson(data['user'] as Map<String, dynamic>);
      ref.read(authTokenProvider.notifier).setToken(token);
      state = AuthState(
        isAuthenticated: true,
        token: token,
        user: user,
      );
    } on DioException catch (e) {
      String msg;
      if (e.type == DioExceptionType.connectionTimeout || e.type == DioExceptionType.receiveTimeout) {
        msg = 'Connection timeout. Make sure the phone is on the same Wi-Fi as the backend.\n'
            'Backend IP: ${ApiConfig.baseUrl}';
      } else if (e.type == DioExceptionType.connectionError) {
        msg = 'Cannot reach backend at ${ApiConfig.baseUrl}.\n'
            'Check network connection and that the backend is running.';
      } else {
        msg = e.response?.data?['detail'] ?? e.message ?? 'Login failed';
      }
      state = state.copyWith(isLoading: false, error: msg);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> signup(String email, String password, String fullName, String phone) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final dio = ref.read(dioProvider);
      final response = await dio.post(
        '/api/v1/register/signup',
        data: {
          'email': email.trim(),
          'password': password,
          'full_name': fullName.trim(),
          'phone': phone.trim(),
        },
      );
      final data = response.data as Map<String, dynamic>;
      final token = data['access_token'] as String;
      final user = UserModel.fromJson(data['user'] as Map<String, dynamic>);
      ref.read(authTokenProvider.notifier).setToken(token);
      state = AuthState(
        isAuthenticated: true,
        token: token,
        user: user,
      );
    } on DioException catch (e) {
      final msg = e.response?.data?['detail'] ?? e.message ?? 'Signup failed';
      state = state.copyWith(isLoading: false, error: msg);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void logout() {
    ref.read(authTokenProvider.notifier).setToken(null);
    state = AuthState.initial();
  }

  void clearError() {
    state = state.copyWith(error: null);
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
