import 'package:alpha_app/core/utils/app_colors.dart';
import 'package:alpha_app/core/utils/device.dart';
import 'package:alpha_app/models/expense_model.dart';
import 'package:alpha_app/providers/expense_provider.dart';
import 'package:alpha_app/providers/themeprovider.dart';
import 'package:alpha_app/screens/expenses/expense_date_screen.dart';
import 'package:alpha_app/screens/main_screen.dart';
import 'package:alpha_app/widgets/custom_textfield.dart';
import 'package:alpha_app/widgets/multi_select_chip.dart';
import 'package:alpha_app/widgets/option_chip.dart';
import 'package:alpha_app/widgets/app_button.dart';
import 'package:alpha_app/screens/receipts/receipt_input_screen.dart';
import 'package:alpha_app/screens/voice/voice_record_screen.dart';
import 'package:alpha_app/core/utils/dashboard_action_result.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class NewExpenseScreen extends StatefulWidget {
  final ExpenseModel? expenseToEdit;

  const NewExpenseScreen({
    super.key,
    this.expenseToEdit,
  });

  @override
  State<NewExpenseScreen> createState() => _NewExpenseScreenState();
}

class _NewExpenseScreenState extends State<NewExpenseScreen> {
  bool _formPrepared = false;

  bool get _isEditing => widget.expenseToEdit != null;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _formPrepared) {
        return;
      }

      _formPrepared = true;

      final provider = context.read<ExpenseProvider>();

      if (widget.expenseToEdit != null) {
        provider.prepareExpenseForEditing(
          widget.expenseToEdit!,
        );
      } else {
        provider.clearForm();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ExpenseProvider>();

    final themeProvider = context.watch<Themeprovider>();

    final bool isDark = themeProvider.isDark;

    final double screenW = Device.width(context);

    final double screenH = Device.height(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (
        didPop,
        result,
      ) {
        if (!didPop) {
          _closeScreen();
        }
      },
      child: Scaffold(
        backgroundColor:
            isDark ? AppColors.darkBackground : AppColors.lightBackground,
        body: SafeArea(
          child: Stack(
            children: [
              SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.symmetric(
                  horizontal: screenW * 0.05,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: screenH * 0.022,
                    ),

                    _buildHeader(
                      isDark: isDark,
                      screenW: screenW,
                    ),

                    SizedBox(
                      height: screenH * 0.012,
                    ),

                    Text(
                      _isEditing
                          ? "Update the expense details below."
                          : "Record the expense accurately so Alpha can analyze its effect on your budget.",
                      style: GoogleFonts.ibmPlexSansArabic(
                        color: isDark
                            ? AppColors.darkSubText
                            : AppColors.lightSubText,
                        fontSize: screenW * 0.034,
                        fontWeight: FontWeight.w500,
                        height: 1.5,
                      ),
                    ),

                    SizedBox(
                      height: screenH * 0.03,
                    ),

                    if (!_isEditing) ...[
                      _SectionTitle(
                        title: "Input Method",
                        screenW: screenW,
                        isDark: isDark,
                      ),
                      SizedBox(height: screenH * 0.012),
                      Row(
                        children: [
                          Expanded(
                            child: _InputOptionCard(
                              icon: Icons.edit_note,
                              title: "Manual",
                              isSelected: true,
                              isDark: isDark,
                              onTap: () {}, // Already here
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _InputOptionCard(
                              icon: Icons.document_scanner_outlined,
                              title: "Receipt",
                              isSelected: false,
                              isDark: isDark,
                              onTap: () async {
                                final result = await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          const ReceiptInputScreen()),
                                );
                                if (result == DashboardActionResult.created && mounted) {
                                  Navigator.pop(context, DashboardActionResult.created);
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _InputOptionCard(
                              icon: Icons.mic_none,
                              title: "Voice",
                              isSelected: false,
                              isDark: isDark,
                              onTap: () async {
                                final result = await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          const VoiceRecordScreen()),
                                );
                                if (result == DashboardActionResult.created && mounted) {
                                  Navigator.pop(context, DashboardActionResult.created);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: screenH * 0.03),
                    ],

                    // ================= MOVEMENT TYPE =================

                    _SectionTitle(
                      title: "Movement type",
                      screenW: screenW,
                      isDark: isDark,
                    ),

                    SizedBox(
                      height: screenH * 0.012,
                    ),

                    OptionChip(
                      items: provider.movementTypes,
                      selected: provider.movementTypeLabel,
                      onTap: provider.setMovementTypeByLabel,
                    ),

                    SizedBox(
                      height: screenH * 0.022,
                    ),

                    // ================= NEED / WANT =================

                    _SectionTitle(
                      title: "Expense type",
                      screenW: screenW,
                      isDark: isDark,
                    ),

                    SizedBox(
                      height: screenH * 0.012,
                    ),

                    OptionChip(
                      items: const [
                        "Need",
                        "Want",
                      ],
                      selected: provider.expenseType == ExpenseType.need
                          ? "Need"
                          : (provider.expenseType == ExpenseType.want
                              ? "Want"
                              : null),
                      onTap: (value) {
                        provider.setExpenseType(
                          value == "Need" ? ExpenseType.need : ExpenseType.want,
                        );
                      },
                    ),

                    SizedBox(
                      height: screenH * 0.022,
                    ),

                    // ================= CATEGORY =================

                    _SectionTitle(
                      title: "Category",
                      screenW: screenW,
                      isDark: isDark,
                    ),

                    SizedBox(
                      height: screenH * 0.012,
                    ),

                    if (provider.expenseType == null)
                      Text(
                        "Select an expense type to view categories.",
                        style: GoogleFonts.ibmPlexSansArabic(
                          color: isDark
                              ? AppColors.darkSubText
                              : AppColors.lightSubText,
                          fontSize: screenW * 0.035,
                        ),
                      )
                    else
                      MultiSelectChip(
                        items: provider.categories,
                        selectedItems: provider.selectedCategory == null
                            ? []
                            : [
                                provider.selectedCategory!,
                              ],
                        onTap: provider.setCategory,
                      ),

                    if (provider.selectedCategory == "Other") ...[
                      SizedBox(
                        height: screenH * 0.018,
                      ),
                      CustomTextfield(
                        controller: provider.customCategoryController,
                        hint: "Enter category name",
                        type: TextFieldType.name,
                        icon: Icons.category_outlined,
                        onChanged: (_) {
                          provider.notifyExpenseFormChanged();
                        },
                      ),
                    ],

                    SizedBox(
                      height: screenH * 0.025,
                    ),

                    // ================= EXPENSE NAME =================

                    _SectionTitle(
                      title: "Expense name",
                      screenW: screenW,
                      isDark: isDark,
                    ),

                    SizedBox(
                      height: screenH * 0.01,
                    ),

                    CustomTextfield(
                      controller: provider.titleController,
                      hint: "Enter expense name",
                      type: TextFieldType.name,
                      icon: Icons.receipt_long_outlined,
                      onChanged: (_) {
                        provider.notifyExpenseFormChanged();
                      },
                    ),

                    SizedBox(
                      height: screenH * 0.022,
                    ),

                    // ================= AMOUNT =================

                    _SectionTitle(
                      title: "Amount",
                      screenW: screenW,
                      isDark: isDark,
                    ),

                    SizedBox(
                      height: screenH * 0.01,
                    ),

                    CustomTextfield(
                      controller: provider.amountController,
                      hint: "Enter amount",
                      type: TextFieldType.number,
                      icon: Icons.payments_outlined,
                      suffix: const Padding(
                        padding: EdgeInsets.all(12),
                        child: Text("JOD"),
                      ),
                      onChanged: (_) {
                        provider.notifyExpenseFormChanged();
                      },
                    ),

                    SizedBox(
                      height: screenH * 0.022,
                    ),

                    // ================= RECURRING FIELDS =================

                    if (provider.isRecurring) ...[
                      _SectionTitle(
                        title: "Coverage period",
                        screenW: screenW,
                        isDark: isDark,
                      ),
                      SizedBox(
                        height: screenH * 0.012,
                      ),
                      MultiSelectChip(
                        items: provider.coveragePeriods,
                        selectedItems: provider.coveragePeriodLabel == null
                            ? []
                            : [
                                provider.coveragePeriodLabel!,
                              ],
                        onTap: provider.setCoveragePeriodByLabel,
                      ),
                      SizedBox(
                        height: screenH * 0.022,
                      ),
                      _SectionTitle(
                        title: "Flexibility",
                        screenW: screenW,
                        isDark: isDark,
                      ),
                      SizedBox(
                        height: screenH * 0.012,
                      ),
                      OptionChip(
                        items: provider.flexibilities,
                        selected: provider.flexibility,
                        onTap: provider.setFlexibility,
                      ),
                      SizedBox(
                        height: screenH * 0.022,
                      ),
                    ] else ...[
                      // ================= PAYMENT METHOD =================
                      _SectionTitle(
                        title: "Payment method",
                        screenW: screenW,
                        isDark: isDark,
                      ),
                      SizedBox(
                        height: screenH * 0.012,
                      ),
                      OptionChip(
                        items: provider.paymentMethods,
                        selected: provider.paymentMethod,
                        onTap: provider.setPaymentMethod,
                      ),
                      SizedBox(
                        height: screenH * 0.022,
                      ),
                    ],

                    // ================= DATE =================

                    _SectionTitle(
                      title: provider.isRecurring
                          ? "Next Due Date"
                          : "Transaction Date",
                      screenW: screenW,
                      isDark: isDark,
                    ),

                    SizedBox(
                      height: screenH * 0.01,
                    ),

                    CustomTextfield(
                      controller: provider.dateController,
                      hint: provider.isRecurring
                          ? "Select due date"
                          : "Select transaction date",
                      type: TextFieldType.date,
                      icon: Icons.calendar_month_outlined,
                      readOnly: true,
                      onTap: () async {
                        final selectedDate = await Navigator.push<DateTime>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ExpenseDateScreen(
                              initialDate: provider.selectedDate,
                              isRecurring: provider.isRecurring,
                            ),
                          ),
                        );

                        if (selectedDate == null || !context.mounted) {
                          return;
                        }

                        provider.setDate(
                          selectedDate,
                        );
                      },
                    ),

                    SizedBox(
                      height: screenH * 0.022,
                    ),

                    // ================= NOTE =================

                    _SectionTitle(
                      title: "Note (optional)",
                      screenW: screenW,
                      isDark: isDark,
                    ),

                    SizedBox(
                      height: screenH * 0.01,
                    ),

                    CustomTextfield(
                      controller: provider.noteController,
                      hint: "Add a note",
                      type: TextFieldType.name,
                      icon: Icons.notes_rounded,
                      onChanged: (_) {
                        provider.notifyExpenseFormChanged();
                      },
                    ),

                    SizedBox(
                      height: screenH * 0.03,
                    ),

                    // ================= DISABLED REASON =================

                    if (!provider.isValid) ...[
                      Padding(
                        padding: EdgeInsets.only(bottom: screenH * 0.015),
                        child: Text(
                          provider.validationMessage ?? "",
                          style: GoogleFonts.ibmPlexSansArabic(
                            color: isDark
                                ? AppColors.darkError
                                : AppColors.lightError,
                            fontSize: screenW * 0.035,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],

                    // ================= SAVE BUTTON =================

                    AppButton(
                      text: _isEditing
                          ? "Save Changes"
                          : provider.isShoppingSessionActive
                              ? "Add to Session"
                              : "Add Expense",
                      isDark: isDark,
                      isLoading: provider.isSaving,
                      width: double.infinity,
                      height: screenH * 0.065,
                      onPressed: () async {
                        FocusScope.of(context).unfocus();

                        provider.clearError();

                        if (!provider.isValid) {
                          ScaffoldMessenger.of(context)
                            ..hideCurrentSnackBar()
                            ..showSnackBar(
                              SnackBar(
                                content: Text(
                                  "Please complete all required fields",
                                  style: GoogleFonts.ibmPlexSansArabic(
                                    fontSize: screenW * 0.04,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                backgroundColor: isDark
                                    ? AppColors.darkError
                                    : AppColors.lightError,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );

                          return;
                        }

                        final bool wasEditing = _isEditing;

                        final bool addedToSession =
                            provider.isShoppingSessionActive && !wasEditing;

                        final bool saved = await provider.saveCurrentExpense();

                        if (!mounted) {
                          return;
                        }

                        if (provider.errorMessage ==
                                'NO_ACTIVE_FINANCIAL_CYCLE' ||
                            provider.errorMessage == 'CYCLE_NOT_FOUND') {
                          _showNoActiveCycleDialog(context, provider);
                          return;
                        }

                        if (!saved) {
                          ScaffoldMessenger.of(context)
                            ..hideCurrentSnackBar()
                            ..showSnackBar(
                              SnackBar(
                                content: Text(
                                  "Could not save expense",
                                  style: GoogleFonts.ibmPlexSansArabic(
                                    fontSize: screenW * 0.04,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                backgroundColor: isDark
                                    ? AppColors.darkError
                                    : AppColors.lightError,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );

                          return;
                        }

                        ScaffoldMessenger.of(context)
                          ..hideCurrentSnackBar()
                          ..showSnackBar(
                            SnackBar(
                              content: Text(
                                wasEditing
                                    ? "Expense updated successfully"
                                    : addedToSession
                                        ? "Expense added to shopping session"
                                        : "Expense added successfully",
                                style: GoogleFonts.ibmPlexSansArabic(
                                  fontSize: screenW * 0.04,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              backgroundColor: isDark
                                  ? AppColors.darkSecondary
                                  : AppColors.lightSecondary,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );

                        Navigator.pop(
                          context,
                          DashboardActionResult.created,
                        );
                      },
                    ),

                    SizedBox(
                      height: screenH * 0.03,
                    ),
                  ],
                ),
              ),
              if (provider.isSaving)
                Positioned.fill(
                  child: AbsorbPointer(
                    child: Container(
                      color: Colors.black.withOpacity(0.15),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader({
    required bool isDark,
    required double screenW,
  }) {
    return Row(
      children: [
        InkWell(
          onTap: _closeScreen,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: screenW * 0.11,
            height: screenW * 0.11,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF203330) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark
                    ? Colors.white.withOpacity(0.04)
                    : Colors.black.withOpacity(0.05),
              ),
            ),
            child: Icon(
              Icons.arrow_back_ios_new_rounded,
              color: isDark ? AppColors.darkText : AppColors.lightText,
              size: screenW * 0.05,
            ),
          ),
        ),
        SizedBox(
          width: screenW * 0.035,
        ),
        Expanded(
          child: Text(
            _isEditing ? "Edit Expense" : "Add Expense",
            style: GoogleFonts.ibmPlexSansArabic(
              color: isDark ? AppColors.darkText : AppColors.lightText,
              fontSize: screenW * 0.065,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _selectDate({
    required ExpenseProvider provider,
    required bool isDark,
  }) async {
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: provider.selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (
        context,
        child,
      ) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.fromSeed(
              seedColor:
                  isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
              brightness: isDark ? Brightness.dark : Brightness.light,
            ),
          ),
          child: child!,
        );
      },
    );

    if (selectedDate == null || !mounted) {
      return;
    }

    provider.setDate(selectedDate);
  }

  void _closeScreen() {
    context.read<ExpenseProvider>().clearForm();

    Navigator.pop(context);
  }

  void _showNoActiveCycleDialog(
      BuildContext context, ExpenseProvider provider) {
    showModalBottomSheet(
        context: context,
        isDismissible: false,
        enableDrag: false,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        builder: (ctx) {
          return StatefulBuilder(builder: (context, setState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final screenW = Device.width(context);
            final screenH = Device.height(context);

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.all(screenW * 0.05),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      "No Active Financial Cycle",
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: screenW * 0.05,
                        fontWeight: FontWeight.bold,
                        color:
                            isDark ? AppColors.darkText : AppColors.lightText,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: screenH * 0.015),
                    Text(
                      "Start a financial cycle before adding transactions.",
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: screenW * 0.04,
                        fontWeight: FontWeight.w500,
                        color: isDark
                            ? AppColors.darkSubText
                            : AppColors.lightSubText,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: screenH * 0.03),
                    AppButton(
                      text: "Start Financial Cycle",
                      isDark: isDark,
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const MainNavigationScreen(),
                          ),
                          (route) => false,
                        );
                      },
                    ),
                    SizedBox(height: screenH * 0.015),
                    AppButton(
                      text: "Cancel",
                      isDark: isDark,
                      onPressed: () {
                        Navigator.pop(ctx);
                      },
                    ),
                  ],
                ),
              ),
            );
          });
        });
  }
}

// =====================================================
// SECTION TITLE
// =====================================================

class _SectionTitle extends StatelessWidget {
  final String title;
  final double screenW;
  final bool isDark;

  const _SectionTitle({
    required this.title,
    required this.screenW,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: GoogleFonts.ibmPlexSansArabic(
        fontSize: screenW * 0.04,
        color: isDark ? AppColors.darkSubText : AppColors.lightSubText,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}

// =====================================================
// INPUT OPTION CARD
// =====================================================

class _InputOptionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  const _InputOptionCard({
    required this.icon,
    required this.title,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isSelected
        ? (isDark ? AppColors.darkPrimary : AppColors.lightPrimary)
        : (isDark ? AppColors.darkBorder : AppColors.lightBorder);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withOpacity(0.1)
              : (isDark ? AppColors.darkBackground : AppColors.lightBackground),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              title,
              style: GoogleFonts.ibmPlexSansArabic(
                color: isSelected
                    ? color
                    : (isDark ? AppColors.darkSubText : AppColors.lightSubText),
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
