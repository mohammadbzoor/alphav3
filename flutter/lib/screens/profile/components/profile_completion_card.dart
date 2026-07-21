import 'package:alpha_app/core/utils/app_colors.dart';
import 'package:alpha_app/models/profile_completion_model.dart';
import 'package:alpha_app/providers/profile_provider.dart';
import 'package:alpha_app/screens/profile/financial_setup_screen.dart';
import 'package:alpha_app/screens/profile/personal_info_screen.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ProfileCompletionCard extends StatelessWidget {
  final ProfileProvider profileProvider;
  final bool isDark;

  const ProfileCompletionCard({
    Key? key,
    required this.profileProvider,
    required this.isDark,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final completion = profileProvider.profileCompletion;

    if (completion != null && completion.isComplete) {
      return const SizedBox.shrink();
    }

    if (completion == null) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkBorder : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.redAccent.withOpacity(0.5)),
        ),
        child: Column(
          children: [
            Icon(Icons.error_outline, color: Colors.redAccent),
            const SizedBox(height: 8),
            Text(
              'Could not load profile completion data.',
              style: GoogleFonts.ibmPlexSansArabic(
                color: isDark ? AppColors.darkText : AppColors.lightText,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                profileProvider.refreshProfileSummary();
              },
              child: Text(
                'Retry',
                style: GoogleFonts.ibmPlexSansArabic(color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary),
              ),
            )
          ],
        ),
      );
    }

    final double progress = completion.percentage / 100.0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkBorder : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'complete_profile'.tr(),
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.darkText : AppColors.lightText,
                  ),
                ),
              ),
              Text(
                '${completion.percentage}%',
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: isDark ? AppColors.darkBackground : Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(
              isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
            ),
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(height: 12),
          Text(
            'completion_message'.tr(namedArgs: {'percentage': completion.percentage.toString()}),
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: 13,
              color: isDark ? AppColors.darkSubText : AppColors.lightSubText,
            ),
          ),
          const SizedBox(height: 12),
          if (completion.missingSections.isNotEmpty) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: completion.missingSections.map((section) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkBackground : Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'missing_$section'.tr(),
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 11,
                      color: isDark ? AppColors.darkText : AppColors.lightText,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
          ],
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                _navigateToNextRequired(context, completion.nextRequiredSection);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: Text(
                'complete_now'.tr(),
                style: GoogleFonts.ibmPlexSansArabic(
                  color: AppColors.darkBorder,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToNextRequired(BuildContext context, String? section) {
    Widget? nextScreen;
    
    if (section == 'personal_information') {
      nextScreen = const PersonalInfoScreen(isEditing: true);
    } else if (section == 'financial_information') {
      nextScreen = const FinancialSetupScreen();
    } else if (section == 'allocation_preference') {
      nextScreen = const FinancialSetupScreen();
    }

    if (nextScreen != null) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => nextScreen!),
      ).then((_) {
        profileProvider.refreshProfileSummary();
      });
    }
  }
}
