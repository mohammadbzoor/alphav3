import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Themeprovider extends ChangeNotifier{

bool _isDark = false;


bool  get isDark => _isDark;

ThemeMode get thememode => _isDark ? ThemeMode.dark :  ThemeMode.light;

void toggleDark() async
{
_isDark = !_isDark;

final pref = await SharedPreferences.getInstance();
await pref.setBool("isDark", _isDark);
notifyListeners();

}


void loadtheme()async
{
final pref = await SharedPreferences.getInstance();
_isDark = pref.getBool("isDark")?? false;

notifyListeners();

}






}