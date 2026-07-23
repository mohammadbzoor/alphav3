import 'package:alpha_app/media/images.dart';
import 'package:alpha_app/core/utils/step_resolver.dart';
import 'package:alpha_app/providers/onboarding_provider.dart';
import 'package:alpha_app/providers/themeprovider.dart';
import 'package:alpha_app/screens/auth/login.dart';
import 'package:alpha_app/providers/auth_provider.dart';

import 'package:alpha_app/core/utils/app_colors.dart';
import 'package:alpha_app/core/utils/device.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  @override
  Widget build(BuildContext context) {
    final double screenW = Device.width(context);
    final double screenH = Device.height(context);
    final themeprovider = Provider.of<Themeprovider>(context);
    return Scaffold(
      backgroundColor: themeprovider.isDark
          ? AppColors.darkBackground
          : AppColors.lightBackground,
      body: Stack(
        children: [
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  ImagesAssets.logo,
                  width: screenW * 0.5,
                  height: screenH * 0.18,
                  fit: BoxFit.contain,
                ),
                SizedBox(height: screenH * 0.03),
                Text(
                  "Alpha",
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: screenW * 0.1,
                    fontWeight: FontWeight.bold,
                    color: themeprovider.isDark
                        ? AppColors.darkText
                        : AppColors.lightText,
                  ),
                ),
                SizedBox(height: screenH * 0.02),
                Text(
                  "SMART FINANCIAL ADVISOR",
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: screenW * 0.042,
                    color: themeprovider.isDark
                        ? AppColors.darkSubText
                        : AppColors.lightSubText,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.only(bottom: screenH * 0.1),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: CircularProgressIndicator(
                color: themeprovider.isDark
                    ? AppColors.darkAccent
                    : AppColors.darkAccent,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _checkAuthStatus() async {
    final authProvider = context.read<AuthProvider>();
    final onboardingProvider = context.read<OnboardingProvider>();

    // Optional delay for the splash animation
    await Future.delayed(const Duration(seconds: 3));

    if (!mounted) return;

    final hasSession = await authProvider.hasSavedSession();

    if (!hasSession) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const Login()),
      );
      return;
    }

    // Loop for retrying on network error
    bool success = false;
    while (!success && mounted) {
      success = await onboardingProvider.checkOnboardingStatus();

      if (!mounted) return;

      if (success) {
        final String? phone = authProvider.fullPhoneNumber.isNotEmpty
            ? authProvider.fullPhoneNumber
            : null;

        final navigated = replaceWithOnboardingStep(
          context,
          onboardingProvider.nextStep,
          allocation: onboardingProvider.allocation,
          phoneNumber: phone,
        );

        if (!navigated) {
          if (onboardingProvider.nextStep == 'otp_verification') {
            await _clearSavedSession();
            authProvider.clear();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text(
                        'تعذر استعادة جلسة التحقق. سجّل الدخول أو أعد طلب رمز التحقق.')),
              );
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const Login()),
              );
            }
            break;
          } else {
            // Unknown step
            await showDialog<void>(
              context: context,
              barrierDismissible: false,
              builder: (context) => AlertDialog(
                title: const Text('Error'),
                content: Text('Unknown step: ${onboardingProvider.nextStep}'),
                actions: [
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context), // Retry
                    child: const Text('إعادة المحاولة'),
                  ),
                ],
              ),
            );
            success = false; // Force loop to retry
          }
        }
      } else {
        final error = onboardingProvider.errorMessage ?? '';
        final isAuthError = error == 'UNAUTHORIZED';

        if (isAuthError) {
          await _clearSavedSession();
          authProvider.clear();
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const Login()),
            );
          }
          break; // Stop loop and stay on login
        } else {
          // Network, Server, or Unknown Error
          // Show error dialog with retry only
          await showDialog<void>(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              title: const Text('Connection Error'),
              content: const Text(
                  'تعذر الاتصال بالخادم.\nتحقق من الإنترنت وحاول مرة أخرى.'),
              actions: [
                ElevatedButton(
                  onPressed: () => Navigator.pop(context), // Retry
                  child: const Text('إعادة المحاولة'),
                ),
              ],
            ),
          );
          // Will loop again since success is false
        }
      }
    }
  }

  Future<void> _clearSavedSession() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove('access_token');
    await preferences.remove('refresh_token');
    await preferences.remove('token');
    await preferences.remove('remember_me');
    await preferences.remove('saved_phone');
  }
}
