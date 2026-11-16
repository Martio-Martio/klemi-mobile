/// Base URL de l'API Klemi. Configurable par environnement via `--dart-define`.
///
/// Exemples :
///   flutter run                                                        # dev Railway (défaut)
///   flutter run --dart-define=API_BASE_URL=https://api.klemi.ci/api    # prod
///   flutter run --dart-define=API_BASE_URL=http://localhost:7501/api   # backend local
class ApiUrl {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://teach-me-api-development.up.railway.app/api',
  );

  static const String useMockRaw = String.fromEnvironment('USE_MOCK', defaultValue: 'false');
  static bool get useMock => useMockRaw.toLowerCase() == 'true';
}
