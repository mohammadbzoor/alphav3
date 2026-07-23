import 'package:alpha_app/core/utils/app_colors.dart';
import 'package:alpha_app/core/utils/device.dart';
import 'package:alpha_app/providers/auth_provider.dart';
import 'package:alpha_app/providers/themeprovider.dart';
import 'package:alpha_app/screens/auth/login.dart';
import 'package:alpha_app/screens/auth/otp_screen.dart';
import 'package:alpha_app/screens/profile/birth_date_screen.dart';
import 'package:alpha_app/widgets/app_button.dart';
import 'package:alpha_app/widgets/custom_phonefield.dart';
import 'package:alpha_app/widgets/custom_textfield.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class CreateAccount extends StatefulWidget {
  const CreateAccount({
    super.key,
  });

  @override
  State<CreateAccount> createState() => _CreateAccountState();
}

class _CreateAccountState extends State<CreateAccount> {
  final _formKey = GlobalKey<FormState>();
  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      context.read<AuthProvider>().clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenW = Device.width(context);

    final screenH = Device.height(context);

    final themeProvider = context.watch<Themeprovider>();

    final authProvider = context.watch<AuthProvider>();

    final isDark = themeProvider.isDark;

    return Form(
      key: _formKey,
      child: SafeArea(
        child: Scaffold(
          backgroundColor:
              isDark ? AppColors.darkBackground : AppColors.lightBackground,
          body: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: screenW * 0.05,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: screenH * 0.06,
                  ),
                  Text(
                    "LET'S GET STARTED",
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: screenW * 0.04,
                      fontWeight: FontWeight.w500,
                      color:
                          isDark ? AppColors.darkAccent : AppColors.lightAccent,
                    ),
                  ),
                  SizedBox(
                    height: screenH * 0.02,
                  ),
                  Text(
                    'Create your account',
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: screenW * 0.08,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppColors.darkText : AppColors.lightText,
                    ),
                  ),
                  SizedBox(
                    height: screenH * 0.02,
                  ),
                  Text(
                    'One minute stands between you and real insight into your money',
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: screenW * 0.04,
                      fontWeight: FontWeight.w500,
                      color: isDark
                          ? AppColors.darkSubText
                          : AppColors.lightSubText,
                    ),
                  ),
                  SizedBox(
                    height: screenH * 0.03,
                  ),
                  _FieldTitle(
                    title: 'Full name',
                    isDark: isDark,
                    screenW: screenW,
                  ),
                  SizedBox(
                    height: screenH * 0.01,
                  ),
                  CustomTextfield(
                    controller: authProvider.nameController,
                    hint: 'Enter your full name',
                    type: TextFieldType.name,
                    icon: Icons.person,
                  ),
                  SizedBox(
                    height: screenH * 0.02,
                  ),
                  _FieldTitle(
                    title: 'Phone number',
                    isDark: isDark,
                    screenW: screenW,
                  ),
                  SizedBox(
                    height: screenH * 0.01,
                  ),
                  CustomPhoneField(
                    controller: authProvider.phoneController,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Phone number is required';
                      }

                      if (value.length != 9) {
                        return 'Enter a valid phone number';
                      }

                      if (!value.startsWith(
                        '7',
                      )) {
                        return 'Invalid phone number';
                      }

                      return null;
                    },
                  ),
                  SizedBox(
                    height: screenH * 0.02,
                  ),
                  _FieldTitle(
                    title: 'Email',
                    isDark: isDark,
                    screenW: screenW,
                  ),
                  SizedBox(
                    height: screenH * 0.01,
                  ),
                  CustomTextfield(
                    controller: authProvider.emailController,
                    hint: 'Enter your email',
                    type: TextFieldType.email,
                    icon: Icons.email_outlined,
                  ),
                  SizedBox(
                    height: screenH * 0.02,
                  ),
                  _FieldTitle(
                    title: 'Date of birth',
                    isDark: isDark,
                    screenW: screenW,
                  ),
                  SizedBox(
                    height: screenH * 0.01,
                  ),
                  CustomTextfield(
                    controller: authProvider.birthDateController,
                    hint: 'Select your birth date',
                    icon: Icons.calendar_month,
                    type: TextFieldType.date,
                    readOnly: true,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Date of birth is required';
                      }

                      return null;
                    },
                    onTap: () async {
                      final date = await Navigator.push<DateTime>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => BirthDateScreen(
                            initialDate: authProvider.birthDate,
                          ),
                        ),
                      );

                      if (date != null) {
                        authProvider.setBirthDate(
                          date,
                        );
                      }
                    },
                  ),
                  SizedBox(
                    height: screenH * 0.02,
                  ),
                  _FieldTitle(
                    title: 'Password',
                    isDark: isDark,
                    screenW: screenW,
                  ),
                  SizedBox(
                    height: screenH * 0.01,
                  ),
                  CustomTextfield(
                    controller: authProvider.passwordController,
                    hint: '8+ chars, upper, lower, number',
                    icon: Icons.lock_outline_rounded,
                    type: TextFieldType.password,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'validation.password_required'.tr();
                      }

                      if (value.length < 8) {
                        return 'Password must be at least 8 characters';
                      }

                      if (!RegExp(
                        r'(?=.*[a-z])',
                      ).hasMatch(value)) {
                        return 'Password must contain a lowercase letter';
                      }

                      if (!RegExp(
                        r'(?=.*[A-Z])',
                      ).hasMatch(value)) {
                        return 'Password must contain an uppercase letter';
                      }

                      if (!RegExp(
                        r'(?=.*\d)',
                      ).hasMatch(value)) {
                        return 'Password must contain a number';
                      }

                      return null;
                    },
                  ),
                  SizedBox(
                    height: screenH * 0.03,
                  ),
                  Center(
                    child: AppButton(
                      text: 'Create Account',
                      isDark: isDark,
                      isLoading: authProvider.isLoading,
                      width: screenW * 0.8,
                      height: screenH * 0.065,
                      onPressed: () async {
                        FocusScope.of(context).unfocus();

                        if (!_formKey.currentState!.validate()) {
                          return;
                        }

                        if (authProvider.birthDate == null) {
                          ScaffoldMessenger.of(context)
                            ..hideCurrentSnackBar()
                            ..showSnackBar(
                              const SnackBar(
                                content: Text('Please select your birth date'),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          return;
                        }

                        if (_isNavigating) return;
                        setState(() {
                          _isNavigating = true;
                        });

                        try {
                          final success =
                              await authProvider.createAccountAndSendOtp();

                          if (!mounted) return;

                          if (!success) {
                            ScaffoldMessenger.of(context)
                              ..hideCurrentSnackBar()
                              ..showSnackBar(
                                SnackBar(
                                  content: Text(
                                    authProvider.errorMessage ??
                                        'Could not create account',
                                  ),
                                  backgroundColor: isDark
                                      ? AppColors.darkError
                                      : AppColors.lightError,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            return;
                          }

                          ScaffoldMessenger.of(context)
                            ..hideCurrentSnackBar()
                            ..showSnackBar(
                              SnackBar(
                                content: const Text(
                                    'Verification code was sent to your email'),
                                backgroundColor: isDark
                                    ? AppColors.darkSecondary
                                    : AppColors.lightSecondary,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );

                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => OtpScreen(
                                phoneNumber: authProvider.fullPhoneNumber,
                                isRegistration: true,
                              ),
                            ),
                          );
                        } finally {
                          if (mounted) {
                            setState(() {
                              _isNavigating = false;
                            });
                          }
                        }
                      },
                    ),
                  ),
                  SizedBox(
                    height: screenH * 0.06,
                  ),
                  Center(
                    child: InkWell(
                      onTap: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const Login(),
                          ),
                        );
                      },
                      child: Text(
                        'Already have an account? Sign in',
                        style: TextStyle(
                          color: isDark
                              ? AppColors.darkSecondary
                              : AppColors.lightSecondary,
                          fontSize: screenW * 0.04,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    height: screenH * 0.04,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FieldTitle extends StatelessWidget {
  final String title;
  final bool isDark;
  final double screenW;

  const _FieldTitle({
    required this.title,
    required this.isDark,
    required this.screenW,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: screenW * 0.02,
      ),
      child: Text(
        title,
        style: TextStyle(
          fontSize: screenW * 0.04,
          color: isDark ? AppColors.darkSubText : AppColors.lightSubText,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
