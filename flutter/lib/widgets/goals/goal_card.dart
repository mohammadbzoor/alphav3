import 'package:alpha_app/core/utils/app_colors.dart';
import 'package:alpha_app/models/goal_model.dart';
import 'package:alpha_app/providers/themeprovider.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:provider/provider.dart';

class GoalCard extends StatelessWidget {
  final Goal goal;
  final VoidCallback onDelete;

  const GoalCard({
    super.key,
    required this.goal,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<Themeprovider>();

    final isDark = themeProvider.isDark;

    final Color urgencyColor = goal.showCircularProgress
        ? const Color(0xFFF4C95D)
        : const Color(0xFF34D399);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(
        bottom: 16,
      ),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkPrimary.withOpacity(0.04)
            : AppColors.lightPrimary.withOpacity(0.04),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
            color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _GoalHeader(
            goal: goal,
            isDark: isDark,
            urgencyColor: urgencyColor,
            onDelete: onDelete,
          ),
          const SizedBox(height: 18),
          if (goal.showCircularProgress)
            _CircularGoalContent(
              goal: goal,
              isDark: isDark,
            )
          else
            _LinearGoalContent(
              goal: goal,
              isDark: isDark,
            ),
        ],
      ),
    );
  }
}

// =====================================================
// HEADER
// =====================================================

class _GoalHeader extends StatelessWidget {
  final Goal goal;
  final bool isDark;
  final Color urgencyColor;
  final VoidCallback onDelete;

