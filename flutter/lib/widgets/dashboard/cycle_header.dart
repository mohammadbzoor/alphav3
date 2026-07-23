import 'package:flutter/material.dart';
import 'package:alpha_app/core/utils/app_colors.dart';
import 'package:alpha_app/models/home_model.dart';
import 'package:google_fonts/google_fonts.dart';

class CycleHeader extends StatelessWidget {
  final HomeCycle? cycle;
  final bool isDark;

  const CycleHeader({Key? key, required this.cycle, required this.isDark})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (cycle == null) return const SizedBox.shrink();

    final daysRemainingText = cycle!.daysRemaining == null
        ? "Unavailable"
        : (cycle!.daysRemaining == 0
            ? "Ends today"
            : "${cycle!.daysRemaining} days left");

    final startDateStr = cycle!.startDate != null
        ? "${cycle!.startDate!.day}/${cycle!.startDate!.month}"
        : "";
    final endDateStr = cycle!.endDate != null
        ? "${cycle!.endDate!.day}/${cycle!.endDate!.month}"
        : "";

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: (isDark ? AppColors.darkBorder : AppColors.lightBorder),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Current Cycle",
                style: GoogleFonts.ibmPlexSansArabic(
                  color: isDark ? AppColors.darkText : AppColors.lightText,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "$startDateStr - $endDateStr",
                style: GoogleFonts.ibmPlexSansArabic(
                  color:
                      isDark ? AppColors.darkSubText : AppColors.lightSubText,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: (isDark ? AppColors.darkPrimary : AppColors.lightPrimary)
                  .withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              daysRemainingText,
              style: GoogleFonts.ibmPlexSansArabic(
                color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
