import 'package:alpha_app/providers/themeprovider.dart';
import 'package:alpha_app/screens/auth/login.dart';
import 'package:alpha_app/screens/onboarding/PageView/boarding_one.dart';
import 'package:alpha_app/screens/onboarding/PageView/boarding_three.dart';
import 'package:alpha_app/screens/onboarding/PageView/boarding_two.dart';
import 'package:alpha_app/core/utils/app_colors.dart';
import 'package:alpha_app/core/utils/device.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int currentPage = 0;

  @override
  Widget build(BuildContext context) {
    final double screenW = Device.width(context);
    final double screenH = Device.height(context);
    final themeprovider = Provider.of<Themeprovider>(context);
    return SafeArea(
      child: Scaffold(
        backgroundColor: themeprovider.isDark
            ? AppColors.darkBackground
            : AppColors.lightBackground,
        body: Padding(
          padding: EdgeInsets.symmetric(horizontal: screenW * 0.05),
          child: Column(
            children: [
              Expanded(
                child: PageView(
                  controller: _controller,
                  onPageChanged: (index) {
                    setState(() {
                      currentPage = index;
                    });
                  },
                  children: [BoardingOne(), BoardingTwo(), BoardingThree()],
                ),
              ),
              SmoothPageIndicator(
                controller: _controller,
                count: 3,
                effect: ExpandingDotsEffect(
                  activeDotColor: themeprovider.isDark
                      ? AppColors.darkAccent
                      : AppColors.lightAccent,
                  dotColor: themeprovider.isDark
                      ? AppColors.darkBorder
                      : AppColors.lightBorder,
                  dotHeight: 8,
                  dotWidth: 8,
                  expansionFactor: 3,
                  spacing: 6,
                ),
              ),
              SizedBox(
                height: screenH * 0.05,
              ),
              currentPage == 2
                  ? ElevatedButton(
                      onPressed: () {
                        Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) => Login(),
                            ));
                      },
                      style: ButtonStyle(
                        backgroundColor: WidgetStatePropertyAll(
                          themeprovider.isDark
                              ? AppColors.darkPrimary
                              : AppColors.lightPrimary,
                        ),
                        fixedSize: WidgetStatePropertyAll(
                          Size(screenW * 0.8, screenH * 0.06),
                        ),
                        shape: WidgetStatePropertyAll(
                          RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      child: Text(
                        "Get Started",
                        style: TextStyle(
                          fontSize: screenW * 0.055,
                          color: AppColors.darkBorder,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                  : Row(
                      children: [
                        TextButton(
                          onPressed: () {
                            // Skip
                          },
                          child: Text(
                            "Skip",
                            style: TextStyle(
                                color: themeprovider.isDark
                                    ? AppColors.darkSubText
                                    : AppColors.lightSubText,
                                fontWeight: FontWeight.w500,
                                fontSize: screenW * 0.042),
                          ),
                        ),
                        Expanded(
                            child: ElevatedButton(
                          onPressed: () {
                            _controller.nextPage(
                              duration: Duration(milliseconds: 300),
                              curve: Curves.ease,
                            );
                          },
                          style: ButtonStyle(
                            backgroundColor: WidgetStatePropertyAll(
                              themeprovider.isDark
                                  ? AppColors.darkPrimary
                                  : AppColors.lightPrimary,
                            ),
                            fixedSize: WidgetStatePropertyAll(
                              Size(screenW * 0.8, screenH * 0.065),
                            ),
                            shape: WidgetStatePropertyAll(
                              RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                          child: Text(
                            "Next",
                            style: TextStyle(
                              fontSize: screenW * 0.055,
                              color: AppColors.darkBorder,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        )),
                      ],
                    ),
              SizedBox(
                height: screenH * 0.03,
              )
            ],
          ),
        ),
      ),
    );
  }
}
