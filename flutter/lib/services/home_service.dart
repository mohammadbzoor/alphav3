import 'package:flutter/material.dart';
import 'package:alpha_app/services/api_service.dart';

class HomeService {
  /// Load consolidated dashboard data from single backend endpoint
  static Future<Map<String, dynamic>> loadDashboard() async {
    try {
      final response = await ApiService.get(
        '/dashboard/summary',
      );

      final body = await ApiService.parseJson(response);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = body['data'];

        return data is Map
            ? Map<String, dynamic>.from(data)
            : <String, dynamic>{};
      }

      return <String, dynamic>{};
    } catch (e) {
      debugPrint('Error loading dashboard: $e');
      return <String, dynamic>{};
    }
  }
}
