import 'package:alpha_app/core/utils/app_colors.dart';
import 'package:alpha_app/providers/themeprovider.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class DeleteDialog {
  static Future<void> show({
    required BuildContext context,
    required String title,
    required String message,
    required VoidCallback onDelete,
  }) async {
    final themeProvider = context.read<Themeprovider>();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor:
              themeProvider.isDark ? const Color(0xFF172624) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: Text(
            title,
            style: GoogleFonts.ibmPlexSansArabic(
              color: themeProvider.isDark
                  ? AppColors.darkText
                  : AppColors.lightText,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            message,
            style: GoogleFonts.ibmPlexSansArabic(
              color: themeProvider.isDark
                  ? AppColors.darkSubText
                  : AppColors.lightSubText,
              fontSize: 14,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: Text(
                "Cancel",
                style: GoogleFonts.ibmPlexSansArabic(
                  color: themeProvider.isDark
                      ? AppColors.darkSubText
                      : AppColors.lightSubText,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                onDelete();
                Navigator.pop(dialogContext);
              },
              child: Text(
                "Delete",
                style: GoogleFonts.ibmPlexSansArabic(
                  color: const Color(0xFFFF6B6B),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
