import 'package:alpha_app/core/utils/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class QuickActionsGrid extends StatelessWidget {
  final bool isDark;

  final VoidCallback onAddExpense;
  final VoidCallback onAnalytics;
  final VoidCallback onScanReceipt;
  final VoidCallback onChallenges;

  const QuickActionsGrid({
    super.key,
    required this.isDark,
    required this.onAddExpense,
    required this.onAnalytics,
    required this.onScanReceipt,
    required this.onChallenges,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.05,
      children: [
        QuickActionCard(
          title: 'Add Expense',
          subtitle: 'Track your spending',
          icon: Icons.account_balance_wallet_outlined,
          iconColor: isDark ? AppColors.darkError : AppColors.lightError,
          isDark: isDark,
          onTap: onAddExpense,
        ),
        QuickActionCard(
          title: 'Analytics',
          subtitle: 'View spending trends',
          icon: Icons.bar_chart_rounded,
          iconColor: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
          isDark: isDark,
          onTap: onAnalytics,
        ),
        QuickActionCard(
          title: 'Scan Receipt',
          subtitle: 'Capture expenses',
          icon: Icons.document_scanner_outlined,
          iconColor:
              isDark ? AppColors.darkSecondary : AppColors.lightSecondary,
          isDark: isDark,
          onTap: onScanReceipt,
        ),
        QuickActionCard(
          title: 'Challenges',
          subtitle: 'Build good habits',
          icon: Icons.emoji_events_outlined,
          iconColor: isDark ? AppColors.darkAccent : AppColors.lightAccent,
          isDark: isDark,
          onTap: onChallenges,
        ),
      ],
    );
  }
}

class QuickActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final bool isDark;
  final VoidCallback onTap;

  const QuickActionCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color cardColor = isDark
        ? AppColors.darkBorder.withOpacity(0.4)
        : AppColors.lightBorder.withOpacity(0.4);

    final Color borderColor =
        isDark ? AppColors.darkBorder : AppColors.lightBorder;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          padding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 16,
          ),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: borderColor,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(
                  icon,
                  color: iconColor,
                  size: 25,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.ibmPlexSansArabic(
                  color: isDark ? AppColors.darkText : AppColors.lightText,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.ibmPlexSansArabic(
                  color:
                      isDark ? AppColors.darkSubText : AppColors.lightSubText,
                  fontSize: 10,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
