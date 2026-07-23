import 'package:alpha_app/core/utils/app_colors.dart';
import 'package:alpha_app/providers/themeprovider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class OptionChip extends StatelessWidget {
  final List<String> items;

  final String? selected;

  final Function(String) onTap;

  const OptionChip({
    super.key,
    required this.items,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final themeprovider = Provider.of<Themeprovider>(context);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 2.0),
      child: Row(
        children: items.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          final isSelected = item == selected;

          return Padding(
            padding:
                EdgeInsets.only(right: index != items.length - 1 ? 10.0 : 0),
            child: GestureDetector(
              onTap: () {
                onTap(item);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? (themeprovider.isDark
                              ? AppColors.darkSecondary
                              : AppColors.lightSecondary)
                          .withValues(alpha: 0.04)
                      : (themeprovider.isDark
                              ? AppColors.darkSubText
                              : AppColors.lightSubText)
                          .withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    width: 1.5,
                    color: isSelected
                        ? themeprovider.isDark
                            ? AppColors.darkPrimary
                            : AppColors.lightPrimary
                        : Colors.transparent,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isSelected) ...[
                      Icon(
                        Icons.check,
                        size: 16,
                        color: themeprovider.isDark
                            ? AppColors.darkPrimary
                            : AppColors.lightPrimary,
                      ),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      item,
                      maxLines: 1,
                      overflow: TextOverflow.visible,
                      style: TextStyle(
                        color: isSelected
                            ? themeprovider.isDark
                                ? AppColors.darkPrimary
                                : AppColors.lightPrimary
                            : (themeprovider.isDark
                                ? AppColors.darkSubText
                                : AppColors.lightSubText),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
