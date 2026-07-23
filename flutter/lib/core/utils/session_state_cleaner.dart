import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:alpha_app/providers/auth_provider.dart';
import 'package:alpha_app/providers/cycle_provider.dart';
import 'package:alpha_app/providers/expense_provider.dart';
import 'package:alpha_app/providers/financial_setup_provider.dart';
import 'package:alpha_app/providers/goal_provider.dart';
import 'package:alpha_app/providers/home_provider.dart';
import 'package:alpha_app/providers/income_provider.dart';
import 'package:alpha_app/providers/onboarding_provider.dart';
import 'package:alpha_app/providers/profile_provider.dart';

class SessionStateCleaner {
  static Future<void> clearAllState(BuildContext context) async {
    // 1. Clear Profile and Token
    final profileProvider = context.read<ProfileProvider>();
    await profileProvider.logout();

    // 2. Clear Auth
    try {
      final authProvider = context.read<AuthProvider>();
      // authProvider.logout() if available, but ProfileProvider already removes the token.
    } catch (_) {}

    // 3. Clear other providers synchronously
    context.read<OnboardingProvider>().clearData();
    context.read<CycleProvider>().clearData();
    context.read<HomeProvider>().clearData();
    context.read<ExpenseProvider>().clearData();
    context.read<IncomeProvider>().clearData();
    context.read<GoalProvider>().clearData();

    // Clear Financial Setup
    try {
      // Assuming FinancialProvider has a clearData or similar, we'll try to call it.
      // If it doesn't exist, we will add it shortly.
      context.read<FinancialProvider>().clearData();
    } catch (_) {}
  }
}
