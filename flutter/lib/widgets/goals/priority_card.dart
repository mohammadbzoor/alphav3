import 'package:alpha_app/core/utils/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PriorityCard extends StatelessWidget {
  final int priority;
  final bool isDark;
  final double screenW;
  final ValueChanged<double> onChanged;

  const PriorityCard({
    super.key,
    required this.priority,
    required this.isDark,
    required this.screenW,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 15,
        vertical: 14,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkBorder : Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                Icons.priority_high_rounded,
                color:
                    isDark ? AppColors.darkSecondary : AppColors.lightSecondary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  "How important is this goal?",
                  style: GoogleFonts.ibmPlexSansArabic(
                    color: isDark ? AppColors.darkText : AppColors.lightText,
                    fontSize: screenW * 0.035,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                "$priority / 10",
                style: GoogleFonts.ibmPlexSansArabic(
                  color: isDark ? AppColors.darkAccent : AppColors.lightAccent,
                  fontSize: screenW * 0.038,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          Slider(
            value: priority.toDouble(),
            min: 1,
            max: 10,
            divisions: 9,
            label: priority.toString(),
            activeColor:
                isDark ? AppColors.darkSecondary : AppColors.lightSecondary,
            inactiveColor: isDark
                ? AppColors.darkSubText.withOpacity(0.25)
                : AppColors.lightSubText.withOpacity(0.25),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
