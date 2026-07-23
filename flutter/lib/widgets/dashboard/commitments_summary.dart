import 'package:flutter/material.dart';
import 'package:alpha_app/core/utils/app_colors.dart';
import 'package:alpha_app/models/home_model.dart';
import 'package:google_fonts/google_fonts.dart';

class CommitmentsSummaryWidget extends StatelessWidget {
  final HomeCommitmentsSummary? commitments;
  final bool isDark;
  final VoidCallback onViewCommitments;

  const CommitmentsSummaryWidget({
    Key? key,
    required this.commitments,
    required this.isDark,
    required this.onViewCommitments,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (commitments == null) return const SizedBox.shrink();

    final shouldShow = (commitments!.totalReserved != null &&
            commitments!.totalReserved! > 0) ||
        commitments!.upcomingCount > 0 ||
        commitments!.overdueCount > 0;

    if (!shouldShow) return const SizedBox.shrink();

    final hasOverdue = commitments!.overdueCount > 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasOverdue
              ? Colors.red.withOpacity(0.5)
              : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.event_repeat,
                  color: hasOverdue
                      ? Colors.red
                      : (isDark
                          ? AppColors.darkPrimary
                          : AppColors.lightPrimary)),
              const SizedBox(width: 8),
              Text(
                "Commitments Summary",
                style: GoogleFonts.ibmPlexSansArabic(
                  color: isDark ? AppColors.darkText : AppColors.lightText,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: onViewCommitments,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  "View",
                  style: GoogleFonts.ibmPlexSansArabic(
                    color:
                        isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildItem(
                  "Total Reserved",
                  commitments!.totalReserved != null
                      ? "${commitments!.totalReserved!.toStringAsFixed(2)} JOD"
                      : "0.00 JOD"),
              _buildItem("Upcoming", "${commitments!.upcomingCount}"),
              _buildItem("Overdue", "${commitments!.overdueCount}",
                  color: hasOverdue ? Colors.red : null),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildItem(String label, String value, {Color? color}) {
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
            color: color ?? (isDark ? AppColors.darkText : AppColors.lightText),
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ],
    );
  }
}
