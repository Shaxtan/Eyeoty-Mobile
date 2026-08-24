/// Centralised runtime configuration.
///
/// Values can be overridden at build/run time via --dart-define, e.g.:
///   flutter run -d chrome --dart-define=API_BASE_URL=https://tech-hop.com/api
///
/// The default below matches the base URL used by the existing Eyeoty
/// web application (src/services/apiService.js in the React project,
/// confirmed earlier in this project's history).
class Env {
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://tech-hop.com/api',
  );

  /// Named to match the localStorage key ('auspre-token') used by the
  /// existing web app. The two apps do NOT share storage — each
  /// platform has its own secure storage — the name is kept consistent
  /// purely so anyone cross-referencing the two codebases recognises it.
  static const String authTokenStorageKey = 'auspre-token';
}
