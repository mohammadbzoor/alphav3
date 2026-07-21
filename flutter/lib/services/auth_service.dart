import 'package:alpha_app/services/api_exception.dart';
import 'package:alpha_app/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  // =====================================================
  // REGISTER
  // Backend expects:
  // fullName, phone, email, birthDate, password
  // =====================================================

  static Future<Map<String, dynamic>> register({
    required String fullName,
    required String phone,
    required String email,
    required String birthDate,
    required String password,
  }) async {
    final response = await ApiService.post(
      '/auth/register',
      body: {
        'fullName': fullName.trim(),
        'phone': phone.trim(),
        'email': email.trim(),
        'birthDate': birthDate,
        'password': password,
      },
      skipRetry: true,
    );

    return _handleResponse(
      response,
      fallbackMessage: 'Registration failed',
    );
  }

  // =====================================================
  // VERIFY REGISTRATION OTP
  // Backend expects: phoneNumber, otpCode
  // Returns user + tokens
  // =====================================================

  static Future<Map<String, dynamic>> verifyPhone({
    required String phoneNumber,
    required String otpCode,
  }) async {
    final response = await ApiService.post(
      '/auth/verify-phone',
      body: {
        'phoneNumber': phoneNumber.trim(),
        'otpCode': otpCode.trim(),
      },
      skipRetry: true,
    );

    final body = await _handleResponse(
      response,
      fallbackMessage: 'Verification failed',
    );

    await _saveTokensFromResponse(body);

    return body;
  }

  // =====================================================
  // LOGIN
  // Backend expects: phoneNumber, password
  // Returns user + tokens
  // =====================================================

  static Future<Map<String, dynamic>> login({
    required String phoneNumber,
    required String password,
  }) async {
    final response = await ApiService.post(
      '/auth/login',
      body: {
        'phoneNumber': phoneNumber.trim(),
        'password': password,
      },
      skipRetry: true,
    );

    final body = await _handleResponse(
      response,
      fallbackMessage: 'Login failed',
    );

    await _saveTokensFromResponse(body);

    return body;
  }

  // =====================================================
  // FORGOT PASSWORD
  // Backend expects: email
  // =====================================================

  static Future<Map<String, dynamic>> forgotPassword({
    required String email,
  }) async {
    final response = await ApiService.post(
      '/auth/forgot-password',
      body: {
        'email': email.trim(),
      },
      skipRetry: true,
    );

    return _handleResponse(
      response,
      fallbackMessage: 'Failed to send password reset code',
    );
  }

  // =====================================================
  // VERIFY RESET OTP
  // Backend expects: email, otpCode
  // =====================================================

  static Future<Map<String, dynamic>> verifyResetOtp({
    required String email,
    required String otpCode,
  }) async {
    final response = await ApiService.post(
      '/auth/verify-reset-otp',
      body: {
        'email': email.trim(),
        'otpCode': otpCode.trim(),
      },
      skipRetry: true,
    );

    return _handleResponse(
      response,
      fallbackMessage: 'Invalid reset code',
    );
  }

  // =====================================================
  // RESET PASSWORD
  // Backend expects: email, otpCode, newPassword
  // =====================================================

  static Future<Map<String, dynamic>> resetPassword({
    required String email,
    required String otpCode,
    required String newPassword,
  }) async {
    final response = await ApiService.post(
      '/auth/reset-password',
      body: {
        'email': email.trim(),
        'otpCode': otpCode.trim(),
        'newPassword': newPassword,
      },
      skipRetry: true,
    );

    return _handleResponse(
      response,
      fallbackMessage: 'Failed to reset password',
    );
  }

  // =====================================================
  // REFRESH TOKEN
  // Backend expects: refreshToken
  // =====================================================

  static Future<Map<String, dynamic>> refreshToken() async {
    final preferences =
        await SharedPreferences.getInstance();

    final savedRefreshToken =
        preferences.getString('refresh_token');

    if (savedRefreshToken == null ||
        savedRefreshToken.isEmpty) {
      throw const ApiException(
        message: 'No refresh token available',
        code: 'NO_REFRESH_TOKEN',
      );
    }

    final response = await ApiService.post(
      '/auth/refresh-token',
      body: {
        'refreshToken': savedRefreshToken,
      },
      skipRetry: true,
    );

    final body = await _handleResponse(
      response,
      fallbackMessage: 'Token refresh failed',
    );

    await _saveTokensFromResponse(body);

    return body;
  }

  // =====================================================
  // LOCAL LOGOUT
  // Add a server request here only if your controller
  // actually exposes POST /auth/logout.
  // =====================================================

  static Future<void> logout() async {
    try {
      final response = await ApiService.post(
        '/auth/logout',
        body: const {},
        skipRetry: true,
      );

      await _handleResponse(
        response,
        fallbackMessage: 'Logout failed',
      );
    } catch (_) {
      // Clear the local session even if the server request fails.
    } finally {
      final preferences =
          await SharedPreferences.getInstance();

      await preferences.remove('access_token');
      await preferences.remove('refresh_token');
      await preferences.remove('token');
      await preferences.remove('remember_me');
      await preferences.remove('saved_phone');
    }
  }

  // =====================================================
  // RESPONSE HANDLING
  // =====================================================

  static Future<Map<String, dynamic>> _handleResponse(
    dynamic response, {
    required String fallbackMessage,
  }) async {
    final Map<String, dynamic> body;

    try {
      body = await ApiService.parseJson(response);
    } catch (_) {
      throw const ApiException(
        message: 'The server returned an invalid response',
        code: 'INVALID_RESPONSE',
      );
    }

    if (response.statusCode >= 200 &&
        response.statusCode < 300) {
      return body;
    }

    final rawError = body['error'];

    final Map<String, dynamic>? error =
        rawError is Map
            ? Map<String, dynamic>.from(rawError)
            : null;

    final rawDetails = error?['details'];

    final Map<String, dynamic>? details =
        rawDetails is Map
            ? Map<String, dynamic>.from(rawDetails)
            : null;

    String message =
        error?['message']?.toString() ??
        body['message']?.toString() ??
        fallbackMessage;

    final rawErrors = details?['errors'];

    if (rawErrors is List && rawErrors.isNotEmpty) {
      final firstError = rawErrors.first;

      if (firstError is Map) {
        final field =
            firstError['field']?.toString();
        final fieldMessage =
            firstError['message']?.toString();

        if (fieldMessage != null &&
            fieldMessage.isNotEmpty) {
          message = field == null ||
                  field.isEmpty
              ? fieldMessage
              : '$field: $fieldMessage';
        }
      }
    }

    throw ApiException(
      message: message,
      code: error?['code']?.toString(),
      details: details,
    );
  }

  // =====================================================
  // TOKEN STORAGE
  // =====================================================

  static Future<void> _saveTokensFromResponse(
    Map<String, dynamic> body,
  ) async {
    final rawData = body['data'];

    final Map<String, dynamic>? data =
        rawData is Map
            ? Map<String, dynamic>.from(rawData)
            : null;

    final rawTokens = data?['tokens'];

    final Map<String, dynamic>? tokens =
        rawTokens is Map
            ? Map<String, dynamic>.from(rawTokens)
            : null;

    final accessToken =
        tokens?['accessToken']?.toString() ??
        data?['accessToken']?.toString() ??
        data?['access_token']?.toString();

    final refreshToken =
        tokens?['refreshToken']?.toString() ??
        data?['refreshToken']?.toString() ??
        data?['refresh_token']?.toString();

    if (accessToken == null ||
        accessToken.isEmpty) {
      return;
    }

    final preferences =
        await SharedPreferences.getInstance();

    await preferences.setString(
      'access_token',
      accessToken,
    );

    await preferences.setString(
      'token',
      accessToken,
    );

    if (refreshToken != null &&
        refreshToken.isNotEmpty) {
      await preferences.setString(
        'refresh_token',
        refreshToken,
      );
    }
  }
}
