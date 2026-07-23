import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:alpha_app/providers/onboarding_provider.dart';
import 'package:alpha_app/providers/themeprovider.dart';
import 'package:alpha_app/core/utils/step_resolver.dart';
import 'package:alpha_app/core/utils/app_colors.dart';
import 'package:alpha_app/widgets/option_chip.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';

class OnboardingPersonalInfoScreen extends StatefulWidget {
  const OnboardingPersonalInfoScreen({super.key});

  @override
  State<OnboardingPersonalInfoScreen> createState() =>
      _OnboardingPersonalInfoScreenState();
}

class _OnboardingPersonalInfoScreenState
    extends State<OnboardingPersonalInfoScreen> {
  String? _gender = 'Female';
  String? _maritalStatus = 'Single';
  bool _isHeadOfHousehold = false;
  bool _contributesToExpenses = false;
  bool _isStudent = false;
  int _familySize = 1;
  bool _isNavigating = false;

  Future<void> _submit() async {
    if (_isNavigating) return;
    setState(() => _isNavigating = true);

    try {
      final provider = Provider.of<OnboardingProvider>(context, listen: false);

      final data = {
        'gender': _gender?.toLowerCase(),
        'maritalStatus': _maritalStatus?.toLowerCase(),
        'isHeadOfHousehold': _isHeadOfHousehold,
        'isStudent': _isStudent,
        'familySize': _familySize,
        'contributesToExpenses': _contributesToExpenses,
      };

      final success = await provider.savePersonalInfo(data);
      if (!mounted) return;

      if (success) {
        replaceWithOnboardingStep(context, provider.nextStep);
      } else if (provider.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(provider.errorMessage!)),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isNavigating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<OnboardingProvider>(context);
    final themeProvider = Provider.of<Themeprovider>(context);
    final isDark = themeProvider.isDark;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              Text(
                'Personal Information',
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.darkText : AppColors.lightText,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Accurate data means sharper advice from Alpha',
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color:
                      isDark ? AppColors.darkSubText : AppColors.lightSubText,
                ),
              ),
              const SizedBox(height: 20),
              LinearPercentIndicator(
                lineHeight: 12.0,
                percent: 0.25,
                padding: EdgeInsets.zero,
                backgroundColor:
                    isDark ? AppColors.darkBorder : AppColors.lightBorder,
                progressColor:
                    isDark ? AppColors.darkSecondary : AppColors.lightSecondary,
                barRadius: const Radius.circular(10),
              ),
              const SizedBox(height: 30),
              _SectionTitle('Gender', isDark: isDark),
              const SizedBox(height: 10),
              OptionChip(
                items: const ['Female', 'Male'],
                selected: _gender,
                onTap: (val) => setState(() => _gender = val),
              ),
              const SizedBox(height: 20),
              _SectionTitle('Marital Status', isDark: isDark),
              const SizedBox(height: 10),
              OptionChip(
                items: const ['Single', 'Married', 'Other'],
                selected: _maritalStatus,
                onTap: (val) => setState(() => _maritalStatus = val),
              ),
              const SizedBox(height: 20),
              _SectionTitle('Are you head of household?', isDark: isDark),
              const SizedBox(height: 10),
              OptionChip(
                items: const ['Yes', 'No'],
                selected: _isHeadOfHousehold ? 'Yes' : 'No',
                onTap: (val) =>
                    setState(() => _isHeadOfHousehold = (val == 'Yes')),
              ),
              const SizedBox(height: 20),
              _SectionTitle('Do you contribute to family expenses?',
                  isDark: isDark),
              const SizedBox(height: 10),
              OptionChip(
                items: const ['Yes', 'No'],
                selected: _contributesToExpenses ? 'Yes' : 'No',
                onTap: (val) =>
                    setState(() => _contributesToExpenses = (val == 'Yes')),
              ),
              const SizedBox(height: 20),
              _SectionTitle('Are you university student?', isDark: isDark),
              const SizedBox(height: 10),
              OptionChip(
                items: const ['Yes', 'No'],
                selected: _isStudent ? 'Yes' : 'No',
                onTap: (val) => setState(() => _isStudent = (val == 'Yes')),
              ),
              const SizedBox(height: 20),
              _SectionTitle('Family members:', isDark: isDark),
              const SizedBox(height: 10),
              Row(
                children: [
                  _CounterButton(
                    icon: Icons.remove,
                    onTap: () {
                      if (_familySize > 1) setState(() => _familySize--);
                    },
                    isDark: isDark,
                  ),
                  const SizedBox(width: 20),
                  Text(
                    '$_familySize',
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isDark
                          ? AppColors.darkPrimary
                          : AppColors.lightPrimary,
                    ),
                  ),
                  const SizedBox(width: 20),
                  _CounterButton(
                    icon: Icons.add,
                    onTap: () => setState(() => _familySize++),
                    isDark: isDark,
                  ),
                ],
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: provider.isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: provider.isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          'Next',
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontSize: 18,
                            color: isDark
                                ? AppColors.darkBackground
                                : AppColors.lightCard,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final bool isDark;

  const _SectionTitle(this.title, {required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: GoogleFonts.ibmPlexSansArabic(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: isDark ? AppColors.darkSubText : AppColors.lightSubText,
      ),
    );
  }
}

class _CounterButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool isDark;

  const _CounterButton({
    required this.icon,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 45,
        height: 45,
        decoration: BoxDecoration(
          border: Border.all(
            color: isDark ? AppColors.darkAccent : AppColors.lightAccent,
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          color: isDark ? AppColors.darkAccent : AppColors.lightAccent,
        ),
      ),
    );
  }
}
