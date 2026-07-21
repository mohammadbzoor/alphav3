import 'package:alpha_app/core/utils/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class DashedActionButton extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  final bool isDark;

  final IconData icon;
  final double height;
  final double borderRadius;

  const DashedActionButton({
    super.key,
    required this.text,
    required this.onTap,
    required this.isDark,
    this.icon = Icons.add_rounded,
    this.height = 58,
    this.borderRadius = 22,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius:
          BorderRadius.circular(borderRadius),
      child: CustomPaint(
        painter: DashedBorderPainter(
          color: isDark
              ? const Color(0xFF29433E)
              : AppColors.lightSecondary
                  .withOpacity(0.40),
          borderRadius: borderRadius,
        ),
        child: SizedBox(
          width: double.infinity,
          height: height,
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: isDark
                      ? AppColors.darkSubText
                      : AppColors.lightSubText,
                ),
                const SizedBox(width: 8),
                Text(
                  text,
                  style: GoogleFonts.ibmPlexSansArabic(
                    color: isDark
                        ? AppColors.darkSubText
                        : AppColors.lightSubText,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class DashedBorderPainter
    extends CustomPainter {
  final Color color;
  final double borderRadius;

  const DashedBorderPainter({
    required this.color,
    this.borderRadius = 22,
  });

  @override
  void paint(
    Canvas canvas,
    Size size,
  ) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    const dashWidth = 5.0;
    const dashSpace = 4.0;

    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          Radius.circular(borderRadius),
        ),
      );

    for (final metric
        in path.computeMetrics()) {
      double distance = 0;

      while (distance < metric.length) {
        final end =
            (distance + dashWidth)
                .clamp(
          0.0,
          metric.length,
        );

        canvas.drawPath(
          metric.extractPath(
            distance,
            end,
          ),
          paint,
        );

        distance +=
            dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(
    covariant DashedBorderPainter
        oldDelegate,
  ) {
    return oldDelegate.color != color ||
        oldDelegate.borderRadius !=
            borderRadius;
  }
}