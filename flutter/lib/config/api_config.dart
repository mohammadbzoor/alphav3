enum AppEnvironment {
  local,
  production,
}

class ApiConfig {
  // Optional build-time override
  static const String _envOverride = String.fromEnvironment(
    'APP_ENV',
    defaultValue: '',
  );

  // Central static default switch
  static const AppEnvironment environment = AppEnvironment.production;

  // Derive environment respecting dart-define first, then default
  static AppEnvironment get _effectiveEnvironment {
    if (_envOverride == 'local') return AppEnvironment.local;
    if (_envOverride == 'production') return AppEnvironment.production;
    return environment;
  }

  static const String localServerUrl = 'http://192.168.1.21:3000';
  static const String productionServerUrl = 'https://alphav3-r707.onrender.com';

  static String get serverUrl {
    switch (_effectiveEnvironment) {
      case AppEnvironment.local:
        return localServerUrl;
      case AppEnvironment.production:
        return productionServerUrl;
    }
  }

  static String get apiBaseUrl => '$serverUrl/api';
  static String get apiV1BaseUrl => '$serverUrl/api/v1';
  static String get uploadsBaseUrl => '$serverUrl/uploads';

  /// Resolves an image or file path to a fully qualified backend URL safely.
  static String resolveBackendUrl(String? path) {
    if (path == null || path.isEmpty) {
      return '';
    }
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }
    if (path.startsWith('/')) {
      return '$serverUrl$path';
    }
    return '$serverUrl/$path';
  }
}
