import 'dart:async';
import 'package:alpha_app/config/api_config.dart';
import 'dart:convert';


import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http_parser/http_parser.dart';

class ApiService {
  static String get baseUrl => ApiConfig.apiV1BaseUrl;

  static Uri _buildUri(String path) {
    String p = path.startsWith('/') ? path : '/$path';
    if (p.startsWith('/api/v1')) {
      p = p.substring('/api/v1'.length);
    }
    // Remove duplicated slashes, e.g. //api
    p = p.replaceAll(RegExp(r'/+'), '/');
    
    // apiV1BaseUrl doesn't have trailing slash, and p always starts with / here
    return Uri.parse('$baseUrl$p');
  }

  static const Duration _timeoutDuration = Duration(seconds: 90);

  // =====================================================
  // TOKEN REFRESH STATE
  // =====================================================

  static bool _isRefreshing = false;

  static Completer<bool>? _refreshCompleter;

  // =====================================================
  // REQUEST WITH AUTOMATIC TOKEN REFRESH
  // =====================================================

  static Future<http.Response> _requestWithRetry(
    Future<http.Response> Function(
      String token,
    ) requestFunction, {
    bool skipRetry = false,
  }) async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();

    final String accessToken = preferences.getString(
          'access_token',
        ) ??
        '';

    final http.Response response = await requestFunction(
      accessToken,
    );

    if (skipRetry || !_isTokenExpired(response)) {
      return response;
    }

    final bool refreshed = await _refreshAccessToken();

    if (!refreshed) {
      return response;
    }

    final SharedPreferences updatedPreferences =
        await SharedPreferences.getInstance();

    final String updatedAccessToken = updatedPreferences.getString(
          'access_token',
        ) ??
        '';

