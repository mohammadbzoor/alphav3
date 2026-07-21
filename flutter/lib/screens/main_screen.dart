
import 'package:alpha_app/providers/profile_provider.dart';
import 'package:alpha_app/providers/home_provider.dart';
import 'package:alpha_app/screens/ai_assistant/chat_screen.dart';
import 'package:alpha_app/screens/auth/otp_screen.dart';
import 'package:alpha_app/screens/expenses/expenses_screen.dart';
import 'package:alpha_app/screens/goals/goal_history.dart';
import 'package:alpha_app/screens/home/home_screen.dart';
import 'package:alpha_app/screens/profile/profile_screen.dart';
import 'package:alpha_app/providers/auth_provider.dart';

import 'package:alpha_app/widgets/custom_nav_bar.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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

class _MainNavigationScreenState
    extends State<MainNavigationScreen> {
  late int _currentIndex;

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

    _currentIndex =
        widget.initialIndex.clamp(0, 4);

    // Load profile and home data once after auth is confirmed
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final profileProvider = context.read<ProfileProvider>();
      final homeProvider = context.read<HomeProvider>();
      
      if (!profileProvider.hasProfile && !profileProvider.isLoading) {
        profileProvider.loadProfileSummary().then((_) {
          // Check if account not verified
          if (profileProvider.errorCode == 'ACCOUNT_NOT_VERIFIED') {
            _handleAccountNotVerified(context);
          }
        });
      }
      
      // Load home data (dashboard) after profile is confirmed
      if (!homeProvider.hasData && !homeProvider.isLoading) {
        homeProvider.loadHomeData();
      }
    });
  }

  void _handleAccountNotVerified(BuildContext context) {
    // Get the user's phone from storage or auth provider
    final authProvider = context.read<AuthProvider>();
    final phone = authProvider.currentUser?['phone'] ?? authProvider.localPhoneNumber;
    
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

      bottomNavigationBar:
          CustomBottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _changePage,
      ),
    );
  }
}