import 'package:flutter/material.dart';
import 'package:alpha_app/core/utils/app_colors.dart';
import 'package:alpha_app/models/home_model.dart';
import 'package:google_fonts/google_fonts.dart';

class IncomeOverview extends StatelessWidget {
  final HomeIncome? income;
  final bool isDark;

  const IncomeOverview({Key? key, required this.income, required this.isDark})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (income == null) return const SizedBox.shrink();

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
              Icon(Icons.account_balance_wallet_outlined,
                  color:
                      isDark ? AppColors.darkPrimary : AppColors.lightPrimary),
              const SizedBox(width: 8),
              Text(
                "Income Overview",
                style: GoogleFonts.ibmPlexSansArabic(
                  color: isDark ? AppColors.darkText : AppColors.lightText,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildIncomeItem("Expected Income", income!.expected),
              _buildIncomeItem("Recorded Income", income!.recorded,
                  isPrimary: true),
            ],
          ),
          if (income!.unexpected != null && income!.unexpected! > 0) ...[
            const SizedBox(height: 12),
            Text(
              "Includes ${income!.unexpected!.toStringAsFixed(2)} JOD unexpected income.",
              style: GoogleFonts.ibmPlexSansArabic(
                color: isDark ? AppColors.darkSubText : AppColors.lightSubText,
                fontSize: 12,
              ),
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildIncomeItem(String label, double? amount,
      {bool isPrimary = false}) {
    final amountText =
        amount == null ? "Unavailable" : "${amount.toStringAsFixed(2)} JOD";
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
          amountText,
          style: GoogleFonts.ibmPlexSansArabic(
            color: isPrimary
                ? (isDark ? AppColors.darkPrimary : AppColors.lightPrimary)
                : (isDark ? AppColors.darkText : AppColors.lightText),
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ],
    );
  }
}
