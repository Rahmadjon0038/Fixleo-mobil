/// Central place for backend connection settings.
///
/// All API docs (see `/api/*.md`) share the same base URL and the same
/// response envelope. Keep environment-specific values here so switching
/// between staging / production is a one-line change.
class ApiConfig {
  ApiConfig._();

  /// Base URL for every request — already includes the `/api/v1` prefix, so
  /// service classes pass only the route part (e.g. `/work-radiuses`).
  /// LOCAL DEV: points at the local Docker backend (localhost:9000). For prod
  /// switch back to https://api.fixleo.com/api/v1.
  static const String baseUrl = 'http://localhost:9000/api/v1';

  /// Swagger / OpenAPI docs, handy for reference.
  static const String docsUrl = 'http://localhost:9000/api/docs';

  /// Network timeouts.
  static const Duration connectTimeout = Duration(seconds: 20);
  static const Duration receiveTimeout = Duration(seconds: 20);
}
