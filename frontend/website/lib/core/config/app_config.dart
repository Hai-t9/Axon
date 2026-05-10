import 'package:flutter/foundation.dart';

class AppConfig {
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://stood-triangle-mangy.ngrok-free.dev/api/v1',
  );
  static String get apiBaseUrl {
    const configuredBaseUrl = String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: '',
    );

    if (configuredBaseUrl.isNotEmpty) {
      return configuredBaseUrl;
    }

    if (kIsWeb) {
      return '${Uri.base.origin}/api/v1';
    }

    return 'http://localhost:8000/api/v1';
  }

  static const googleClientId = String.fromEnvironment(
    'GOOGLE_CLIENT_ID',
    defaultValue: '',
  );
}