    return requestFunction(
      updatedAccessToken,
    );
  }

  // =====================================================
  // REFRESH TOKEN HANDLING
  // =====================================================

  static Future<bool> _refreshAccessToken() async {
    if (_isRefreshing) {
      final Completer<bool>? completer = _refreshCompleter;

      if (completer == null) {
        return false;
      }

      try {
        return await completer.future;
      } catch (_) {
        return false;
      }
    }

    _isRefreshing = true;
    _refreshCompleter = Completer<bool>();

    try {
      final bool success = await _doRefreshToken();

      if (!_refreshCompleter!.isCompleted) {
        _refreshCompleter!.complete(
          success,
        );
      }

      return success;
    } catch (error) {
      if (!_refreshCompleter!.isCompleted) {
        _refreshCompleter!.complete(
          false,
        );
      }

      debugPrint(
        'REFRESH TOKEN ERROR: $error',
      );

      return false;
    } finally {
      _isRefreshing = false;
      _refreshCompleter = null;
    }
  }

  static bool _isTokenExpired(
    http.Response response,
  ) {
    if (response.statusCode != 401) {
      return false;
    }

    try {
      final dynamic decoded = jsonDecode(response.body);

      if (decoded is! Map) {
        return true;
      }

      final Map<String, dynamic> body = Map<String, dynamic>.from(
        decoded,
      );

      final dynamic rawError = body['error'];

      final Map<String, dynamic>? error = rawError is Map
          ? Map<String, dynamic>.from(
              rawError,
            )
          : null;

      final String? code =
          error?['code']?.toString() ?? body['code']?.toString();

      return code == 'TOKEN_EXPIRED' || code == 'UNAUTHORIZED';
    } catch (_) {
      return true;
    }
  }

  static Future<bool> _doRefreshToken() async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();

    final String? refreshToken = preferences.getString(
      'refresh_token',
    );

    if (refreshToken == null || refreshToken.isEmpty) {
      return false;
    }

    final Uri uri = _buildUri('/auth/refresh-token');

    debugPrint(
      'POST URL: $uri',
    );

    final http.Response response = await http
        .post(
          uri,
          headers: const {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode({
            'refreshToken': refreshToken,
          }),
        )
        .timeout(
          _timeoutDuration,
        );

    debugPrint(
      'STATUS CODE: ${response.statusCode}',
    );

    // response body redacted

    if (response.statusCode < 200 || response.statusCode >= 300) {
      return false;
    }

    final Map<String, dynamic> body = await parseJson(response);

    final dynamic rawData = body['data'];

    final Map<String, dynamic>? data = rawData is Map
        ? Map<String, dynamic>.from(
            rawData,
          )
        : null;

    final dynamic rawTokens = data?['tokens'];

    final Map<String, dynamic>? tokens = rawTokens is Map
        ? Map<String, dynamic>.from(
            rawTokens,
          )
        : null;

    final String? newAccessToken = tokens?['accessToken']?.toString();

    final String? newRefreshToken = tokens?['refreshToken']?.toString();

    if (newAccessToken == null || newAccessToken.isEmpty) {
      return false;
    }

    await preferences.setString(
      'access_token',
      newAccessToken,
    );

    await preferences.setString(
      'token',
      newAccessToken,
    );

    if (newRefreshToken != null && newRefreshToken.isNotEmpty) {
      await preferences.setString(
        'refresh_token',
        newRefreshToken,
      );
    }

    return true;
  }

  // =====================================================
  // GET
  // =====================================================

  static Future<http.Response> get(
    String path, {
    Map<String, String>? queryParameters,
    bool skipRetry = false,
  }) async {
    return _requestWithRetry(
      (String token) async {
        final Uri uri = _buildUri(path).replace(
          queryParameters: queryParameters,
        );

        debugPrint(
          'GET URL: $uri',
        );

        final http.Response response = await http
            .get(
              uri,
              headers: _headers(token),
            )
            .timeout(
              _timeoutDuration,
            );

        _logResponse(response);

        return response;
      },
      skipRetry: skipRetry,
    );
  }

  // =====================================================
  // POST
  // =====================================================

  static Future<http.Response> post(
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
    bool skipRetry = false,
  }) async {
    return _requestWithRetry(
      (String token) async {
        final Uri uri = _buildUri(path);

        final Map<String, dynamic> requestBody = body ?? <String, dynamic>{};

        debugPrint(
          'POST URL: $uri',
        );

        debugPrint('POST BODY: [REDACTED]');

        final allHeaders = _headers(token);
        if (headers != null) {
          allHeaders.addAll(headers);
        }

        final http.Response response = await http
            .post(
              uri,
              headers: allHeaders,
              body: jsonEncode(
                requestBody,
              ),
            )
            .timeout(
              _timeoutDuration,
            );

        _logResponse(response);

        return response;
      },
      skipRetry: skipRetry,
    );
  }

  // =====================================================
  // PATCH
  // =====================================================

  static Future<http.Response> patch(
    String path, {
    Map<String, dynamic>? body,
    bool skipRetry = false,
  }) async {
    return _requestWithRetry(
      (String token) async {
        final Uri uri = _buildUri(path);

        final Map<String, dynamic> requestBody = body ?? <String, dynamic>{};

        debugPrint(
          'PATCH URL: $uri',
        );

        debugPrint('PATCH BODY: [REDACTED]');

        final http.Response response = await http
            .patch(
              uri,
              headers: _headers(token),
              body: jsonEncode(
                requestBody,
              ),
            )
            .timeout(
              _timeoutDuration,
            );

        _logResponse(response);

        return response;
      },
      skipRetry: skipRetry,
    );
  }

  // =====================================================
  // PUT
  // =====================================================

  static Future<http.Response> put(
    String path, {
    Map<String, dynamic>? body,
    bool skipRetry = false,
  }) async {
    return _requestWithRetry(
      (String token) async {
        final Uri uri = _buildUri(path);

        final Map<String, dynamic> requestBody = body ?? <String, dynamic>{};

        debugPrint(
          'PUT URL: $uri',
        );

        debugPrint('PUT BODY: [REDACTED]');

        final http.Response response = await http
            .put(
              uri,
              headers: _headers(token),
              body: jsonEncode(
                requestBody,
              ),
            )
            .timeout(
              _timeoutDuration,
            );

        _logResponse(response);

        return response;
      },
      skipRetry: skipRetry,
    );
  }

  // =====================================================
  // DELETE
  // =====================================================

  static Future<http.Response> delete(
    String path, {
    Map<String, dynamic>? body,
    bool skipRetry = false,
  }) async {
    return _requestWithRetry(
      (String token) async {
        final Uri uri = _buildUri(path);

        debugPrint(
          'DELETE URL: $uri',
        );

        if (body != null) {
          debugPrint('DELETE BODY: [REDACTED]');
        }

        final http.Request request = http.Request(
          'DELETE',
          uri,
        );

        request.headers.addAll(
          _headers(token),
        );

        if (body != null) {
          request.body = jsonEncode(body);
        }

        final http.StreamedResponse streamedResponse =
            await request.send().timeout(
                  _timeoutDuration,
                );

        final http.Response response = await http.Response.fromStream(
          streamedResponse,
        );

        _logResponse(response);

        return response;
      },
      skipRetry: skipRetry,
    );
  }

  // =====================================================
  // MULTIPART UPLOAD
  // =====================================================

  static Future<http.Response> uploadFile(
    String endpoint, {
    required String fileField,
    required String filePath,
    Map<String, String>? fields,
    MediaType? contentType,
    bool skipRetry = false,
  }) async {
    return _requestWithRetry(
      (String token) async {
        final Uri uri = _buildUri(endpoint);

        debugPrint('UPLOAD URL: $uri');

        final http.MultipartRequest request =
            http.MultipartRequest('POST', uri);

        // Add headers but remove Content-Type as multipart request sets its own boundary
        final headers = _headers(token);
        headers.remove('Content-Type');
        request.headers.addAll(headers);

        if (fields != null) {
          request.fields.addAll(fields);
        }

        final file = await http.MultipartFile.fromPath(
          fileField,
          filePath,
          contentType: contentType,
        );

        if (endpoint.contains('voice')) {
          debugPrint('VOICE fileExtension=.${filePath.split('.').last}');
          debugPrint('VOICE inferredMimeType=${file.contentType?.mimeType}');
          debugPrint(
              'VOICE multipartContentType=${file.contentType?.mimeType}');
          debugPrint('VOICE fileSize=${file.length}');
        }

        request.files.add(file);

        final http.StreamedResponse streamedResponse =
            await request.send().timeout(_timeoutDuration);

        final http.Response response =
            await http.Response.fromStream(streamedResponse);

        _logResponse(response);

        return response;
      },
      skipRetry: skipRetry,
    );
  }

  // =====================================================
  // PARSE JSON
  // =====================================================

  static Future<Map<String, dynamic>> parseJson(
    http.Response response,
  ) async {
    if (response.body.trim().isEmpty) {
      return <String, dynamic>{};
    }

    final dynamic decoded = jsonDecode(response.body);

    if (decoded is Map) {
      return Map<String, dynamic>.from(
        decoded,
      );
    }

    return <String, dynamic>{
      'data': decoded,
    };
  }

  static bool isSuccess(
    http.Response response,
  ) {
    return response.statusCode >= 200 && response.statusCode < 300;
  }

  static Map<String, dynamic> decodeResponse(
    http.Response response,
  ) {
    if (response.body.trim().isEmpty) {
      return <String, dynamic>{};
    }

    final dynamic decoded = jsonDecode(response.body);

    if (decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }

    return <String, dynamic>{
      'data': decoded,
    };
  }

  // =====================================================
  // RESPONSE ERROR MESSAGE
  // =====================================================

  static Future<String> getErrorMessage(
    http.Response response, {
    String fallback = 'Something went wrong',
  }) async {
    try {
      final Map<String, dynamic> body = await parseJson(response);

      final dynamic rawError = body['error'];

      if (rawError is Map && rawError['message'] != null) {
        return rawError['message'].toString();
      }

      if (body['message'] != null) {
        return body['message'].toString();
      }

      return '$fallback (${response.statusCode})';
    } catch (_) {
      return '$fallback (${response.statusCode})';
    }
  }

  // =====================================================
  // HEADERS
  // =====================================================

  static Map<String, String> _headers(
    String token,
  ) {
    return <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  // =====================================================
  // LOG RESPONSE
  // =====================================================

  static void _logResponse(
    http.Response response,
  ) {
    debugPrint(
      'STATUS CODE: ${response.statusCode}',
    );

    // response body redacted
  }
}
