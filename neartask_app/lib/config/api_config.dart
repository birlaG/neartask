/// Point this at your backend. Use 10.0.2.2 instead of localhost when
/// running on the Android emulator; use your machine's LAN IP for a
/// physical device; use your real domain once deployed to the Contabo VPS.
class ApiConfig {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:3000',
  );
}
