class AppConfig {
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',


    defaultValue: 'http://localhost:8000/api/v1',

  );

  static const googleClientId = String.fromEnvironment(
    'GOOGLE_CLIENT_ID',
    defaultValue: '',
  );
}
