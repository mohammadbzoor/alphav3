import 'package:flutter/material.dart';
import 'package:alpha_app/screens/auth/otp_screen.dart';
import 'package:alpha_app/screens/profile/onboarding_personal_info_screen.dart';
import 'package:alpha_app/screens/profile/financial_setup_screen.dart';
import 'package:alpha_app/screens/profile/allocation_review_screen.dart';
import 'package:alpha_app/screens/main_screen.dart';

bool replaceWithOnboardingStep(
  BuildContext context,
  String step, {
  dynamic allocation,
  String? phoneNumber,
  bool isRegistration = false,
}) {
  Widget nextScreen;

  switch (step) {
    case 'otp_verification':
      if (phoneNumber == null) {
        // Fallback or error state
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Missing phone number for OTP step')),
        );
        return false;
      }
      nextScreen =
          OtpScreen(phoneNumber: phoneNumber, isRegistration: isRegistration);
      break;
    case 'personal_info':
      nextScreen = const OnboardingPersonalInfoScreen();
      break;
    case 'financial_setup':
      nextScreen = const FinancialSetupScreen();
      break;
    case 'allocation_review':
      nextScreen = const AllocationReviewScreen();
      break;
    case 'dashboard':
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const MainNavigationScreen()),
        (route) => false,
      );
      return true;
    default:
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unknown onboarding step: $step')),
      );
      return false;
  }

  Navigator.pushReplacement(
    context,
    MaterialPageRoute(builder: (context) => nextScreen),
  );
  return true;
}
