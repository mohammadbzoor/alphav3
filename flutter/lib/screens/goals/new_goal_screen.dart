import 'package:alpha_app/core/utils/app_colors.dart';
import 'package:alpha_app/core/utils/device.dart';
import 'package:alpha_app/providers/goal_provider.dart';
import 'package:alpha_app/providers/themeprovider.dart';
import 'package:alpha_app/screens/goals/goal_date.dart';
import 'package:alpha_app/widgets/app_button.dart';
import 'package:alpha_app/widgets/custom_textfield.dart';
import 'package:alpha_app/widgets/goals/priority_card.dart';
import 'package:alpha_app/widgets/multi_select_chip.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class NewGoalScreen extends StatefulWidget {
  const NewGoalScreen({
    super.key,
  });

  @override
  State<NewGoalScreen> createState() => _NewGoalScreenState();
}

class _NewGoalScreenState extends State<NewGoalScreen> {
  bool _formPrepared = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _formPrepared) {
        return;
      }

      _formPrepared = true;

      context.read<GoalProvider>().clearForm();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GoalProvider>();

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
                      "Set a realistic financial goal and Alpha will help you track your progress.",
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

                    // ================= GOAL CATEGORY =================

                    _SectionTitle(
                      title: "Choose your goal",
                      screenW: screenW,
                      isDark: isDark,
                    ),

                    SizedBox(
                      height: screenH * 0.012,
                    ),

                    MultiSelectChip(
                      items: provider.goalCategories,
                      selectedItems: provider.selectedCategory == null
                          ? []
                          : [
                              provider.selectedCategory!,
                            ],
                      onTap: provider.setCategory,
                    ),

                    // ================= CUSTOM GOAL NAME =================

                    if (provider.selectedCategory == "Other") ...[
                      SizedBox(
                        height: screenH * 0.022,
                      ),
                      _SectionTitle(
                        title: "Goal name",
                        screenW: screenW,
                        isDark: isDark,
                      ),
                      SizedBox(
                        height: screenH * 0.01,
                      ),
                      CustomTextfield(
                        controller: provider.customNameController,
                        hint: "Enter goal name",
                        type: TextFieldType.name,
                        icon: Icons.flag_outlined,
                        onChanged: (_) {
                          provider.refresh();
                        },
                      ),
                    ],

                    SizedBox(
                      height: screenH * 0.025,
                    ),

                    // ================= MONTHLY SAVING =================

                    _SectionTitle(
                      title: "Monthly saving amount",
                      screenW: screenW,
                      isDark: isDark,
                    ),

                    SizedBox(
                      height: screenH * 0.01,
                    ),

                    CustomTextfield(
                      controller: provider.amountController,
                      hint: "Amount per month",
                      type: TextFieldType.number,
                      icon: Icons.payments_outlined,
                      suffix: Padding(
                        padding: const EdgeInsets.all(
                          12,
                        ),
                        child: Text(
                          "JOD",
                          style: TextStyle(
                            color: isDark
                                ? AppColors.darkSubText
                                : AppColors.lightSubText,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      onChanged: (_) {
                        provider.refresh();
                      },
                    ),

                    SizedBox(
                      height: screenH * 0.025,
                    ),

                    // ================= PRIORITY =================

                    _SectionTitle(
                      title: "Priority",
                      screenW: screenW,
                      isDark: isDark,
                    ),

                    SizedBox(
                      height: screenH * 0.012,
                    ),

                    PriorityCard(
                      priority: provider.priority,
                      isDark: isDark,
                      screenW: screenW,
                      onChanged: (value) {
                        provider.setPriority(
                          value.toInt(),
                        );
                      },
                    ),

                    SizedBox(
                      height: screenH * 0.025,
                    ),

                    // ================= TARGET DATE =================

                    _SectionTitle(
                      title: "Target date",
                      screenW: screenW,
                      isDark: isDark,
                    ),

                    SizedBox(
                      height: screenH * 0.01,
                    ),

                    CustomTextfield(
                      controller: provider.targetDateController,
                      hint: "Select your target date",
                      icon: Icons.calendar_month_outlined,
                      type: TextFieldType.date,
                      readOnly: true,
                      onTap: () {
                        _selectGoalDate(
                          provider,
                        );
                      },
                    ),

                    SizedBox(
                      height: screenH * 0.025,
                    ),

                    // ================= ALPHA PREVIEW =================

                    _AlphaGoalPreviewCard(
                      provider: provider,
                      isDark: isDark,
                      screenW: screenW,
                    ),

                    if (provider.errorMessage != null) ...[
                      SizedBox(
                        height: screenH * 0.018,
                      ),
                      _ErrorCard(
                        message: provider.errorMessage!,
                        onClose: provider.clearError,
                      ),
                    ],

                    SizedBox(
                      height: screenH * 0.03,
                    ),

                    // ================= SAVE BUTTON =================

                    Center(
                      child: AppButton(
                        text: "Add Goal",
                        isDark: isDark,
                        isLoading: provider.isSaving,
                        width: double.infinity,
                        height: screenH * 0.065,
                        onPressed: () async {
                          if (!provider.isValid) {
                            ScaffoldMessenger.of(context)
                              ..hideCurrentSnackBar()
                              ..showSnackBar(
                                SnackBar(
                                  backgroundColor: isDark
                                      ? AppColors.darkError
                                      : AppColors.lightError,
                                  content: Text(
                                    "Please complete all required fields",
                                    style: GoogleFonts.ibmPlexSansArabic(
                                      fontSize: screenW * 0.04,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );

                            return;
                          }

                          final bool saved = await provider.saveCurrentGoal();

                          if (!context.mounted) {
                            return;
                          }

                          if (!saved) {
                            ScaffoldMessenger.of(context)
                              ..hideCurrentSnackBar()
                              ..showSnackBar(
                                SnackBar(
                                  backgroundColor: isDark
                                      ? AppColors.darkError
                                      : AppColors.lightError,
                                  content: Text(
                                    provider.errorMessage ??
                                        "Could not save goal",
                                    style: GoogleFonts.ibmPlexSansArabic(
                                      fontSize: screenW * 0.04,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );

                            return;
                          }

                          ScaffoldMessenger.of(context)
                            ..hideCurrentSnackBar()
                            ..showSnackBar(
                              SnackBar(
                                backgroundColor: isDark
                                    ? AppColors.darkSecondary
                                    : AppColors.lightSecondary,
                                content: Text(
                                  "Goal added successfully",
                                  style: GoogleFonts.ibmPlexSansArabic(
                                    fontSize: screenW * 0.04,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );

                          Navigator.pop(
                            context,
                            true,
                          );
                        },
                      ),
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

  // =====================================================
  // HEADER
  // =====================================================

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
              color: isDark ? AppColors.darkBorder : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
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
            "Add Goal",
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

  // =====================================================
  // DATE
  // =====================================================

  Future<void> _selectGoalDate(
    GoalProvider provider,
  ) async {
    final dynamic selectedDate = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GoalDateScreen(
          initialDate: provider.targetDate,
        ),
      ),
    );

    if (!mounted || selectedDate == null || selectedDate is! DateTime) {
      return;
    }

    provider.setDate(selectedDate);
  }

  // =====================================================
  // CLOSE
  // =====================================================

  void _closeScreen() {
    context.read<GoalProvider>().clearForm();

    Navigator.pop(context);
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
// ALPHA GOAL PREVIEW
// =====================================================

class _AlphaGoalPreviewCard extends StatelessWidget {
  final GoalProvider provider;
  final bool isDark;
  final double screenW;

  const _AlphaGoalPreviewCard({
    required this.provider,
    required this.isDark,
    required this.screenW,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkSecondary.withOpacity(0.10)
            : AppColors.lightSecondary.withOpacity(0.10),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: isDark
              ? AppColors.darkSecondary.withOpacity(0.18)
              : AppColors.lightSecondary.withOpacity(0.18),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.darkPrimary.withOpacity(0.12)
                  : AppColors.lightPrimary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.auto_awesome_rounded,
              color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Alpha Preview",
                  style: GoogleFonts.ibmPlexSansArabic(
                    color:
                        isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
                    fontSize: screenW * 0.036,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _buildMessage(),
                  style: GoogleFonts.ibmPlexSansArabic(
                    color: isDark ? AppColors.darkText : AppColors.lightText,
                    fontSize: screenW * 0.032,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _buildMessage() {
    if (provider.selectedCategory == null) {
      return "Choose a goal to receive a personalized saving suggestion.";
    }

    if (provider.monthlySaving <= 0) {
      return "Enter a realistic monthly saving amount so Alpha can evaluate your plan.";
    }

    if (provider.targetDate == null) {
      return "Select a target date to complete your goal plan.";
    }

    if (provider.priority >= 8) {
      return "This is a high-priority goal. Alpha will give it more importance when analyzing your spending.";
    }

    if (provider.monthlySaving < 20) {
      return "Your monthly saving amount is relatively low. Reaching the goal may take more time.";
    }

    return "Your goal setup looks realistic. Alpha will track your progress and help you stay consistent.";
  }
}

// =====================================================
// ERROR CARD
// =====================================================

class _ErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback onClose;

  const _ErrorCard({
    required this.message,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDark = context.watch<Themeprovider>().isDark;

    final Color errorColor =
        isDark ? AppColors.darkError : AppColors.lightError;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(
        left: 13,
        top: 8,
        bottom: 8,
      ),
      decoration: BoxDecoration(
        color: errorColor.withOpacity(0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: errorColor.withOpacity(0.18),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline_rounded,
            color: errorColor,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.ibmPlexSansArabic(
                color: errorColor,
              ),
            ),
          ),
          IconButton(
            onPressed: onClose,
            icon: Icon(
              Icons.close_rounded,
              color: errorColor,
              size: 18,
            ),
          ),
        ],
      ),
    );
  }
}
