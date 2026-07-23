import 'dart:io';
import 'package:alpha_app/providers/auth_provider.dart';
import 'package:alpha_app/providers/challenge_provider.dart';
import 'package:alpha_app/providers/chatbot_provider.dart';
import 'package:alpha_app/providers/expense_provider.dart';
import 'package:alpha_app/providers/financial_analysis_provider.dart';
import 'package:alpha_app/providers/financial_setup_provider.dart';
import 'package:alpha_app/providers/goal_provider.dart';
import 'package:alpha_app/providers/home_provider.dart';
import 'package:alpha_app/providers/notification_provider.dart';

import 'package:alpha_app/providers/language_provider.dart';
import 'package:alpha_app/providers/leaderbord_provider.dart';
import 'package:alpha_app/providers/onboarding_provider.dart';
import 'package:alpha_app/providers/personal_provider.dart';
import 'package:alpha_app/providers/profile_provider.dart';
import 'package:alpha_app/providers/receipt_provider.dart';
import 'package:alpha_app/providers/income_provider.dart';
import 'package:alpha_app/providers/cycle_provider.dart';
import 'package:alpha_app/providers/reward_provider.dart' show RewardProvider;
import 'package:alpha_app/providers/financial_profile_provider.dart';

import 'package:alpha_app/providers/themeprovider.dart';
import 'package:alpha_app/screens/analysis/financial_analysis_screen.dart';
import 'package:alpha_app/screens/auth/create_account.dart';
import 'package:alpha_app/screens/auth/login.dart';
import 'package:alpha_app/screens/expenses/choose_expense_action_screen.dart';

import 'package:alpha_app/screens/main_screen.dart';
import 'package:alpha_app/screens/onboarding/splash_screen.dart';
import 'package:alpha_app/screens/profile/personal_info_screen.dart';
import 'package:alpha_app/screens/receipts/receipt_review_screen.dart';

import 'package:easy_localization/easy_localization.dart';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:alpha_app/config/api_config.dart';

import 'package:provider/provider.dart';


final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = MyHttpOverrides();
  // API Config handles environment setup now
  await EasyLocalization.ensureInitialized();

  if (kDebugMode) {
    debugPrint('\n=========================================');
    debugPrint('AlphaV3 Environment: ${ApiConfig.environment.name.toUpperCase()}');
    debugPrint('API Base URL: ${ApiConfig.apiV1BaseUrl}');
    debugPrint('=========================================\n');
  }

  runApp(
    EasyLocalization(
        supportedLocales: const [Locale('en'), Locale('ar')],
        path: 'assets/translations',
        fallbackLocale: const Locale('en'),
        startLocale: const Locale('en'),
        child: MultiProvider(providers: [
          ChangeNotifierProvider(
            create: (context) => Themeprovider()..loadtheme(),
          ),
          ChangeNotifierProvider(
              create: (context) => LanguageProvider()..loadSavedLanguage()),
          ChangeNotifierProvider(create: (context) => AuthProvider()),
          ChangeNotifierProvider(create: (context) => OnboardingProvider()),
          ChangeNotifierProvider(create: (context) => IncomeProvider()),
          ChangeNotifierProvider(create: (context) => PersonalProvider()),
          ChangeNotifierProvider(
              create: (context) => FinancialProfileProvider()),
          ChangeNotifierProvider(create: (context) => FinancialProvider()),
          ChangeNotifierProvider(create: (context) => GoalProvider()),
          ChangeNotifierProvider(create: (context) => CycleProvider()),
          ChangeNotifierProvider(
            create: (_) => ChallengeProvider(),
          ),
          ChangeNotifierProvider(
            create: (_) => RewardProvider(),
          ),
          ChangeNotifierProvider(
            create: (_) => LeaderboardProvider(),
          ),
          ChangeNotifierProvider(
            create: (_) => ChatbotProvider(),
          ),
          ChangeNotifierProvider(
            create: (_) => HomeProvider(),
          ),
          ChangeNotifierProvider(
            create: (_) => ReceiptProvider(),
          ),
          ChangeNotifierProvider(
            create: (_) => ExpenseProvider(),
          ),
          ChangeNotifierProvider(
            create: (_) => FinancialAnalysisProvider(),
          ),
          ChangeNotifierProvider(
            create: (_) => NotificationProvider(),
          ),
          ChangeNotifierProvider(
            create: (_) => ProfileProvider(),
          ),
        ], child: MyApp())),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    Future.microtask(() {
      String currentLang = context.locale.languageCode;
    });
  }

  @override
  Widget build(BuildContext context) {
    print(context.locale.languageCode);

    return Consumer<Themeprovider>(
      builder: (context, themeprovider, _) {
        return MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: ThemeData.light(),
            darkTheme: ThemeData.dark(),
            themeMode: themeprovider.thememode,
            localizationsDelegates: context.localizationDelegates,
            supportedLocales: context.supportedLocales,
            locale: context.locale,
            navigatorKey: navigatorKey,
            home: const SplashScreen());
      },
    );
  }
}
