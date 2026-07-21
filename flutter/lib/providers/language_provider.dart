import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageProvider extends ChangeNotifier{

Locale _currentLocale = const Locale('en');

  Locale get currentLocale => _currentLocale;
   String get languageCode => _currentLocale.languageCode;


Future<void> changeLanguage(BuildContext context, String langCode) async {
   
_currentLocale  = Locale(langCode);

await context.setLocale(_currentLocale);

final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language_code', langCode);
    
    notifyListeners();

  }

Future<void> loadSavedLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final lang = prefs.getString('language_code') ?? 'en';

    _currentLocale = Locale(lang);
    notifyListeners();
  }



}