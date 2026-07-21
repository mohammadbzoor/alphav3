import 'package:alpha_app/services/api_service.dart';

class HomeService {
  // =====================================================
  // CURRENT CYCLE
  // =====================================================

  static Future<Map<String, dynamic>>
      loadCurrentCycle() async {
    try {
      final response = await ApiService.get(
        '/financial-cycles/current',
      );

      final body =
          await ApiService.parseJson(response);

      if (response.statusCode >= 200 &&
          response.statusCode < 300) {
        final data = body['data'];

        return data is Map
            ? Map<String, dynamic>.from(data)
            : <String, dynamic>{};
      }

      return <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  // =====================================================
  // BUCKET BALANCES
  // =====================================================

  static Future<List<dynamic>>
      loadBucketBalances() async {
    try {
      final response = await ApiService.get(
        '/financial-cycles/current/buckets',
      );

      final body =
          await ApiService.parseJson(response);

      if (response.statusCode >= 200 &&
          response.statusCode < 300) {
        final data = body['data'];

        return data is List
            ? List<dynamic>.from(data)
            : <dynamic>[];
      }

      return <dynamic>[];
    } catch (_) {
      return <dynamic>[];
    }
  }

  // =====================================================
  // DASHBOARD
  // =====================================================

  static Future<Map<String, dynamic>>
      loadDashboard() async {
    try {
      final response = await ApiService.get(
        '/dashboard/summary',
      );

      final body =
          await ApiService.parseJson(response);

      if (response.statusCode >= 200 &&
          response.statusCode < 300) {
        final data = body['data'];

        return data is Map
            ? Map<String, dynamic>.from(data)
            : <String, dynamic>{};
      }

      return <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  // =====================================================
  // HEALTH SCORE
  // =====================================================

  static Future<Map<String, dynamic>>
      loadHealthScore() async {
    try {
      final response = await ApiService.get(
        '/dashboard/health-score',
      );

      final body =
          await ApiService.parseJson(response);

      if (response.statusCode >= 200 &&
          response.statusCode < 300) {
        final data = body['data'];

        return data is Map
            ? Map<String, dynamic>.from(data)
            : <String, dynamic>{};
      }

      return <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  // =====================================================
  // INSIGHTS
  // =====================================================

  static Future<List<dynamic>>
      loadInsights() async {
    try {
      final response = await ApiService.get(
        '/insights',
        queryParameters: const {
          'limit': '1',
        },
      );

      final body =
          await ApiService.parseJson(response);

      if (response.statusCode < 200 ||
          response.statusCode >= 300) {
        return <dynamic>[];
      }

      final rawData = body['data'];

      if (rawData is List) {
        return List<dynamic>.from(rawData);
      }

      if (rawData is Map) {
        final nestedData =
            rawData['data'] ??
            rawData['items'] ??
            rawData['results'];

        if (nestedData is List) {
          return List<dynamic>.from(
            nestedData,
          );
        }
      }

      return <dynamic>[];
    } catch (_) {
      return <dynamic>[];
    }
  }
}