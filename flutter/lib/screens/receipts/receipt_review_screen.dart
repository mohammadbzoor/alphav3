import 'package:alpha_app/core/utils/app_colors.dart';
import 'package:alpha_app/models/parsed_receipt_model.dart';
import 'package:alpha_app/providers/receipt_provider.dart';
import 'package:alpha_app/providers/themeprovider.dart';
import 'package:alpha_app/widgets/app_button.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class ReceiptReviewScreen extends StatelessWidget {
  const ReceiptReviewScreen({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDark =
        context.watch<Themeprovider>().isDark;

    final receiptProvider =
        context.watch<ReceiptProvider>();

    final receipt =
        receiptProvider.parsedReceipt;

    if (receipt == null) {
      return Scaffold(
        backgroundColor: isDark
            ? AppColors.darkBackground
            : AppColors.lightBackground,
        body: _NoReceiptView(
          isDark: isDark,
        ),
      );
    }

    final bool isVoice =
        receipt.inputType ==
            ReceiptInputType.voice;

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.darkBackground
          : AppColors.lightBackground,
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              physics:
                  const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                22,
                22,
                22,
                120,
              ),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  _Header(
                    isVoice: isVoice,
                    isDark: isDark,
                  ),

                  const SizedBox(height: 22),

                  _ConfidenceCard(
                    confidence:
                        receipt.confidence,
                    isVoice: isVoice,
                    isDark: isDark,
                  ),

                  const SizedBox(height: 14),

                  _GeneralInfoCard(
                    receipt: receipt,
                    isDark: isDark,
                    onStorePressed: () {
                      _editStoreName(
                        context,
                        receipt.storeName,
                        isDark,
                      );
                    },
                    onDatePressed: () {
                      _selectDate(
                        context,
                        receipt.date,
                      );
                    },
                    onCategoryPressed: () {
                      _selectCategory(
                        context,
                        receipt.suggestedCategory,
                        isDark,
                      );
                    },
                  ),

                  const SizedBox(height: 14),

                  _ItemsCard(
                    items: receipt.items,
                    total: receipt.total,
                    isDark: isDark,
                    onEditItem: (item) {
                      _editItem(
                        context,
                        item,
                        isDark,
                      );
                    },
                    onRemoveItem: (item) {
                      _showDeleteItemDialog(
                        context,
                        item,
                        isDark,
                      );
                    },
                  ),
                ],
              ),
            ),

            Positioned(
              left: 22,
              right: 22,
              bottom:
                  MediaQuery.paddingOf(context)
                          .bottom +
                      15,
              child: AppButton(
                text: "Confirm",
                isDark: isDark,
                isLoading:
                    receiptProvider.isProcessing,
                width: double.infinity,
                height: 54,
                onPressed: () {
                  _confirmReceipt(context);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmReceipt(
    BuildContext context,
  ) async {
    final success = await context
        .read<ReceiptProvider>()
        .confirmReceipt();

    if (!context.mounted || !success) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            "Expense added successfully",
            style:
                GoogleFonts.ibmPlexSansArabic(
                  
                ),
          ),
          backgroundColor:
              const Color(0xFF0F766E),
        ),
      );

    context.read<ReceiptProvider>().clear();

    Navigator.popUntil(
      context,
      (route) => route.isFirst,
    );
  }

  Future<void> _selectDate(
    BuildContext context,
    DateTime currentDate,
  ) async {
    final selectedDate =
        await showDatePicker(
      context: context,
      initialDate: currentDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );

    if (!context.mounted ||
        selectedDate == null) {
      return;
    }

    context
        .read<ReceiptProvider>()
        .updateDate(selectedDate);
  }

  void _editStoreName(
    BuildContext context,
    String currentValue,
    bool isDark,
  ) {
    final controller =
        TextEditingController(
      text: currentValue,
    );

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: isDark
              ? AppColors.darkBackground
              : AppColors.lightBackground,
          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(22),
          ),
          title: Text(
            "Edit store",
            style:
                GoogleFonts.ibmPlexSansArabic(
              color: isDark
                  ? AppColors.darkText
                  : AppColors.lightText,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            style: TextStyle(
              color: isDark
                  ? AppColors.darkText
                  : AppColors.lightText,
            ),
            decoration: _inputDecoration(
              hint: "Store name",
              isDark: isDark,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                final value =
                    controller.text.trim();

                if (value.isEmpty) return;

                context
                    .read<ReceiptProvider>()
                    .updateStoreName(value);

                Navigator.pop(dialogContext);
              },
              style:
                  ElevatedButton.styleFrom(
                backgroundColor:
                    const Color(0xFF34D399),
                foregroundColor:
                    const Color(0xFF09231E),
              ),
              child: const Text("Save"),
            ),
          ],
        );
      },
    );
  }

  void _selectCategory(
    BuildContext context,
    String selectedCategory,
    bool isDark,
  ) {
    const categories = [
      "Shopping",
      "Groceries",
      "Food",
      "Transport",
      "Bills",
      "Health",
      "Entertainment",
      "Education",
      "Other",
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          padding: EdgeInsets.fromLTRB(
            20,
            15,
            20,
            MediaQuery.paddingOf(context)
                    .bottom +
                20,
          ),
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.darkBackground
                : AppColors.lightBackground,
            borderRadius:
                const BorderRadius.vertical(
              top: Radius.circular(28),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white24
                      : Colors.black12,
                  borderRadius:
                      BorderRadius.circular(10),
                ),
              ),

              const SizedBox(height: 18),

              Text(
                "Select category",
                style: GoogleFonts
                    .ibmPlexSansArabic(
                  color: isDark
                      ? AppColors.darkText
                      : AppColors.lightText,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 12),

              ...categories.map(
                (category) {
                  final selected =
                      category ==
                          selectedCategory;

                  return ListTile(
                    onTap: () {
                      context
                          .read<ReceiptProvider>()
                          .updateCategory(category);

                      Navigator.pop(sheetContext);
                    },
                    leading: Icon(
                      _categoryIcon(category),
                      color: selected
                          ? const Color(
                              0xFF34D399,
                            )
                          : isDark
                              ? AppColors
                                  .darkSubText
                              : AppColors
                                  .lightSubText,
                    ),
                    title: Text(
                      category,
                      style: GoogleFonts
                          .ibmPlexSansArabic(
                        color: isDark
                            ? AppColors.darkText
                            : AppColors.lightText,
                        fontWeight: selected
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                    trailing: selected
                        ? const Icon(
                            Icons.check_rounded,
                            color: Color(
                              0xFF34D399,
                            ),
                          )
                        : null,
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _editItem(
    BuildContext context,
    ReceiptItemModel item,
    bool isDark,
  ) {
    final nameController =
        TextEditingController(
      text: item.name,
    );

    final amountController =
        TextEditingController(
      text: item.amount.toStringAsFixed(3),
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            bottom:
                MediaQuery.viewInsetsOf(
              sheetContext,
            ).bottom,
          ),
          child: Container(
            padding: EdgeInsets.fromLTRB(
              22,
              14,
              22,
              MediaQuery.paddingOf(
                        sheetContext,
                      ).bottom +
                  22,
            ),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF10201C)
                  : Colors.white,
              borderRadius:
                  const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 45,
                    height: 5,
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white24
                          : Colors.black12,
                      borderRadius:
                          BorderRadius.circular(
                        10,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                Text(
                  "Edit item",
                  style: GoogleFonts
                      .ibmPlexSansArabic(
                    color: isDark
                        ? AppColors.darkText
                        : AppColors.lightText,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 17),

                TextField(
                  controller: nameController,
                  style: TextStyle(
                    color: isDark
                        ? AppColors.darkText
                        : AppColors.lightText,
                  ),
                  decoration: _inputDecoration(
                    hint: "Item name",
                    isDark: isDark,
                  ),
                ),

                const SizedBox(height: 12),

                TextField(
                  controller: amountController,
                  keyboardType:
                      const TextInputType
                          .numberWithOptions(
                    decimal: true,
                  ),
                  style: TextStyle(
                    color: isDark
                        ? AppColors.darkText
                        : AppColors.lightText,
                  ),
                  decoration: _inputDecoration(
                    hint: "Amount",
                    isDark: isDark,
                    suffixText: "JOD",
                  ),
                ),

                const SizedBox(height: 18),

                AppButton(
                  text: "Save Changes",
                  isDark: isDark,
                  width: double.infinity,
                  height: 50,
                  onPressed: () {
                    final name =
                        nameController.text.trim();

                    final amount = double.tryParse(
                      amountController.text.trim(),
                    );

                    if (name.isEmpty ||
                        amount == null ||
                        amount < 0) {
                      return;
                    }

                    context
                        .read<ReceiptProvider>()
                        .updateItem(
                          itemId: item.id,
                          name: name,
                          amount: amount,
                        );

                    Navigator.pop(sheetContext);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showDeleteItemDialog(
    BuildContext context,
    ReceiptItemModel item,
    bool isDark,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: isDark
              ? AppColors.darkBackground
              : AppColors.lightBackground,
          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(22),
          ),
          title: Text(
            "Remove item?",
            style:
                GoogleFonts.ibmPlexSansArabic(
              color: isDark
                  ? AppColors.darkText
                  : AppColors.lightText,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            item.name,
            style:
                GoogleFonts.ibmPlexSansArabic(
              color: isDark
                  ? AppColors.darkSubText
                  : AppColors.lightSubText,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                context
                    .read<ReceiptProvider>()
                    .removeItem(item.id);

                Navigator.pop(dialogContext);
              },
              child: const Text(
                "Remove",
                style: TextStyle(
                  color: Color(0xFFFF6B6B),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required bool isDark,
    String? suffixText,
  }) {
    return InputDecoration(
      hintText: hint,
      suffixText: suffixText,
      hintStyle: TextStyle(
        color: isDark
            ? AppColors.darkSubText
            : AppColors.lightSubText,
      ),
      filled: true,
      fillColor: isDark
          ? AppColors.darkBorder.withOpacity(0.40)
          : AppColors.lightBorder.withOpacity(0.40),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: isDark
              ? AppColors.darkPrimary
              : AppColors.lightPrimary,
        ),
      ),
    );
  }

  static IconData _categoryIcon(
    String category,
  ) {
    switch (category) {
      case "Groceries":
        return Icons.local_grocery_store_outlined;
      case "Food":
        return Icons.restaurant_outlined;
      case "Transport":
        return Icons.directions_car_outlined;
      case "Bills":
        return Icons.receipt_long_outlined;
      case "Health":
        return Icons.medical_services_outlined;
      case "Entertainment":
        return Icons.movie_outlined;
      case "Education":
        return Icons.school_outlined;
      default:
        return Icons.shopping_bag_outlined;
    }
  }
}

// =====================================================
// HEADER
// =====================================================

class _Header extends StatelessWidget {
  final bool isVoice;
  final bool isDark;

  const _Header({
    required this.isVoice,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                isVoice
                    ? "Expense recognized ✓"
                    : "Receipt recognized ✓",
                style: GoogleFonts
                    .ibmPlexSansArabic(
                  color: isDark
                      ? AppColors.darkText
                      : AppColors.lightText,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                isVoice
                    ? "via Speech Recognition + BASIRA AI"
                    : "via OCR + BASIRA AI",
                style: GoogleFonts
                    .ibmPlexSansArabic(
                  color: isDark
                      ? AppColors.darkSubText
                      : AppColors.lightSubText,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(width: 12),

        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              Navigator.pop(context);
            },
            borderRadius:
                BorderRadius.circular(12),
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.darkBorder.withOpacity(0.40)
                    : AppColors.lightBorder.withOpacity(0.40),
                borderRadius:
                    BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.close_rounded,
                color: isDark
                    ? AppColors.darkSubText
                    : AppColors.lightSubText,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// =====================================================
// CONFIDENCE
// =====================================================

class _ConfidenceCard extends StatelessWidget {
  final double confidence;
  final bool isVoice;
  final bool isDark;

  const _ConfidenceCard({
    required this.confidence,
    required this.isVoice,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final percentage =
        (confidence * 100).round();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkAccent.withOpacity(0.20)
            : AppColors.lightAccent.withOpacity(0.20),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark
              ? AppColors.darkAccent
              : AppColors.lightAccent,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: (isDark ? AppColors.darkAccent : AppColors.lightAccent).withOpacity(0.12),
                  borderRadius:
                      BorderRadius.circular(11),
                ),
                child: Icon(
                  isVoice
                      ? Icons.mic_rounded
                      : Icons.psychology_alt_rounded,
                  color: isDark ? AppColors.darkAccent : AppColors.lightAccent,
                  size: 21,
                ),
              ),

              const SizedBox(width: 11),

              Expanded(
                child: Text(
                  "Auto-extracted at $percentage% confidence",
                  style: GoogleFonts
                      .ibmPlexSansArabic(
                    color: isDark ? AppColors.darkAccent : AppColors.lightAccent,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 13),

          Text(
            "Review the data below and edit any field before confirming if needed.",
            style:
                GoogleFonts.ibmPlexSansArabic(
              color: isDark
                  ? AppColors.darkText
                  : AppColors.lightText,
              fontSize: 10,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

// =====================================================
// GENERAL INFO
// =====================================================

class _GeneralInfoCard extends StatelessWidget {
  final ParsedReceiptModel receipt;
  final bool isDark;
  final VoidCallback onStorePressed;
  final VoidCallback onDatePressed;
  final VoidCallback onCategoryPressed;

  const _GeneralInfoCard({
    required this.receipt,
    required this.isDark,
    required this.onStorePressed,
    required this.onDatePressed,
    required this.onCategoryPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 18,
        vertical: 14,
      ),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkPrimary.withOpacity(0.04)
            : AppColors.lightPrimary.withOpacity(0.04),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark
              ? AppColors.darkPrimary
              : AppColors.lightPrimary,
        ),
      ),
      child: Column(
        children: [
          _InfoRow(
            icon: Icons.storefront_outlined,
            label: "Store",
            value: receipt.storeName,
            isDark: isDark,
            onTap: onStorePressed,
          ),

          _Divider(isDark: isDark),

          _InfoRow(
            icon: Icons.calendar_month_outlined,
            label: "Date",
            value: DateFormat(
              "MMM d, yyyy",
            ).format(receipt.date),
            isDark: isDark,
            onTap: onDatePressed,
          ),

          _Divider(isDark: isDark),

          _InfoRow(
            icon: Icons.sell_outlined,
            label: "Suggested category",
            value: receipt.suggestedCategory,
            isDark: isDark,
            showAiBadge: true,
            onTap: onCategoryPressed,
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isDark;
  final bool showAiBadge;
  final VoidCallback onTap;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.isDark,
    required this.onTap,
    this.showAiBadge = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(13),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: 12,
        ),
        child: Row(
          children: [
            Container(
              width: 39,
              height: 39,
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.darkBorder.withOpacity(0.40)
                    : AppColors.lightBorder.withOpacity(0.40),
                borderRadius:
                    BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: isDark ? AppColors.darkAccent : AppColors.lightAccent,
                size: 20,
              ),
            ),

            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts
                        .ibmPlexSansArabic(
                      color: isDark
                          ? AppColors.darkText
                          : AppColors.lightText,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    value,
                    maxLines: 1,
                    overflow:
                        TextOverflow.ellipsis,
                    style: GoogleFonts
                        .ibmPlexSansArabic(
                      color: isDark
                          ? AppColors.darkSubText
                          : AppColors.lightSubText,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),

            if (showAiBadge)
              Container(
                margin:
                    const EdgeInsets.only(left: 8),
                padding:
                    const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: (isDark ? AppColors.darkPrimary : AppColors.lightPrimary)
                      .withOpacity(0.12),
                  borderRadius:
                      BorderRadius.circular(5),
                ),
                child: Text(
                  "Auto AI",
                  style: GoogleFonts
                      .ibmPlexSansArabic(
                    color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
                    fontSize: 9,
                  ),
                ),
              ),

            const SizedBox(width: 6),

            Icon(
              Icons.edit_outlined,
              color: isDark
                  ? AppColors.darkSubText
                  : AppColors.lightSubText,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  final bool isDark;

  const _Divider({
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      color: isDark
          ? Colors.white.withOpacity(0.05)
          : Colors.black.withOpacity(0.05),
    );
  }
}

// =====================================================
// ITEMS
// =====================================================

class _ItemsCard extends StatelessWidget {
  final List<ReceiptItemModel> items;
  final double total;
  final bool isDark;

  final ValueChanged<ReceiptItemModel>
      onEditItem;

  final ValueChanged<ReceiptItemModel>
      onRemoveItem;

  const _ItemsCard({
    required this.items,
    required this.total,
    required this.isDark,
    required this.onEditItem,
    required this.onRemoveItem,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkPrimary.withOpacity(0.04)
            : AppColors.lightPrimary.withOpacity(0.04),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark
              ? AppColors.darkPrimary
              : AppColors.lightPrimary,
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Text(
            "Extracted items (${items.length})",
            style:
                GoogleFonts.ibmPlexSansArabic(
              color: isDark
                  ? AppColors.darkText
                  : AppColors.lightText,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 13),

          ...items.map(
            (item) => _ReceiptItemRow(
              item: item,
              isDark: isDark,
              onEdit: () {
                onEditItem(item);
              },
              onRemove: () {
                onRemoveItem(item);
              },
            ),
          ),

          const SizedBox(height: 11),

          Divider(
            color: isDark
                ? Colors.white.withOpacity(0.08)
                : Colors.black.withOpacity(0.08),
          ),

          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(
                child: Text(
                  "Total",
                  style: GoogleFonts
                      .ibmPlexSansArabic(
                    color: isDark
                        ? AppColors.darkText
                        : AppColors.lightText,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              Text(
                "${total.toStringAsFixed(3)} JOD",
                style: GoogleFonts
                    .ibmPlexSansArabic(
                  color: isDark
                      ? AppColors.darkText
                      : AppColors.lightText,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReceiptItemRow extends StatelessWidget {
  final ReceiptItemModel item;
  final bool isDark;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  const _ReceiptItemRow({
    required this.item,
    required this.isDark,
    required this.onEdit,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        bottom: 4,
      ),
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(11),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: 11,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: GoogleFonts
                          .ibmPlexSansArabic(
                        color: isDark
                            ? AppColors.darkText
                            : AppColors.lightText,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (item.category
                        .trim()
                        .isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        item.category,
                        style: GoogleFonts
                            .ibmPlexSansArabic(
                          color: isDark
                              ? AppColors
                                  .darkSubText
                              : AppColors
                                  .lightSubText,
                          fontSize: 9,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              Text(
                item.amount.toStringAsFixed(3),
                style: GoogleFonts
                    .ibmPlexSansArabic(
                  color: isDark
                      ? AppColors.darkText
                      : AppColors.lightText,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(width: 7),

              PopupMenuButton<String>(
                padding: EdgeInsets.zero,
                iconSize: 19,
                color: isDark
                    ? AppColors.darkBorder.withOpacity(0.40)
                    : AppColors.lightBorder.withOpacity(0.40),
                icon: Icon(
                  Icons.more_vert_rounded,
                  color: isDark
                      ? AppColors.darkSubText
                      : AppColors.lightSubText,
                ),
                onSelected: (value) {
                  if (value == "edit") {
                    onEdit();
                  } else if (value ==
                      "remove") {
                    onRemove();
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: "edit",
                    child: Row(
                      children: [
                        Icon(
                          Icons.edit_outlined,
                          size: 19,
                        ),
                        SizedBox(width: 9),
                        Text("Edit"),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: "remove",
                    child: Row(
                      children: [
                        Icon(
                          Icons.delete_outline,
                          color:
                              Color(0xFFFF6B6B),
                          size: 19,
                        ),
                        SizedBox(width: 9),
                        Text(
                          "Remove",
                          style: TextStyle(
                            color:
                                Color(0xFFFF6B6B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =====================================================
// NO RESULT
// =====================================================

class _NoReceiptView extends StatelessWidget {
  final bool isDark;

  const _NoReceiptView({
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.receipt_long_outlined,
                color: Color(0xFF34D399),
                size: 55,
              ),
              const SizedBox(height: 14),
              Text(
                "No receipt data found",
                style: GoogleFonts
                    .ibmPlexSansArabic(
                  color: isDark
                      ? AppColors.darkText
                      : AppColors.lightText,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 15),
              AppButton(
                text: "Go Back",
                isDark: isDark,
                width: 170,
                height: 50,
                onPressed: () {
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}