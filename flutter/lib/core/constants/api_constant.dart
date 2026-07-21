import 'dart:io';

class ApiConstants {
  static const String _envUrl = String.fromEnvironment('API_URL');
  
  static String get baseUrl {
    if (_envUrl.isNotEmpty) return _envUrl;
    return Platform.isAndroid 
        ? 'http://10.0.2.2:3000/api/v1' 
        : 'http://localhost:3000/api/v1';
  }
}
