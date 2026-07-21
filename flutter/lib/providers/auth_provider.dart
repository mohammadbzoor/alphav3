import 'package:alpha_app/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:alpha_app/services/api_exception.dart';

class AuthProvider extends ChangeNotifier {
  // =====================================================
  // CONTROLLERS
  // =====================================================

  final TextEditingController nameController =
      TextEditingController();

  final TextEditingController phoneController =
      TextEditingController();

  final TextEditingController emailController =
      TextEditingController();

  final TextEditingController passwordController =
      TextEditingController();

  final TextEditingController birthDateController =
      TextEditingController();

  final TextEditingController otpController =
      TextEditingController();

  final TextEditingController newPasswordController =
      TextEditingController();

  // =====================================================
  // STATE
  // =====================================================

  DateTime? birthDate;

  bool isLoading = false;
  bool rememberMe = false;
  bool registrationCreated = false;

  String? errorMessage;

  Map<String, dynamic>? currentUser;

  // =====================================================
  // CLEAN VALUES
  // =====================================================

  String get fullName =>
      nameController.text.trim();

  String get localPhoneNumber =>
      phoneController.text.trim();

  String get fullPhoneNumber {
    final phone = localPhoneNumber;

    if (phone.startsWith('+962')) {
      return phone;
    }

    if (phone.startsWith('07')) {
      return '+962${phone.substring(1)}';
    }

    return '+962$phone';
  }

  String get email =>
      emailController.text.trim();

  String get password =>
      passwordController.text;

