import 'package:flutter/material.dart';
import 'package:alpha_app/core/utils/app_colors.dart';
import 'package:alpha_app/models/home_model.dart';
import 'package:google_fonts/google_fonts.dart';

class SafeDailySpendingCard extends StatelessWidget {
  final HomeSafeDailySpending? safeDailySpending;
  final bool isDark;

  const SafeDailySpendingCard({
    Key? key,
    required this.safeDailySpending,
    required this.isDark,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (safeDailySpending == null) return const SizedBox.shrink();

    final isAvailable = safeDailySpending!.amount != null;
    final amountText = isAvailable
        ? "${safeDailySpending!.amount!.toStringAsFixed(2)} JOD"
        : _getReasonText(safeDailySpending!.reasons);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.shield_outlined,
                  color:
                      isDark ? AppColors.darkPrimary : AppColors.lightPrimary),
              const SizedBox(width: 8),
              Text(
                "Safe to spend daily",
                style: GoogleFonts.ibmPlexSansArabic(
                  color: isDark ? AppColors.darkText : AppColors.lightText,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const Spacer(),
              if (safeDailySpending!.reliability != null &&
                  safeDailySpending!.reliability != 'reliable' &&
                  safeDailySpending!.reliability != 'unavailable')
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    safeDailySpending!.reliability!,
                    style: GoogleFonts.ibmPlexSansArabic(
                      color: Colors.orange,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            amountText,
            style: GoogleFonts.ibmPlexSansArabic(
              color: isAvailable
                  ? (isDark ? AppColors.darkPrimary : AppColors.lightPrimary)
                  : (isDark ? AppColors.darkSubText : AppColors.lightSubText),
              fontWeight: FontWeight.bold,
              fontSize: isAvailable ? 24 : 14,
            ),
          ),
        ],
      ),
    );
  }

  String _getReasonText(List<String> reasons) {
    if (reasons.isEmpty) {
      return "لا تتوفر بيانات كافية لحساب الإنفاق اليومي الآمن.";
    }

    if (reasons.contains('NO_ACTIVE_FINANCIAL_CYCLE')) {
      return "لا توجد دورة مالية نشطة.";
    }
    if (reasons.contains('ZERO_INCOME')) {
      return "لم يتم تسجيل دخل.";
    }
    return "لا تتوفر بيانات كافية لحساب الإنفاق اليومي الآمن.";
  }
}
