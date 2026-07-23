import 'package:alpha_app/core/utils/app_colors.dart';
import 'package:alpha_app/providers/auth_provider.dart';
import 'package:alpha_app/providers/themeprovider.dart';
import 'package:alpha_app/screens/auth/reset_password_screen.dart';
import 'package:alpha_app/widgets/app_button.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pinput/pinput.dart';
import 'package:provider/provider.dart';

class ForgetPasswordOtpScreen extends StatelessWidget {
  final String email;

  const ForgetPasswordOtpScreen({super.key, required this.email});

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;
    final themeprovider = Provider.of<Themeprovider>(context);
    final isDark = themeprovider.isDark;
    final authProvider = Provider.of<AuthProvider>(context);

    final defaultPinTheme = PinTheme(
      width: 56,
      height: 56,
      textStyle: GoogleFonts.ibmPlexSansArabic(
        fontSize: 20,
        color: isDark ? AppColors.darkText : AppColors.lightText,
        fontWeight: FontWeight.w600,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
        borderRadius: BorderRadius.circular(16),
      ),
    );

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios,
              color: isDark ? AppColors.darkText : AppColors.lightText),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: screenH * 0.05),
              Text(
                'Verify Code',
                style: GoogleFonts.ibmPlexSansArabic(
                  color: isDark ? AppColors.darkText : AppColors.lightText,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Please enter the 6-digit code sent to $email',
                style: GoogleFonts.ibmPlexSansArabic(
                  color:
                      isDark ? AppColors.darkSubText : AppColors.lightSubText,
                  fontSize: 16,
                ),
              ),
              SizedBox(height: screenH * 0.05),
              Center(
                child: Pinput(
                  length: 6,
                  controller: authProvider.otpController,
                  defaultPinTheme: defaultPinTheme,
                  focusedPinTheme: defaultPinTheme.copyDecorationWith(
                    border: Border.all(
                        color: isDark
                            ? AppColors.darkPrimary
                            : AppColors.lightPrimary,
                        width: 2),
                  ),
                  submittedPinTheme: defaultPinTheme,
                  showCursor: true,
                  onCompleted: (pin) async {
                    if (authProvider.isLoading) return;
                    final success = await authProvider.verifyPasswordResetOtp(
                      otpCode: pin,
                    );
                    if (success && context.mounted) {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              ResetPasswordScreen(email: email, otpCode: pin),
                        ),
                      );
                    }
                  },
                ),
              ),
              if (authProvider.errorMessage != null) ...[
                const SizedBox(height: 20),
                Center(
                  child: Text(
                    authProvider.errorMessage!,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
              SizedBox(height: screenH * 0.05),
              SizedBox(
                width: double.infinity,
                child: AppButton(
                  text: 'Verify',
                  isDark: isDark,
                  onPressed: authProvider.isLoading
                      ? () {}
                      : () async {
                          final success =
                              await authProvider.verifyPasswordResetOtp(
                            otpCode: authProvider.otpController.text,
                          );
                          if (success && context.mounted) {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ResetPasswordScreen(
                                  email: email,
                                  otpCode: authProvider.otpController.text,
                                ),
                              ),
                            );
                          }
                        },
                  isLoading: authProvider.isLoading,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
