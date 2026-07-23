import 'package:flutter/material.dart';
import 'package:alpha_app/core/utils/app_colors.dart';
import 'package:google_fonts/google_fonts.dart';

class DashboardWarningsWidget extends StatelessWidget {
  final List<String> warnings;
  final bool isDark;

  const DashboardWarningsWidget({
    Key? key,
    required this.warnings,
    required this.isDark,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Filter out NO_ACTIVE_FINANCIAL_CYCLE since that's handled by StartCycleCard
    final filteredWarnings =
        warnings.where((w) => w != 'NO_ACTIVE_FINANCIAL_CYCLE').toList();
    if (filteredWarnings.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.orange.withOpacity(0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.orange),
              const SizedBox(width: 8),
              Text(
                "Important Notices",
                style: GoogleFonts.ibmPlexSansArabic(
                  color: Colors.orange,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...filteredWarnings.map((w) => Padding(
                padding: const EdgeInsets.only(bottom: 6.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("• ", style: TextStyle(color: Colors.orange)),
                    Expanded(
                      child: Text(
                        _getWarningMessage(w),
                        style: GoogleFonts.ibmPlexSansArabic(
                          color:
                              isDark ? AppColors.darkText : AppColors.lightText,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  String _getWarningMessage(String code) {
    switch (code) {
      case 'OVERDUE_COMMITMENTS':
        return 'You have overdue commitments that require your attention.';
      case 'NO_INCOME_RECORDED':
        return 'No income has been recorded yet for the current cycle.';
      case 'UNEXPECTED_EXPENSE_IMPACT':
        return 'Unexpected expenses may impact your planned savings.';
      default:
        return 'Notice: $code';
    }
  }
}
