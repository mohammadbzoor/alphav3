import 'package:alpha_app/main.dart';
import 'package:alpha_app/providers/auth_provider.dart';
import 'package:alpha_app/providers/financial_setup_provider.dart';
import 'package:alpha_app/providers/language_provider.dart';
import 'package:alpha_app/providers/onboarding_provider.dart';
import 'package:alpha_app/providers/personal_provider.dart';
import 'package:alpha_app/providers/themeprovider.dart';
import 'package:alpha_app/providers/home_provider.dart';
import 'package:alpha_app/providers/profile_provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  testWidgets('App smoke test with Providers and Localization',
      (WidgetTester tester) async {
    // Provide a localized app wrapper
    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [Locale('en'), Locale('ar')],
        path:
            'assets/translations', // This is ignored during tests usually or needs mock
        fallbackLocale: const Locale('en'),
        startLocale: const Locale('en'),
        child: MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => Themeprovider()),
            ChangeNotifierProvider(create: (_) => LanguageProvider()),
            ChangeNotifierProvider(create: (_) => AuthProvider()),
            ChangeNotifierProvider(create: (_) => OnboardingProvider()),
            ChangeNotifierProvider(create: (_) => PersonalProvider()),
            ChangeNotifierProvider(create: (_) => FinancialProvider()),
            ChangeNotifierProvider(create: (_) => HomeProvider()),
            ChangeNotifierProvider(create: (_) => ProfileProvider()),
          ],
          child: Builder(builder: (context) {
            return MaterialApp(
              locale: context.locale,
              supportedLocales: context.supportedLocales,
              localizationsDelegates: context.localizationDelegates,
              home: const Scaffold(
                body: Center(child: Text('Alpha App Ready')),
              ),
            );
          }),
        ),
      ),
    );

    // Initial pump and settle
    await tester.pumpAndSettle();

    // Verify it renders
    expect(find.text('Alpha App Ready'), findsOneWidget);
  });
}
