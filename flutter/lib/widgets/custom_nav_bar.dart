import 'package:alpha_app/core/utils/app_colors.dart';
import 'package:alpha_app/providers/themeprovider.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class CustomBottomNavigationBar
    extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const CustomBottomNavigationBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final themeProvider =
        context.watch<Themeprovider>();

    final isDark = themeProvider.isDark;

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(
        20,
        0,
        20,
        14,
      ),
      child: Container(
        height: 72,
        padding:
            const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF10201F)
              : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isDark
                ? const Color(0xFF1D3532)
                : Colors.black.withOpacity(0.06),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(
                isDark ? 0.20 : 0.08,
              ),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: _NavigationItem(
                icon: Icons.home_outlined,
                selectedIcon: Icons.home,
                label: "Home",
                isSelected: currentIndex == 0,
                isDark: isDark,
                onTap: () => onTap(0),
              ),
            ),

            Expanded(
              child: _NavigationItem(
                icon: Icons.receipt_long_outlined,
                selectedIcon: Icons.receipt_long,
                label: "Expenses",
                isSelected: currentIndex == 1,
                isDark: isDark,
                onTap: () => onTap(1),
              ),
            ),

            Expanded(
              child: _BasiraNavigationItem(
                isSelected: currentIndex == 2,
                onTap: () => onTap(2),
              ),
            ),

            Expanded(
              child: _NavigationItem(
                icon: Icons.track_changes_outlined,
                selectedIcon: Icons.track_changes,
                label: "Goals",
                isSelected: currentIndex == 3,
                isDark: isDark,
                onTap: () => onTap(3),
              ),
            ),

            Expanded(
              child: _NavigationItem(
                icon: Icons.person_outline,
                selectedIcon: Icons.person,
                label: "Profile",
                isSelected: currentIndex == 4,
                isDark: isDark,
                onTap: () => onTap(4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =====================================================
// NORMAL ITEM
// =====================================================

class _NavigationItem extends StatelessWidget {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  const _NavigationItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final selectedColor = isDark
        ? AppColors.darkSecondary
        : AppColors.lightSecondary;

    final unselectedColor = isDark
        ? AppColors.darkSubText
        : AppColors.lightSubText;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: double.infinity,
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Icon(
              isSelected ? selectedIcon : icon,
              size: 25,
              color: isSelected
                  ? selectedColor
                  : unselectedColor,
            ),

            const SizedBox(height: 5),

            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.ibmPlexSansArabic(
                color: isSelected
                    ? selectedColor
                    : unselectedColor,
                fontSize: 10,
                fontWeight: isSelected
                    ? FontWeight.bold
                    : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =====================================================
// BASIRA CENTER ITEM
// =====================================================

class _BasiraNavigationItem extends StatelessWidget {
  final bool isSelected;
  final VoidCallback onTap;

  const _BasiraNavigationItem({
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: const Offset(0, -15),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: AnimatedContainer(
          duration:
              const Duration(milliseconds: 250),
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFF4C95D),
                Color(0xFF7BE495),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF34D399)
                    .withOpacity(
                  isSelected ? 0.45 : 0.25,
                ),
                blurRadius: isSelected ? 22 : 15,
                spreadRadius: isSelected ? 2 : 0,
                offset: const Offset(0, 7),
              ),
            ],
            border: Border.all(
              color: Colors.white.withOpacity(
                isSelected ? 0.45 : 0.20,
              ),
            ),
          ),
          child: Center(
            child: Icon(
            Icons.psychology_alt_outlined,
              color: const Color(0xFF0B4A3E),
              size: isSelected ? 38 : 35,
            ),
          ),
        ),
      ),
    );
  }
}