  const _GoalHeader({
    required this.goal,
    required this.isDark,
    required this.urgencyColor,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.darkPrimary.withOpacity(0.7)
                : AppColors.lightPrimary.withOpacity(0.7),
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Icon(
            _goalIcon(goal.category),
            color: isDark ? AppColors.darkText : AppColors.lightText,
            size: 25,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            goal.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.ibmPlexSansArabic(
              color: isDark ? AppColors.darkText : AppColors.lightText,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 5),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 7,
            vertical: 3,
          ),
          decoration: BoxDecoration(
            color: urgencyColor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            "${goal.daysLeft} days left",
            style: GoogleFonts.ibmPlexSansArabic(
              color: urgencyColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 2),
        PopupMenuButton<String>(
          tooltip: "Goal options",
          padding: EdgeInsets.zero,
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          elevation: 5,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          icon: Icon(
            Icons.more_vert,
            color: isDark ? AppColors.darkSubText : AppColors.lightSubText,
            size: 22,
          ),
          onSelected: (value) {
            if (value == "delete") {
              onDelete();
            }
          },
          itemBuilder: (context) {
            return [
              PopupMenuItem<String>(
                value: "delete",
                child: Row(
                  children: [
                    Icon(
                      Icons.delete_outline,
                      color:
                          isDark ? AppColors.darkError : AppColors.lightError,
                      size: 23,
                    ),
                    const SizedBox(width: 9),
                    Text(
                      "Delete Goal",
                      style: GoogleFonts.ibmPlexSansArabic(
                        color:
                            isDark ? AppColors.darkError : AppColors.lightError,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ];
          },
        ),
      ],
    );
  }

  IconData _goalIcon(String category) {
    switch (category) {
      case "Laptop":
        return Icons.laptop_mac_outlined;

      case "Travel":
        return Icons.flight_takeoff;

      case "Car":
        return Icons.directions_car_outlined;

      case "House":
        return Icons.home_outlined;

      case "Education":
        return Icons.school_outlined;

      case "Business":
        return Icons.business_center_outlined;

      case "Furniture":
        return Icons.chair_outlined;

      case "Emergency Fund":
        return Icons.health_and_safety_outlined;

      default:
        return Icons.flag_outlined;
    }
  }
}

// =====================================================
// CIRCULAR CARD CONTENT
// =====================================================

class _CircularGoalContent extends StatelessWidget {
  final Goal goal;
  final bool isDark;

  const _CircularGoalContent({
    required this.goal,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            CircularPercentIndicator(
              radius: 32,
              lineWidth: 6,
              percent: goal.progress,
              animation: true,
              animationDuration: 700,
              circularStrokeCap: CircularStrokeCap.round,
              backgroundColor:
                  isDark ? AppColors.darkBorder : AppColors.lightBorder,
              progressColor: const Color(0xFFF4C95D),
              center: Text(
                "${goal.progressPercentage}%",
                style: GoogleFonts.ibmPlexSansArabic(
                  color: isDark ? AppColors.darkText : AppColors.lightText,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Saved so far",
                    style: GoogleFonts.ibmPlexSansArabic(
                      color: isDark
                          ? AppColors.darkSubText
                          : AppColors.lightSubText,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (goal.hasProgressData)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          goal.savedAmount!.toStringAsFixed(0),
                          style: GoogleFonts.ibmPlexSansArabic(
                            color: isDark
                                ? AppColors.darkText
                                : AppColors.lightText,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Padding(
                            padding: const EdgeInsets.only(
                              bottom: 2,
                            ),
                            child: Text(
                              "of ${goal.targetAmount!.toStringAsFixed(0)} JD",
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.ibmPlexSansArabic(
                                color: isDark
                                    ? AppColors.darkSubText
                                    : AppColors.lightSubText,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  else
                    Text(
                      "Progress will appear here",
                      style: GoogleFonts.ibmPlexSansArabic(
                        color: isDark
                            ? AppColors.darkSubText
                            : AppColors.lightSubText,
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _RecommendationBox(
          goal: goal,
          isDark: isDark,
        ),
      ],
    );
  }
}

// =====================================================
// LINEAR CARD CONTENT
// =====================================================

class _LinearGoalContent extends StatelessWidget {
  final Goal goal;
  final bool isDark;

  const _LinearGoalContent({
    required this.goal,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: LinearProgressIndicator(
            value: goal.progress,
            minHeight: 7,
            backgroundColor:
                isDark ? AppColors.darkBorder : AppColors.lightBorder,
            valueColor: const AlwaysStoppedAnimation<Color>(
              Color(0xFF34D399),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              goal.savedAmount != null
                  ? "${goal.savedAmount!.toStringAsFixed(0)} JD"
                  : "0 JD",
              style: GoogleFonts.ibmPlexSansArabic(
                color: isDark ? AppColors.darkSubText : AppColors.lightSubText,
                fontSize: 10,
              ),
            ),
            Text(
              goal.targetAmount != null
                  ? "Goal ${goal.targetAmount!.toStringAsFixed(0)} JD"
                  : "Goal",
              style: GoogleFonts.ibmPlexSansArabic(
                color: isDark ? AppColors.darkSubText : AppColors.lightSubText,
                fontSize: 10,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _RecommendationBox(
          goal: goal,
          isDark: isDark,
        ),
      ],
    );
  }
}

// =====================================================
// RECOMMENDATION
// =====================================================

class _RecommendationBox extends StatelessWidget {
  final Goal goal;
  final bool isDark;

  const _RecommendationBox({
    required this.goal,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkBorder.withOpacity(0.8)
            : AppColors.lightBorder.withOpacity(0.8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                "💰",
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  "Recommended Monthly Saving",
                  style: GoogleFonts.ibmPlexSansArabic(
                    color: isDark
                        ? AppColors.darkSecondary
                        : AppColors.lightSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                "${goal.displayedMonthlyRecommendation.toStringAsFixed(0)} JD",
                style: GoogleFonts.ibmPlexSansArabic(
                  color: isDark ? AppColors.darkText : AppColors.lightText,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 5),
              Padding(
                padding: const EdgeInsets.only(
                  bottom: 2,
                ),
                child: Text(
                  "/ month",
                  style: GoogleFonts.ibmPlexSansArabic(
                    color:
                        isDark ? AppColors.darkSubText : AppColors.lightSubText,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