  String get birthDateIso {
    final date = birthDate;

    if (date == null) {
      return '';
    }

    return '${date.year}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  // =====================================================
  // BIRTH DATE
  // =====================================================

  void setBirthDate(DateTime date) {
    birthDate = date;

    birthDateController.text =
        birthDateIso;

    notifyListeners();
  }

  // =====================================================
  // GENERAL SETTERS
  // =====================================================

  void toggleRemember() {
    rememberMe = !rememberMe;
    notifyListeners();
  }

  void clearError() {
    errorMessage = null;
    notifyListeners();
  }

  // =====================================================
  // CREATE ACCOUNT
  // /auth/register creates user and sends OTP.
  // =====================================================

  Future<bool> createAccountAndSendOtp() async {
    if (isLoading) {
      return false;
    }

    final validationError =
        validateRegistrationData();

    if (validationError != null) {
      errorMessage = validationError;
      notifyListeners();

      return false;
    }

    isLoading = true;
    errorMessage = null;
    registrationCreated = false;
    notifyListeners();

    try {
      final response =
          await AuthService.register(
        fullName: fullName,
        phone: fullPhoneNumber,
        email: email,
        birthDate: birthDateIso,
        password: password,
      );

      debugPrint(
        'REGISTER RESPONSE: $response',
      );

      final rawData = response['data'];

      if (rawData is Map) {
        currentUser =
            Map<String, dynamic>.from(rawData);
      }

      registrationCreated = true;

      return true;
    } catch (error) {
      errorMessage =
          _cleanError(error);

      debugPrint(
        'REGISTER ERROR: $error',
      );

      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  // =====================================================
  // VERIFY REGISTRATION OTP
  // Do not call register again here.
  // =====================================================

  Future<bool> verifyPhoneOtp({
    required String otpCode,
  }) async {
    if (isLoading) {
      return false;
    }

    final cleanOtp =
        otpCode.trim();

    if (cleanOtp.length != 6 ||
        !RegExp(r'^\d{6}$')
            .hasMatch(cleanOtp)) {
      errorMessage =
          'Please enter a valid 6-digit verification code';

      notifyListeners();

      return false;
    }

    if (!_isValidPhone(localPhoneNumber)) {
      errorMessage =
          'Enter a valid phone number';

      notifyListeners();

      return false;
    }

    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final response =
          await AuthService.verifyPhone(
        phoneNumber: fullPhoneNumber,
        otpCode: cleanOtp,
      );

      debugPrint(
        'VERIFY OTP RESPONSE: $response',
      );

      final rawData = response['data'];

      if (rawData is Map) {
        final data =
            Map<String, dynamic>.from(rawData);

        final rawUser = data['user'];

        if (rawUser is Map) {
          currentUser =
              Map<String, dynamic>.from(
            rawUser,
          );
        }
      }

      registrationCreated = false;
      otpController.clear();

      return true;
    } catch (error) {
      errorMessage =
          _cleanError(error);

      debugPrint(
        'VERIFY OTP ERROR: $error',
      );

      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  // =====================================================
  // LOGIN
  // =====================================================

  Future<bool> loginUser() async {
    if (isLoading) {
      return false;
    }

    if (!_isValidPhone(localPhoneNumber)) {
      errorMessage =
          'Enter a valid phone number';

      notifyListeners();

      return false;
    }

    if (password.isEmpty) {
      errorMessage =
          'Password is required';

      notifyListeners();

      return false;
    }

    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final response =
          await AuthService.login(
        phoneNumber: fullPhoneNumber,
        password: password,
      );

      debugPrint(
        'LOGIN RESPONSE: $response',
      );

      final rawData = response['data'];

      if (rawData is Map) {
        final data =
            Map<String, dynamic>.from(rawData);

        final rawUser = data['user'];

        if (rawUser is Map) {
          currentUser =
              Map<String, dynamic>.from(
            rawUser,
          );
        }
      }

      final preferences =
          await SharedPreferences.getInstance();

      await preferences.setBool(
        'remember_me',
        rememberMe,
      );

      if (rememberMe) {
        await preferences.setString(
          'saved_phone',
          localPhoneNumber,
        );
      } else {
        await preferences.remove(
          'saved_phone',
        );
      }

      return true;
    } catch (error) {
      errorMessage =
          _cleanError(error);

      debugPrint(
        'LOGIN ERROR: $error',
      );

      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  // =====================================================
  // FORGOT PASSWORD
  // =====================================================

  Future<bool> sendPasswordResetOtp() async {
    if (isLoading) {
      return false;
    }

    if (!_isValidEmail(email)) {
      errorMessage =
          'Enter a valid email';

      notifyListeners();

      return false;
    }

    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final response =
          await AuthService.forgotPassword(
        email: email,
      );

      debugPrint(
        'FORGOT PASSWORD RESPONSE: $response',
      );

      return true;
    } catch (error) {
      errorMessage =
          _cleanError(error);

      debugPrint(
        'FORGOT PASSWORD ERROR: $error',
      );

      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> verifyPasswordResetOtp({
    required String otpCode,
  }) async {
    if (isLoading) {
      return false;
    }

    final cleanOtp =
        otpCode.trim();

    if (cleanOtp.length != 6 ||
        !RegExp(r'^\d{6}$')
            .hasMatch(cleanOtp)) {
      errorMessage =
          'Please enter a valid 6-digit code';

      notifyListeners();

      return false;
    }

    if (!_isValidEmail(email)) {
      errorMessage =
          'Enter a valid email';

      notifyListeners();

      return false;
    }

    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final response =
          await AuthService.verifyResetOtp(
        email: email,
        otpCode: cleanOtp,
      );

      debugPrint(
        'VERIFY RESET OTP RESPONSE: $response',
      );

      otpController.text = cleanOtp;

      return true;
    } catch (error) {
      errorMessage =
          _cleanError(error);

      debugPrint(
        'VERIFY RESET OTP ERROR: $error',
      );

      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> resetPassword({
    required String otpCode,
    required String newPassword,
  }) async {
    if (isLoading) {
      return false;
    }

    final cleanOtp =
        otpCode.trim();

    if (!_isValidEmail(email)) {
      errorMessage =
          'Enter a valid email';

      notifyListeners();

      return false;
    }

    if (cleanOtp.length != 6 ||
        !RegExp(r'^\d{6}$')
            .hasMatch(cleanOtp)) {
      errorMessage =
          'Please enter a valid 6-digit code';

      notifyListeners();

      return false;
    }

    final passwordError =
        _validatePassword(newPassword);

    if (passwordError != null) {
      errorMessage = passwordError;
      notifyListeners();

      return false;
    }

    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final response =
          await AuthService.resetPassword(
        email: email,
        otpCode: cleanOtp,
        newPassword: newPassword,
      );

      debugPrint(
        'RESET PASSWORD RESPONSE: $response',
      );

      otpController.clear();
      newPasswordController.clear();

      return true;
    } catch (error) {
      errorMessage =
          _cleanError(error);

      debugPrint(
        'RESET PASSWORD ERROR: $error',
      );

      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  // =====================================================
  // REFRESH TOKEN
  // =====================================================

  Future<bool> refreshSession() async {
    if (isLoading) {
      return false;
    }

    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      await AuthService.refreshToken();
      return true;
    } catch (error) {
      errorMessage =
          _cleanError(error);

      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  // =====================================================
  // REGISTRATION VALIDATION
  // =====================================================

  String? validateRegistrationData() {
    if (fullName.isEmpty) {
      return 'Full name is required';
    }

    if (fullName.length < 3) {
      return 'Enter a valid full name';
    }

    if (!_isValidPhone(localPhoneNumber)) {
      return 'Enter a valid phone number';
    }

    if (!_isValidEmail(email)) {
      return 'Enter a valid email';
    }

    if (birthDate == null) {
      return 'Date of birth is required';
    }

    return _validatePassword(password);
  }

  // =====================================================
  // REMEMBERED USER / SESSION
  // =====================================================

  Future<void> loadRememberedUser() async {
    final preferences =
        await SharedPreferences.getInstance();

    rememberMe =
        preferences.getBool(
          'remember_me',
        ) ??
        false;

    if (rememberMe) {
      phoneController.text =
          preferences.getString(
            'saved_phone',
          ) ??
          '';
    }

    notifyListeners();
  }

  Future<bool> hasSavedSession() async {
    final preferences =
        await SharedPreferences.getInstance();

    final token =
        preferences.getString(
          'access_token',
        );

    return token != null &&
        token.isNotEmpty;
  }

  // =====================================================
  // LOGOUT
  // =====================================================

  Future<void> logout() async {
    await AuthService.logout();
    clear();
  }

  // =====================================================
  // CLEAR
  // =====================================================

  void clear() {
    nameController.clear();
    phoneController.clear();
    emailController.clear();
    passwordController.clear();
    birthDateController.clear();
    otpController.clear();
    newPasswordController.clear();

    birthDate = null;

    isLoading = false;
    rememberMe = false;
    registrationCreated = false;
    errorMessage = null;
    currentUser = null;

    notifyListeners();
  }

  // =====================================================
  // HELPERS
  // =====================================================

  bool _isValidPhone(String value) {
    final phone = value.trim();

    if (phone.startsWith('+962')) {
      return RegExp(
        r'^\+9627[789]\d{7}$',
      ).hasMatch(phone);
    }

    if (phone.startsWith('07')) {
      return RegExp(
        r'^07[789]\d{7}$',
      ).hasMatch(phone);
    }

    return RegExp(
      r'^7[789]\d{7}$',
    ).hasMatch(phone);
  }

  bool _isValidEmail(String value) {
    return RegExp(
      r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
    ).hasMatch(value.trim());
  }

  String? _validatePassword(
    String value,
  ) {
    if (value.isEmpty) {
      return 'Password is required';
    }

    if (value.length < 8) {
      return 'Password must be at least 8 characters';
    }

    if (!RegExp(r'[a-z]')
        .hasMatch(value)) {
      return 'Password must contain a lowercase letter';
    }

    if (!RegExp(r'[A-Z]')
        .hasMatch(value)) {
      return 'Password must contain an uppercase letter';
    }

    if (!RegExp(r'\d')
        .hasMatch(value)) {
      return 'Password must contain a number';
    }

    return null;
  }

  String _cleanError(Object error) {
    if (error is ApiException) {
      switch (error.code) {
        case 'USER_NOT_FOUND':
        case 'INVALID_PHONE_OR_EMAIL':
          // We don't leak account existence on forgot password, but this handles login etc.
          return 'Invalid credentials or account not found';
        case 'OTP_EXPIRED':
          return 'The verification code has expired. Please request a new one.';
        case 'INVALID_OTP':
          return 'The verification code is incorrect. Please try again.';
        case 'OTP_ALREADY_USED':
          return 'This verification code has already been used.';
        case 'PASSWORD_MISMATCH':
          return 'Passwords do not match.';
        case 'RATE_LIMITED':
          return 'Too many attempts. Please try again later.';
        default:
          return error.message;
      }
    }
    
    final errStr = error.toString();
    if (errStr.contains('SocketException') || errStr.contains('TimeoutException')) {
      return 'Network timeout. Please check your internet connection.';
    }
    
    if (errStr.contains('500')) {
      return 'An internal server error occurred. Please try again later.';
    }

    return errStr.replaceFirst('Exception: ', '');
  }

  // =====================================================
  // DISPOSE
  // =====================================================

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    emailController.dispose();
    passwordController.dispose();
    birthDateController.dispose();
    otpController.dispose();
    newPasswordController.dispose();

    super.dispose();
  }
}
