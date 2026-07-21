import 'dart:async';
import 'package:alpha_app/core/utils/app_colors.dart';
import 'package:alpha_app/providers/themeprovider.dart';
import 'package:alpha_app/providers/auth_provider.dart';
import 'package:alpha_app/widgets/app_button.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pinput/pinput.dart';
import 'package:provider/provider.dart';

import 'package:alpha_app/screens/main_screen.dart';
import 'package:alpha_app/screens/profile/personal_info_screen.dart';

class OtpScreen extends StatefulWidget {
  final String phoneNumber;
  final String? devOtpCode;
  final bool isRegistration;

  const OtpScreen({
    super.key,
    required this.phoneNumber,
    this.devOtpCode,
    this.isRegistration = false,
  });

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _pinController = TextEditingController();
  final _focusNode = FocusNode();
  int _secondsRemaining = 30;
  Timer? _timer;
  bool _isLoading = false;
  bool _isResending = false;
  bool _showDevCode = true;
  String? _errorMessage;
  String? _currentDevCode;

  String get _maskedPhone {
    final phone = widget.phoneNumber;
    if (phone.length <= 4) return phone;
    final lastFour = phone.substring(phone.length - 4);
    return '${phone.substring(0, 3)}${'•' * (phone.length - 7)}$lastFour';
  }

  @override
  void initState() {
    super.initState();
    _currentDevCode = widget.devOtpCode;
    _startTimer();
    // Auto-focus the OTP input
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  void _startTimer() {
    setState(() => _secondsRemaining = 30);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_secondsRemaining > 0) {
          _secondsRemaining--;
        } else {
          _timer?.cancel();
        }
      });
    });
  }

  Future<void> _verifyOtp() async {
    final otpCode =
        _pinController.text.trim();

    if (otpCode.length != 6) {
      setState(() {
        _errorMessage =
            'Please enter the full 6-digit code';
      });

      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authProvider =
          context.read<AuthProvider>();

      final success =
          await authProvider.verifyPhoneOtp(
        otpCode: otpCode,
      );

      if (!mounted) {
        return;
      }

      if (!success) {
        setState(() {
          _errorMessage =
              authProvider.errorMessage ??
                  'Verification failed';
        });

        _pinController.clear();
        _focusNode.requestFocus();

        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              widget.isRegistration
                  ? 'Account verified successfully'
                  : 'Verified successfully',
              style: GoogleFonts
                  .ibmPlexSansArabic(),
            ),
            backgroundColor:
                const Color(0xFF0F766E),
            behavior:
                SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius:
                  BorderRadius.circular(10),
            ),
          ),
        );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => widget.isRegistration
              ? const PersonalInfoScreen()
              : const MainNavigationScreen(),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = error
            .toString()
            .replaceFirst(
              'Exception: ',
              '',
            );
      });

      _pinController.clear();
      _focusNode.requestFocus();
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _resendOtp() async {
    if (_secondsRemaining > 0 ||
        _isResending) {
      return;
    }

    setState(() {
      _errorMessage =
          'Resend OTP is not available yet';
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pinController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<Themeprovider>(context);
    final isDark = themeProvider.isDark;
    final screenW = MediaQuery.of(context).size.width;

    final bgColor =
        isDark ? AppColors.darkBackground : AppColors.lightBackground;
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;
    final subTextColor =
        isDark ? AppColors.darkSubText : AppColors.lightSubText;
    final accentColor = isDark ? AppColors.darkAccent : AppColors.lightAccent;
    final primaryColor =
        isDark ? AppColors.darkPrimary : AppColors.lightPrimary;
    final cardColor = isDark ? AppColors.darkCard : AppColors.lightCard;
    final errorColor = isDark ? AppColors.darkError : AppColors.lightError;

    final pinTheme = PinTheme(
      width: 52,
      height: 60,
      textStyle: GoogleFonts.ibmPlexSansArabic(
        fontSize: 22,
        fontWeight: FontWeight.bold,
        color: textColor,
      ),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
    );

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: screenW * 0.06),
            child: Column(
              children: [
                SizedBox(height: MediaQuery.of(context).size.height * 0.06),

                // Back button
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    icon: Icon(Icons.arrow_back_ios, color: textColor),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),

                const SizedBox(height: 20),

                // Icon
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.10),
                    shape: BoxShape.circle,
                  ),
                  child:
                      Icon(Icons.mark_email_read_outlined, size: 48, color: primaryColor),
                ),

                const SizedBox(height: 32),

                // Title
                Text(
                  'Verification Code',
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: screenW * 0.07,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),

                const SizedBox(height: 12),

                // Subtitle
                Text(
                  'We sent a 6-digit verification code to your email',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: screenW * 0.04,
                    color: subTextColor,
                    height: 1.5,
                  ),
                ),

                const SizedBox(height: 32),

                // Dev mode OTP code display
                if (_currentDevCode != null && _showDevCode) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        vertical: 16, horizontal: 20),
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(12),
                      border:
                          Border.all(color: accentColor.withOpacity(0.30)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.code, size: 18, color: accentColor),
                            const SizedBox(width: 8),
                            Text(
                              'Dev Mode - Your OTP Code',
                              style: GoogleFonts.ibmPlexSansArabic(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: accentColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        GestureDetector(
                          onTap: () {
                            _pinController.text = _currentDevCode!;
                            _focusNode.requestFocus();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                vertical: 10, horizontal: 24),
                            decoration: BoxDecoration(
                              color: accentColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _currentDevCode!,
                              style: GoogleFonts.ibmPlexSansArabic(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: accentColor,
                                letterSpacing: 6,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tap to auto-fill',
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontSize: 11,
                            color: subTextColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Error message
                if (_errorMessage != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(
                      color: errorColor.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(10),
                      border:
                          Border.all(color: errorColor.withOpacity(0.30)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, size: 20, color: errorColor),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: 13,
                              color: errorColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // OTP Input
                Pinput(
                  controller: _pinController,
                  focusNode: _focusNode,
                  length: 6,
                  defaultPinTheme: pinTheme,
                  focusedPinTheme: pinTheme.copyWith(
                    decoration: pinTheme.decoration!.copyWith(
                      border: Border.all(color: primaryColor, width: 2),
                    ),
                  ),
                  errorPinTheme: pinTheme.copyWith(
                    decoration: pinTheme.decoration!.copyWith(
                      border: Border.all(color: errorColor, width: 2),
                    ),
                  ),
                  onCompleted: (_) => _verifyOtp(),
                  onChanged: (_) {
                    if (_errorMessage != null) {
                      setState(() => _errorMessage = null);
                    }
                  },
                ),

                const SizedBox(height: 24),

                // Resend section
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Didn't receive the code? ",
                      style: GoogleFonts.ibmPlexSansArabic(
                        color: subTextColor,
                        fontSize: 14,
                      ),
                    ),
                    GestureDetector(
                      onTap: _secondsRemaining == 0 && !_isResending
                          ? _resendOtp
                          : null,
                      child: Text(
                        _isResending
                            ? 'Sending...'
                            : _secondsRemaining > 0
                                ? 'Resend in 0:${_secondsRemaining.toString().padLeft(2, '0')}'
                                : 'Resend Code',
                        style: GoogleFonts.ibmPlexSansArabic(
                          color: (_secondsRemaining == 0 && !_isResending)
                              ? primaryColor
                              : subTextColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 48),

                // Verify button
                AppButton(
                  text: 'Verify',
                  isDark: isDark,
                  isLoading: _isLoading,
                  width: double.infinity,
                  height: 56,
                  onPressed: _verifyOtp,
                ),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}