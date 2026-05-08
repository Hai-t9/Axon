import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import 'package:dio/dio.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    await Future.delayed(const Duration(milliseconds: 800));

    final box = await Hive.openBox('auth');
    final savedToken = box.get('access_token') as String?;

    if (savedToken == null) {
      _navigateTo(const LoginScreen());
      return;
    }

    ref.read(authTokenProvider.notifier).setToken(savedToken);

    try {
      final dio = Dio(BaseOptions(
        baseUrl: ApiConfig.baseUrl,
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 5),
      ));
      dio.options.headers['Authorization'] = 'Bearer $savedToken';

      final response = await dio.get('/api/v1/register/me');

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final user = UserModel.fromJson(data);
        ref.read(authProvider.notifier).restoreSession(savedToken, user);
        _navigateTo(const HomeScreen());
      } else {
        await _clearAndGoToLogin();
      }
    } catch (e) {
      if (mounted) {
        await _clearAndGoToLogin();
      }
    }
  }

  Future<void> _clearAndGoToLogin() async {
    final box = await Hive.openBox('auth');
    await box.delete('access_token');
    ref.read(authTokenProvider.notifier).setToken(null);
    if (mounted) {
      _navigateTo(const LoginScreen());
    }
  }

  void _navigateTo(Widget page) {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => page),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.agriculture,
              size: 80,
              color: Color(0xFF5F75EE),
            ),
            const SizedBox(height: 16),
            Text(
              'Axon',
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF5F75EE),
                  ),
            ),
            const SizedBox(height: 32),
            const SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: Color(0xFF5F75EE),
              ),
            ),
          ],
        ),
      ),
    );
  }
}