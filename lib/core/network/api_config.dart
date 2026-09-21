/// Central place for backend connection settings.
///
/// All API docs (see `/api/*.md`) share the same base URL and the same
/// response envelope. Release and local builds target production by default.
/// A test build can still opt in explicitly with `--dart-define`, keeping the
/// selected REST and realtime environments aligned.
class ApiConfig {
  ApiConfig._();

  /// Base URL for every request — already includes the `/api/v1` prefix, so
  /// service classes pass only the route part (e.g. `/work-radiuses`).
  static const String baseUrl = String.fromEnvironment(
    'FIXLEO_API_BASE_URL',
    defaultValue: 'https://api.fixleo.com/api/v1',
  );

  /// Swagger / OpenAPI docs, handy for reference.
  static const String docsUrl = String.fromEnvironment(
    'FIXLEO_API_DOCS_URL',
    defaultValue: 'https://api.fixleo.com/api/docs',
  );

  /// Socket.IO namespaces live at the API origin, outside the `/api/v1`
  /// prefix. Derived from [baseUrl] so REST and realtime can never silently
  /// point at different environments.
  static String get socketBaseUrl {
    final uri = Uri.parse(baseUrl);
    return uri
        .replace(path: '', query: null, fragment: null)
        .toString()
        .replaceFirst(RegExp(r'/$'), '');
  }

  /// Backend avatar endpoints are intentionally returned as root-relative URLs.
  /// Resolve them against the same API origin so localhost keeps working with
  /// ADB reverse on real Android devices and with iOS simulators.
  static String? resolveMediaUrl(Object? value) {
    final raw = value?.toString().trim();
    if (raw == null || raw.isEmpty) return null;
    final uri = Uri.tryParse(raw);
    if (uri?.hasScheme == true) return raw;
    final base = Uri.parse(baseUrl);
    if (raw.startsWith('/') && uri != null) {
      return base
          .replace(
            path: uri.path,
            query: uri.hasQuery ? uri.query : null,
            fragment: uri.hasFragment ? uri.fragment : null,
          )
          .toString();
    }
    return Uri.parse(
      '${baseUrl.replaceFirst(RegExp(r'/+$'), '')}/$raw',
    ).toString();
  }

  /// Network timeouts.
  static const Duration connectTimeout = Duration(seconds: 20);
  static const Duration receiveTimeout = Duration(seconds: 20);
}
