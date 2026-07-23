import 'package:alpha_app/core/utils/step_resolver.dart';
import 'package:alpha_app/providers/onboarding_provider.dart';
import 'package:alpha_app/providers/profile_provider.dart';
import 'package:alpha_app/providers/home_provider.dart';
import 'package:alpha_app/providers/cycle_provider.dart';
import 'package:alpha_app/screens/ai_assistant/chat_screen.dart';
import 'package:alpha_app/screens/auth/otp_screen.dart';
import 'package:alpha_app/screens/expenses/expenses_screen.dart';
import 'package:alpha_app/screens/goals/goal_history.dart';
import 'package:alpha_app/screens/home/home_screen.dart';
import 'package:alpha_app/screens/profile/profile_screen.dart';
import 'package:alpha_app/providers/auth_provider.dart';
import 'dart:io';
import 'package:alpha_app/widgets/custom_nav_bar.dart';
import 'package:alpha_app/screens/receipts/receipt_input_screen.dart';
import 'package:alpha_app/core/utils/onboarding_guard.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';

class MainNavigationScreen extends StatefulWidget {
  final int initialIndex;

  const MainNavigationScreen({
    super.key,
    this.initialIndex = 0,
  });

  @override
  State<MainNavigationScreen> createState() {
    return _MainNavigationScreenState();
  }
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  late int _currentIndex;
  bool _didCheckLostData = false;

  final List<Widget> _screens = const [
    HomeScreen(),
    ExpensesScreen(),
    ChatScreen(),
    MyGoalsScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();

    _currentIndex = widget.initialIndex.clamp(0, 4);

    // Load profile and home data once after auth is confirmed
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Allow loading the dashboard framework, but restrict capabilities within it
      // if the user is not onboarded.

      if (!mounted) return;

      // Check for lost ImagePicker data (Android OS kills during camera)
      // Only do this AFTER auth and onboarding are completed
      final onboardingProvider = context.read<OnboardingProvider>();
      if (Platform.isAndroid &&
          !_didCheckLostData &&
          onboardingProvider.isOnboarded) {
        _didCheckLostData = true;
        try {
          final picker = ImagePicker();
          final response = await picker.retrieveLostData();

          if (response.exception != null && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text(
                      'Failed to recover image: ${response.exception!.message}')),
            );
          } else if (!response.isEmpty && response.file != null && mounted) {
            final cycleProvider = context.read<CycleProvider>();
            if (!cycleProvider.hasActiveCycle) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text(
                        'Start a financial cycle before adding receipts.')),
              );
              return;
            }

            final file = File(response.file!.path);
            if (await file.exists() && await file.length() > 0) {
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => ReceiptInputScreen(
                  initialImage: file,
                ),
              ));
            }
          }
        } catch (_) {}
      }

      // Data loading (profile, home) has been moved to HomeScreen's initState
      // to ensure a strict loading sequence and prevent double fetching.
    });
  }

  void _handleAccountNotVerified(BuildContext context) {
    // Get the user's phone from storage or auth provider
    final authProvider = context.read<AuthProvider>();
    final phone =
        authProvider.currentUser?['phone'] ?? authProvider.localPhoneNumber;

    if (phone.isNotEmpty && mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => OtpScreen(
            phoneNumber: phone,
            isRegistration: false,
          ),
        ),
      );
    }
  }

  void _changePage(int index) {
    if (_currentIndex == index) {
      return;
    }

    final onboardingProvider = context.read<OnboardingProvider>();
    if (!onboardingProvider.isOnboarded) {
      if (index == 1 || index == 2 || index == 3) {
        requireOnboarding(context);
        return;
      }
    }

    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: CustomBottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _changePage,
      ),
    );
  }
}
