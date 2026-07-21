import 'dart:io';

class ApiConstants {
  static String get baseUrl => Platform.isAndroid 
      ? 'http://10.0.2.2:3000/api/v1' 
      : 'http://localhost:3000/api/v1';
}
