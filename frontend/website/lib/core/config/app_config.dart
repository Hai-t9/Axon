class AppConfig {
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',


    defaultValue: 'https://obligations-guides-bradley-nottingham.trycloudflare.com/api/v1',

  );

  static const googleClientId = String.fromEnvironment(
    'GOOGLE_CLIENT_ID',
    defaultValue: '',
  );
}
