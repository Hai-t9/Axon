class AppConfig {
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',


    defaultValue: 'https://cautious-acorn-4j4r565rr9gwfww-8000.app.github.dev/api/v1',

  );

  static const googleClientId = String.fromEnvironment(
    'GOOGLE_CLIENT_ID',
    defaultValue: '',
  );
}
