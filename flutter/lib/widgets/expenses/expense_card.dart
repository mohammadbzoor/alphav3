import 'package:alpha_app/core/utils/app_colors.dart';
import 'package:alpha_app/models/expense_model.dart';
import 'package:alpha_app/providers/themeprovider.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class ExpenseCard extends StatelessWidget {
  final ExpenseModel expense;
  final VoidCallback onDelete;

  const ExpenseCard({
    super.key,
    required this.expense,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<Themeprovider>().isDark;

    final json = expense.toJson();

    final title =
        expense.title.trim().isEmpty ? "Expense" : expense.title.trim();

    final amount = _toDouble(
      json['amount'] ?? json['expenseAmount'] ?? json['value'],
    );

    final category = _readValue(
      json,
      const [
        'category',
        'categoryName',
        'category_name',
      ],
      fallback: 'Other',
    );

    final payment = _readValue(
      json,
      const [
        'paymentMethod',
        'payment_method',
        'payment',
      ],
      fallback: 'Payment',
    );

    final movement = _readValue(
      json,
      const [
        'movementType',
        'movement_type',
        'movement',
      ],
      fallback: 'One-time',
    );

    final expenseType = _readValue(
      json,
      const [
        'expenseType',
        'expense_type',
        'type',
      ],
      fallback: 'Need',
    );

    final date = _readDate(json);
    final categoryColor = _categoryColor(category);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(
        bottom: 12,
      ),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: categoryColor.withOpacity(
          isDark ? 0.10 : 0.06,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: categoryColor.withOpacity(0.28),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: categoryColor.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: categoryColor.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  _categoryIcon(category),
                  color: categoryColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.ibmPlexSansArabic(
                        color:
                            isDark ? AppColors.darkText : AppColors.lightText,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "$category • $payment",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.ibmPlexSansArabic(
                        color: isDark
                            ? AppColors.darkSubText
                            : AppColors.lightSubText,
                        fontSize: 10,
                      ),
                    ),
                    if (date != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        _formatDate(date),
                        style: GoogleFonts.ibmPlexSansArabic(
                          color: isDark
                              ? AppColors.darkSubText
                              : AppColors.lightSubText,
                          fontSize: 9,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  PopupMenuButton<String>(
                    tooltip: "Expense options",
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    color: isDark ? AppColors.darkBorder : Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        14,
                      ),
                    ),
                    icon: Icon(
                      Icons.more_horiz_rounded,
                      color: categoryColor.withOpacity(0.75),
                      size: 21,
                    ),
                    onSelected: (value) {
                      if (value == 'delete') {
                        onDelete();
                      }
                    },
                    itemBuilder: (
                      context,
                    ) {
                      return [
                        PopupMenuItem<String>(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(
                                Icons.delete_outline_rounded,
                                color: isDark
                                    ? AppColors.darkError
                                    : AppColors.lightError,
                              ),
                              const SizedBox(
                                width: 8,
                              ),
                              Text(
                                "Delete Expense",
                                style: GoogleFonts.ibmPlexSansArabic(
                                  color: isDark
                                      ? AppColors.darkError
                                      : AppColors.lightError,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ];
                    },
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "${amount.toStringAsFixed(2)} JOD",
                    style: GoogleFonts.ibmPlexSansArabic(
                      color: categoryColor,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _SmallBadge(
                label: expenseType,
                color: expenseType.toLowerCase().contains('want')
                    ? (isDark ? AppColors.darkAccent : AppColors.lightAccent)
                    : (isDark
                        ? AppColors.darkSecondary
                        : AppColors.lightSecondary),
              ),
              const SizedBox(width: 8),
              _SmallBadge(
                label: movement,
                color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
              ),
              const Spacer(),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: categoryColor.withOpacity(0.70),
                size: 13,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SmallBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _SmallBadge({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.ibmPlexSansArabic(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

String _readValue(
  Map<String, dynamic> json,
  List<String> keys, {
  required String fallback,
}) {
  for (final key in keys) {
    final value = json[key];

    if (value == null) {
      continue;
    }

    final cleaned = _cleanText(value.toString());

    if (cleaned.isNotEmpty) {
      return cleaned;
    }
  }

  return fallback;
}

String _cleanText(
  String value,
) {
  var cleaned = value.trim();

  if (cleaned.contains('.')) {
    cleaned = cleaned.split('.').last;
  }

  cleaned = cleaned.replaceAll('_', ' ');

  if (cleaned.isEmpty) {
    return '';
  }

  return cleaned
      .split(' ')
      .where(
        (word) => word.isNotEmpty,
      )
      .map(
        (word) => '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}',
      )
      .join(' ');
}

double _toDouble(
  dynamic value,
) {
  if (value is num) {
    return value.toDouble();
  }

  return double.tryParse(
        value?.toString() ?? '',
      ) ??
      0;
}

DateTime? _readDate(
  Map<String, dynamic> json,
) {
  final value = json['date'] ??
      json['expenseDate'] ??
      json['expense_date'] ??
      json['createdAt'] ??
      json['created_at'];

  if (value is DateTime) {
    return value;
  }

  if (value is int) {
    return DateTime.fromMillisecondsSinceEpoch(
      value,
    );
  }

  if (value != null) {
    return DateTime.tryParse(
      value.toString(),
    );
  }

  return null;
}

String _formatDate(
  DateTime date,
) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  return '${months[date.month - 1]} ${date.day}, ${date.year}';
}

IconData _categoryIcon(
  String category,
) {
  switch (category.toLowerCase()) {
    case 'food':
      return Icons.restaurant_outlined;
    case 'shopping':
      return Icons.shopping_bag_outlined;
    case 'transport':
      return Icons.directions_car_outlined;
    case 'bills':
      return Icons.receipt_long_outlined;
    case 'health':
      return Icons.favorite_outline;
    case 'education':
      return Icons.school_outlined;
    case 'entertainment':
      return Icons.movie_outlined;
    case 'travel':
      return Icons.flight_takeoff_outlined;
    case 'investment':
      return Icons.trending_up_rounded;
    default:
      return Icons.payments_outlined;
  }
}

Color _categoryColor(
  String category,
) {
  switch (category.toLowerCase()) {
    case 'food':
      return const Color(0xFF34D399);
    case 'shopping':
      return const Color(0xFF9B7EDE);
    case 'transport':
      return const Color(0xFFF4C95D);
    case 'bills':
      return const Color(0xFF4F9CF9);
    case 'health':
      return const Color(0xFFFF6B6B);
    case 'education':
      return const Color(0xFF14B8A6);
    case 'entertainment':
      return const Color(0xFFEC76A8);
    case 'travel':
      return const Color(0xFF6E7FE8);
    case 'investment':
      return const Color(0xFFD4A72C);
    default:
      return const Color(0xFF8A9A96);
  }
}
