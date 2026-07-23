import 'package:flutter/material.dart';
import 'package:alpha_app/core/utils/app_colors.dart';
import 'package:alpha_app/models/home_model.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:percent_indicator/percent_indicator.dart';

class BucketCardsSection extends StatelessWidget {
  final HomeBuckets? buckets;
  final bool isDark;

  const BucketCardsSection({
    Key? key,
    required this.buckets,
    required this.isDark,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (buckets == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildBucketCard(
          "Needs",
          buckets!.needs,
          Icons.shopping_cart_outlined,
          context,
        ),
        const SizedBox(height: 12),
        _buildBucketCard(
          "Wants",
          buckets!.wants,
          Icons.favorite_outline,
          context,
        ),
        const SizedBox(height: 12),
        _buildBucketCard(
          "Savings",
          buckets!.savings,
          Icons.savings_outlined,
          context,
          isSavings: true,
        ),
      ],
    );
  }

  Widget _buildBucketCard(
      String title, HomeBucket? bucket, IconData icon, BuildContext context,
      {bool isSavings = false}) {
    if (bucket == null) return const SizedBox.shrink();

    final statusColor = _getStatusColor(bucket.status, isDark);
    final targetText = bucket.target != null
        ? "${bucket.target!.toStringAsFixed(2)} JOD"
        : "Unavailable";
    final actualText = bucket.actual != null
        ? "${bucket.actual!.toStringAsFixed(2)} JOD"
        : "Unavailable";

    double progress = 0.0;
    if (bucket.usagePercent != null) {
      progress = bucket.usagePercent! / 100.0;
    } else if (bucket.actual != null &&
        bucket.target != null &&
        bucket.target! > 0) {
      progress = bucket.actual! / bucket.target!;
    }
    progress = progress.clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: (isDark ? AppColors.darkBorder : AppColors.lightBorder),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: statusColor),
              const SizedBox(width: 8),
              Text(
                title,
                style: GoogleFonts.ibmPlexSansArabic(
                  color: isDark ? AppColors.darkText : AppColors.lightText,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const Spacer(),
              if (bucket.status != null && bucket.status != 'unavailable')
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    bucket.status!.toUpperCase(),
                    style: GoogleFonts.ibmPlexSansArabic(
                      color: statusColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildDetail("Actual", actualText),
              _buildDetail("Target", targetText),
            ],
          ),
          const SizedBox(height: 12),
          LinearPercentIndicator(
            lineHeight: 6.0,
            percent: progress,
            backgroundColor:
                isDark ? AppColors.darkBorder : AppColors.lightBorder,
            progressColor: statusColor,
            barRadius: const Radius.circular(8),
            padding: EdgeInsets.zero,
          ),
          const SizedBox(height: 12),
          if (!isSavings && bucket.reserved != null && bucket.reserved! > 0)
            _buildSmallDetail("Reserved for commitments:",
                "${bucket.reserved!.toStringAsFixed(2)} JOD"),
          if (!isSavings && bucket.availableVariable != null)
            _buildSmallDetail("Available for variable:",
                "${bucket.availableVariable!.toStringAsFixed(2)} JOD"),
          if (isSavings &&
              bucket.plannedEmergencyFund != null &&
              bucket.plannedEmergencyFund! > 0)
            _buildSmallDetail("Emergency Fund:",
                "${bucket.plannedEmergencyFund!.toStringAsFixed(2)} JOD"),
          if (isSavings &&
              bucket.plannedGoalAllocations != null &&
              bucket.plannedGoalAllocations! > 0)
            _buildSmallDetail("Goal Allocations:",
                "${bucket.plannedGoalAllocations!.toStringAsFixed(2)} JOD"),
          const SizedBox(height: 8),
          if (bucket.remaining != null)
            Text(
              "Remaining: ${bucket.remaining!.toStringAsFixed(2)} JOD",
              style: GoogleFonts.ibmPlexSansArabic(
                color: isDark ? AppColors.darkText : AppColors.lightText,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDetail(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.ibmPlexSansArabic(
            color: isDark ? AppColors.darkSubText : AppColors.lightSubText,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.ibmPlexSansArabic(
            color: isDark ? AppColors.darkText : AppColors.lightText,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildSmallDetail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.ibmPlexSansArabic(
              color: isDark ? AppColors.darkSubText : AppColors.lightSubText,
              fontSize: 12,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.ibmPlexSansArabic(
              color: isDark ? AppColors.darkSubText : AppColors.lightSubText,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String? status, bool isDark) {
    switch (status) {
      case 'healthy':
        return Colors.green;
      case 'moderate':
      case 'warning':
        return Colors.orange;
      case 'critical':
      case 'exceeded':
        return Colors.red;
      case 'unavailable':
      default:
        return isDark ? Colors.grey[600]! : Colors.grey[400]!;
    }
  }
}
