import 'package:alpha_app/core/utils/app_colors.dart';
import 'package:alpha_app/core/utils/device.dart';
import 'package:alpha_app/core/utils/step_resolver.dart';
import 'package:alpha_app/providers/onboarding_provider.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class CompleteProfileCard extends StatefulWidget {
  final bool isDark;

  const CompleteProfileCard({
    super.key,
    required this.isDark,
  });

  @override
  State<CompleteProfileCard> createState() => _CompleteProfileCardState();
}

class _CompleteProfileCardState extends State<CompleteProfileCard> {
  bool _isLoading = false;

  Future<void> _handleCompleteProfile() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final provider = context.read<OnboardingProvider>();
      final success = await provider.checkOnboardingStatus();

      if (!mounted) return;

      if (success) {
        replaceWithOnboardingStep(
          context,
          provider.nextStep,
          allocation: provider.allocation,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              provider.errorMessage ?? "تعذر تحميل حالة الملف المالي.",
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final double screenW = Device.width(context);
    final double screenH = Device.height(context);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: screenW * 0.05,
        vertical: screenH * 0.025,
      ),
      decoration: BoxDecoration(
        color: widget.isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color:
                (widget.isDark ? AppColors.darkPrimary : AppColors.lightPrimary)
                    .withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person_add_alt_1_outlined,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              SizedBox(width: screenW * 0.03),
              Expanded(
                child: Text(
                  "أكمل ملفك المالي",
                  style: GoogleFonts.ibmPlexSansArabic(
                    color: Colors.white,
                    fontSize: screenW * 0.05,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: screenH * 0.02),
          Text(
            "أكمل بياناتك المالية للحصول على خطة Alpha المناسبة والبدء باستخدام الميزات المالية.",
            style: GoogleFonts.ibmPlexSansArabic(
              color: Colors.white.withOpacity(0.9),
              fontSize: screenW * 0.035,
              height: 1.5,
            ),
          ),
          SizedBox(height: screenH * 0.03),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleCompleteProfile,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: widget.isDark
                    ? AppColors.darkPrimary
                    : AppColors.lightPrimary,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: _isLoading
                  ? SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          widget.isDark
                              ? AppColors.darkPrimary
                              : AppColors.lightPrimary,
                        ),
                      ),
                    )
                  : Text(
                      "أكمل ملفك المالي",
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
