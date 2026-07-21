
import 'package:alpha_app/media/images.dart';
import 'package:alpha_app/providers/themeprovider.dart';
import 'package:alpha_app/screens/onboarding/PageView/boarding_one.dart';
import 'package:alpha_app/screens/onboarding/onboarding_screen.dart';
import 'package:alpha_app/screens/auth/login.dart';
import 'package:alpha_app/screens/main_screen.dart';
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
 backgroundColor:  themeprovider.isDark ? AppColors.darkBackground : AppColors.lightBackground,
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

           SizedBox(height: screenH*0.03),

          Text(
            "Alpha",
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: screenW*0.1,
              fontWeight: FontWeight.bold,
              color: themeprovider.isDark
                  ? AppColors.darkText
                  : AppColors.lightText,
            ),
          ),
 SizedBox(height: screenH*0.02),
          Text(
            "SMART FINANCIAL ADVISOR",
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: screenW*0.042,
             
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
    
    // Optional delay for the splash animation
    await Future.delayed(const Duration(seconds: 3));

    if (!mounted) return;

    final hasSession = await authProvider.hasSavedSession();

    if (hasSession) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const MainNavigationScreen()),
      );
    } else {
      // You can add logic here to check if it's the first install and show OnboardingScreen instead
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const Login()),
      );
    }
  }




  }