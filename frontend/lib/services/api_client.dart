import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AuthNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void setToken(String token) {
    state = token;
  }
}

final authProvider = NotifierProvider<AuthNotifier, String?>(AuthNotifier.new);

class AuthInterceptor extends Interceptor {
  final Ref ref;

  AuthInterceptor(this.ref);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final token = ref.read(authProvider);
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    super.onRequest(options, handler);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    // Add logic here to catch specific status codes like 401/409
    super.onError(err, handler);
  }
}

final dioProvider = Provider<Dio>((ref) {
  // Use the physical machine's IP address on the Wi-Fi network for a physical device.
  final dio = Dio(
    BaseOptions(
      baseUrl: 'http://192.168.135.205:8000',
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      sendTimeout: const Duration(seconds: 10),
    ),
  );

  dio.interceptors.add(AuthInterceptor(ref));
  return dio;
});
