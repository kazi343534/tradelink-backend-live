/// Single source of truth for the API endpoint (includes /api/v1).
///
/// Default: production (Render).
/// Override per-run without code changes:
///   flutter run -d chrome --dart-define=API_URL=http://localhost:8081/api/v1
class ApiConfig {
  static const String baseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'https://tradelink-2.onrender.com/api/v1',
  );
}
