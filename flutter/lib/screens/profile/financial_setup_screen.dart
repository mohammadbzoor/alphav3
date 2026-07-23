import 'package:alpha_app/core/utils/app_colors.dart';
import 'package:alpha_app/core/utils/device.dart';
import 'package:alpha_app/providers/financial_setup_provider.dart';
import 'package:alpha_app/providers/onboarding_provider.dart';
import 'package:alpha_app/providers/themeprovider.dart';
import 'package:alpha_app/widgets/custom_textfield.dart';
import 'package:alpha_app/core/utils/step_resolver.dart';
import 'package:alpha_app/widgets/option_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';
import 'package:provider/provider.dart';

class FinancialSetupScreen extends StatefulWidget {
  const FinancialSetupScreen({super.key});

  @override
  State<FinancialSetupScreen> createState() => _FinancialSetupScreenState();
}

class _FinancialSetupScreenState extends State<FinancialSetupScreen> {
  bool _isNavigating = false;

  final _decimalFormatter =
      FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'));

  void _showSalaryDayPicker(
      BuildContext context, FinancialProvider provider, bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Select Salary Payment Day",
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color:
                            isDark ? AppColors.darkText : AppColors.lightText,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close,
                          color: isDark
                              ? AppColors.darkSubText
                              : AppColors.lightSubText),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  "Choose the day you usually receive your salary.",
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 14,
                    color:
                        isDark ? AppColors.darkSubText : AppColors.lightSubText,
                  ),
                ),
                const SizedBox(height: 20),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 1,
                  ),
                  itemCount: 31,
                  itemBuilder: (context, index) {
                    final day = index + 1;
                    final isSelected = provider.paymentDay == day;
                    return InkWell(
                      onTap: () {
                        provider.setPaymentDay(day);
                        Navigator.pop(ctx);
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Semantics(
                        label: "Salary payment day $day",
                        child: Container(
                          decoration: BoxDecoration(
                            color: isSelected
                                ? (isDark
                                    ? AppColors.darkPrimary
                                    : AppColors.lightPrimary)
                                : (isDark
                                    ? AppColors.darkCard
                                    : AppColors.lightCard),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isSelected
                                  ? (isDark
                                      ? AppColors.darkPrimary
                                      : AppColors.lightPrimary)
                                  : (isDark
                                      ? AppColors.darkBorder
                                      : AppColors.lightBorder),
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            day.toString(),
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: 16,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: isSelected
                                  ? Colors.white
                                  : (isDark
                                      ? AppColors.darkText
                                      : AppColors.lightText),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenW = Device.width(context);
    final screenH = Device.height(context);
    final themeProvider = Provider.of<Themeprovider>(context);
    final isDark = themeProvider.isDark;
    final financialProvider = context.watch<FinancialProvider>();
    final onboardingProvider = context.watch<OnboardingProvider>();

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
              horizontal: screenW * 0.05, vertical: screenH * 0.03),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Title and Progress
              Text(
                "Step 2 of 2",
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: screenW * 0.04,
                  fontWeight: FontWeight.w500,
                  color: isDark ? AppColors.darkAccent : AppColors.lightAccent,
                ),
              ),
              SizedBox(height: screenH * 0.02),
              Text(
                "Financial Information",
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: screenW * 0.075,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.darkText : AppColors.lightText,
                ),
              ),
              SizedBox(height: screenH * 0.01),
              Text(
                "Accurate data means sharper advice from Alpha",
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: screenW * 0.035,
                  fontWeight: FontWeight.w500,
                  color:
                      isDark ? AppColors.darkSubText : AppColors.lightSubText,
                ),
              ),
              SizedBox(height: screenH * 0.02),
              LinearPercentIndicator(
                lineHeight: screenH * 0.02,
                percent: financialProvider.pageProgress,
                padding: EdgeInsets.zero,
                backgroundColor:
                    isDark ? AppColors.darkBorder : AppColors.lightBorder,
                progressColor:
                    isDark ? AppColors.darkSecondary : AppColors.lightSecondary,
                barRadius: const Radius.circular(10),
              ),
              SizedBox(height: screenH * 0.03),

              // 2. Relationship with money
              _SectionTitle("How do you describe your relationship with money?",
                  isDark: isDark, screenW: screenW),
              SizedBox(height: screenH * 0.01),
              OptionChip(
                items: const [
                  "Careful spending",
                  "Balanced spending",
                  "Emotional spending"
                ],
                selected: financialProvider.moneyRelationshipDisplay,
                onTap: financialProvider.setMoneyRelationship,
              ),
              SizedBox(height: screenH * 0.03),

              // 3. Regular Monthly Salary
              _SectionTitle("Regular Monthly Salary",
                  isDark: isDark, screenW: screenW),
              const SizedBox(height: 4),
              Text(
                "Enter the fixed salary you expect to receive each month.",
                style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 13,
                    color: isDark
                        ? AppColors.darkSubText
                        : AppColors.lightSubText),
              ),
              SizedBox(height: screenH * 0.01),
              CustomTextfield(
                controller: financialProvider.regularSalaryController,
                hint: "Enter monthly salary",
                type: TextFieldType.number,
                inputFormatters: [_decimalFormatter],
                suffix: const Padding(
                    padding: EdgeInsets.all(12), child: Text("JOD")),
                onChanged: financialProvider.setRegularSalary,
              ),
              SizedBox(height: screenH * 0.03),

              // 4. Additional Expected Monthly Income
              _SectionTitle("Additional Expected Monthly Income",
                  isDark: isDark, screenW: screenW),
              const SizedBox(height: 4),
              Text(
                "Enter only income that is separate from your regular salary and expected every month.",
                style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 13,
                    color: isDark
                        ? AppColors.darkSubText
                        : AppColors.lightSubText),
              ),
              SizedBox(height: screenH * 0.01),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 2.0),
                child: Row(
                  children: financialProvider.incomeSources
                      .asMap()
                      .entries
                      .map((entry) {
                    final index = entry.key;
                    final item = entry.value;
                    return Padding(
                      padding: EdgeInsets.only(
                          right: index !=
                                  financialProvider.incomeSources.length - 1
                              ? 10.0
                              : 0),
                      child: ChoiceChip(
                        label: Text(item.name == "Temporary Job"
                            ? "Recurring Side Income"
                            : item.name),
                        selected: item.selected,
                        onSelected: (_) => financialProvider.toggleIncome(item),
                        selectedColor: (isDark
                                ? AppColors.darkSecondary
                                : AppColors.lightSecondary)
                            .withValues(alpha: 0.04),
                        backgroundColor: (isDark
                                ? AppColors.darkSubText
                                : AppColors.lightSubText)
                            .withValues(alpha: 0.4),
                        side: BorderSide(
                          color: item.selected
                              ? (isDark
                                  ? AppColors.darkPrimary
                                  : AppColors.lightPrimary)
                              : Colors.transparent,
                        ),
                        labelStyle: TextStyle(
                          color: item.selected
                              ? (isDark
                                  ? AppColors.darkPrimary
                                  : AppColors.lightPrimary)
                              : (isDark
                                  ? AppColors.darkSubText
                                  : AppColors.lightSubText),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              SizedBox(height: screenH * 0.01),
              ...financialProvider.incomeSources
                  .where((e) => e.selected)
                  .map((item) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10.0),
                  child: CustomTextfield(
                    controller: item.controller,
                    hint: "Additional monthly amount",
                    type: TextFieldType.number,
                    inputFormatters: [_decimalFormatter],
                    suffix: const Padding(
                        padding: EdgeInsets.all(12), child: Text("JOD")),
                    onChanged: (val) =>
                        financialProvider.updateIncomeAmount(item, val),
                  ),
                );
              }),
              SizedBox(height: screenH * 0.03),

              // 5. Expected Monthly Income Total
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: (isDark
                          ? AppColors.darkSecondary
                          : AppColors.lightSecondary)
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: isDark
                          ? AppColors.darkSecondary
                          : AppColors.lightSecondary),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Expected Monthly Income:",
                      style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 16,
                          color: isDark
                              ? AppColors.darkSubText
                              : AppColors.lightSubText),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "${financialProvider.totalIncome.toStringAsFixed(2)} JOD",
                      style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? AppColors.darkText
                              : AppColors.lightText),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "This total includes your salary and separate recurring monthly income only.",
                      style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 12,
                          color: isDark
                              ? AppColors.darkSubText
                              : AppColors.lightSubText),
                    ),
                  ],
                ),
              ),
              SizedBox(height: screenH * 0.03),

              // 6. Salary Payment Day
              _SectionTitle("Salary Payment Day",
                  isDark: isDark, screenW: screenW),
              SizedBox(height: screenH * 0.01),
              InkWell(
                onTap: () =>
                    _showSalaryDayPicker(context, financialProvider, isDark),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkCard : AppColors.lightCard,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: isDark
                            ? AppColors.darkBorder
                            : AppColors.lightBorder),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        financialProvider.paymentDay != null
                            ? "Day ${financialProvider.paymentDay}"
                            : "Select salary day",
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 16,
                          color: financialProvider.paymentDay != null
                              ? (isDark
                                  ? AppColors.darkText
                                  : AppColors.lightText)
                              : (isDark
                                  ? AppColors.darkSubText
                                  : AppColors.lightSubText),
                        ),
                      ),
                      Icon(Icons.arrow_drop_down,
                          color: isDark
                              ? AppColors.darkSubText
                              : AppColors.lightSubText),
                    ],
                  ),
                ),
              ),
              SizedBox(height: screenH * 0.03),

              // 7. Fixed Monthly Expenses
              _SectionTitle("Fixed Monthly Expenses",
                  isDark: isDark, screenW: screenW),
              SizedBox(height: screenH * 0.01),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 2.0),
                child: Row(
                  children: financialProvider.fixedExpenses
                      .asMap()
                      .entries
                      .map((entry) {
                    final index = entry.key;
                    final item = entry.value;
                    return Padding(
                      padding: EdgeInsets.only(
                          right: index !=
                                  financialProvider.fixedExpenses.length - 1
                              ? 10.0
                              : 0),
                      child: ChoiceChip(
                        label: Text(item.name),
                        selected: item.selected,
                        onSelected: (_) =>
                            financialProvider.toggleExpense(item),
                        selectedColor: (isDark
                                ? AppColors.darkSecondary
                                : AppColors.lightSecondary)
                            .withValues(alpha: 0.04),
                        backgroundColor: (isDark
                                ? AppColors.darkSubText
                                : AppColors.lightSubText)
                            .withValues(alpha: 0.4),
                        side: BorderSide(
                            color: item.selected
                                ? (isDark
                                    ? AppColors.darkPrimary
                                    : AppColors.lightPrimary)
                                : Colors.transparent),
                        labelStyle: TextStyle(
                            color: item.selected
                                ? (isDark
                                    ? AppColors.darkPrimary
                                    : AppColors.lightPrimary)
                                : (isDark
                                    ? AppColors.darkSubText
                                    : AppColors.lightSubText)),
                      ),
                    );
                  }).toList(),
                ),
              ),
              SizedBox(height: screenH * 0.01),
              ...financialProvider.fixedExpenses
                  .where((e) => e.selected)
                  .map((item) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10.0),
                  child: CustomTextfield(
                    controller: item.controller,
                    hint: "Enter monthly amount for ${item.name}",
                    type: TextFieldType.number,
                    inputFormatters: [_decimalFormatter],
                    suffix: const Padding(
                        padding: EdgeInsets.all(12), child: Text("JOD")),
                    onChanged: (val) =>
                        financialProvider.updateExpenseAmount(item, val),
                  ),
                );
              }),
              SizedBox(height: screenH * 0.03),

              // 8. Flexible Monthly Expenses
              _SectionTitle("Flexible Monthly Expenses",
                  isDark: isDark, screenW: screenW),
              SizedBox(height: screenH * 0.01),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 2.0),
                child: Row(
                  children: financialProvider.flexibleExpenses
                      .asMap()
                      .entries
                      .map((entry) {
                    final index = entry.key;
                    final item = entry.value;
                    return Padding(
                      padding: EdgeInsets.only(
                          right: index !=
                                  financialProvider.flexibleExpenses.length - 1
                              ? 10.0
                              : 0),
                      child: ChoiceChip(
                        label: Text(item.name),
                        selected: item.selected,
                        onSelected: (_) => financialProvider.toggleExpense(item,
                            isFixed: false),
                        selectedColor: (isDark
                                ? AppColors.darkSecondary
                                : AppColors.lightSecondary)
                            .withValues(alpha: 0.04),
                        backgroundColor: (isDark
                                ? AppColors.darkSubText
                                : AppColors.lightSubText)
                            .withValues(alpha: 0.4),
                        side: BorderSide(
                            color: item.selected
                                ? (isDark
                                    ? AppColors.darkPrimary
                                    : AppColors.lightPrimary)
                                : Colors.transparent),
                        labelStyle: TextStyle(
                            color: item.selected
                                ? (isDark
                                    ? AppColors.darkPrimary
                                    : AppColors.lightPrimary)
                                : (isDark
                                    ? AppColors.darkSubText
                                    : AppColors.lightSubText)),
                      ),
                    );
                  }).toList(),
                ),
              ),
              SizedBox(height: screenH * 0.01),
              ...financialProvider.flexibleExpenses
                  .where((e) => e.selected)
                  .map((item) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10.0),
                  child: CustomTextfield(
                    controller: item.controller,
                    hint: "Enter monthly amount for ${item.name}",
                    type: TextFieldType.number,
                    inputFormatters: [_decimalFormatter],
                    suffix: const Padding(
                        padding: EdgeInsets.all(12), child: Text("JOD")),
                    onChanged: (val) =>
                        financialProvider.updateExpenseAmount(item, val),
                  ),
                );
              }),
              SizedBox(height: screenH * 0.03),

              // 9. Estimated Financial Summary
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCard : AppColors.lightCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: isDark
                          ? AppColors.darkBorder
                          : AppColors.lightBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Estimated Financial Summary",
                        style: GoogleFonts.ibmPlexSansArabic(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? AppColors.darkText
                                : AppColors.lightText)),
                    const SizedBox(height: 8),
                    Text(
                        "Note: These are estimates and do not represent actual transactions.",
                        style: GoogleFonts.ibmPlexSansArabic(
                            fontSize: 12,
                            color: isDark
                                ? AppColors.darkSubText
                                : AppColors.lightSubText)),
                    Divider(
                        color: isDark
                            ? AppColors.darkBorder
                            : AppColors.lightBorder,
                        height: 24),
                    _SummaryRow("Expected Monthly Income",
                        financialProvider.totalIncome,
                        isDark: isDark),
                    _SummaryRow(
                        "Fixed Expenses", financialProvider.totalFixedExpenses,
                        isDark: isDark),
                    _SummaryRow("Flexible Expenses",
                        financialProvider.totalVariableExpenses,
                        isDark: isDark),
                    Divider(
                        color: isDark
                            ? AppColors.darkBorder
                            : AppColors.lightBorder,
                        height: 24),
                    _SummaryRow("Total Estimated Expenses",
                        financialProvider.totalExpenses,
                        isDark: isDark, isBold: true),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          financialProvider.estimatedBalance >= 0
                              ? "Estimated Surplus"
                              : "Estimated Deficit",
                          style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? AppColors.darkText
                                  : AppColors.lightText),
                        ),
                        Text(
                          "${financialProvider.estimatedBalance >= 0 ? financialProvider.surplus.toStringAsFixed(2) : financialProvider.deficit.toStringAsFixed(2)} JOD",
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: financialProvider.estimatedBalance >= 0
                                ? (isDark
                                    ? AppColors.darkPrimary
                                    : AppColors.lightPrimary)
                                : (isDark
                                    ? AppColors.darkError
                                    : AppColors.lightError),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(height: screenH * 0.04),

              // 10. Main Financial Goal
              _SectionTitle("Main Financial Goal",
                  isDark: isDark, screenW: screenW),
              SizedBox(height: screenH * 0.01),
              OptionChip(
                items: const [
                  "Saving",
                  "Debt payment",
                  "Daily budget",
                  "Emergency fund",
                  "Other"
                ],
                selected: financialProvider.mainGoalDisplay,
                onTap: financialProvider.setMainGoal,
              ),
              SizedBox(height: screenH * 0.03),

              // 11. Optional Extra Monthly Saving Target
              _SectionTitle("Optional Extra Monthly Saving Target",
                  isDark: isDark, screenW: screenW),
              const SizedBox(height: 4),
              Text(
                "This is a personal target and is not counted as part of your income.",
                style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 13,
                    color: isDark
                        ? AppColors.darkSubText
                        : AppColors.lightSubText),
              ),
              SizedBox(height: screenH * 0.01),
              CustomTextfield(
                controller: financialProvider.savingTargetController,
                hint: "Enter optional saving amount",
                type: TextFieldType.number,
                inputFormatters: [_decimalFormatter],
                suffix: const Padding(
                    padding: EdgeInsets.all(12), child: Text("JOD")),
                onChanged: financialProvider.setSavingTarget,
              ),
              SizedBox(height: screenH * 0.04),

              // 12. Disabled Reason
              if (financialProvider.disabledReason != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Text(
                    financialProvider.disabledReason!,
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color:
                          isDark ? AppColors.darkError : AppColors.lightError,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

              // 13. Next Button
              Padding(
                padding: EdgeInsets.only(bottom: screenH * 0.02),
                child: SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: (financialProvider.isValid &&
                            !onboardingProvider.isLoading)
                        ? () async {
                            if (_isNavigating) return;
                            setState(() => _isNavigating = true);

                            try {
                              final successPersonal =
                                  await onboardingProvider.savePersonalInfo(
                                financialProvider.personalInfoData,
                              );
                              if (!mounted) return;

                              if (successPersonal) {
                                final successFinancial =
                                    await onboardingProvider.saveFinancialSetup(
                                  monthlyIncome: financialProvider.totalIncome,
                                  paymentDay: financialProvider.paymentDay,
                                );
                                if (!mounted) return;

                                if (successFinancial) {
                                  replaceWithOnboardingStep(
                                    context,
                                    onboardingProvider.nextStep,
                                    allocation: onboardingProvider.allocation,
                                  );
                                } else if (onboardingProvider.errorMessage !=
                                    null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content: Text(
                                            onboardingProvider.errorMessage!)),
                                  );
                                }
                              } else if (onboardingProvider.errorMessage !=
                                  null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text(
                                          onboardingProvider.errorMessage!)),
                                );
                              }
                            } finally {
                              if (mounted) {
                                setState(() => _isNavigating = false);
                              }
                            }
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark
                          ? AppColors.darkPrimary
                          : AppColors.lightPrimary,
                      disabledBackgroundColor:
                          isDark ? AppColors.darkBorder : AppColors.lightBorder,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: onboardingProvider.isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(
                            "Next",
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: 18,
                              color: financialProvider.isValid
                                  ? (isDark
                                      ? AppColors.darkBackground
                                      : AppColors.lightCard)
                                  : (isDark
                                      ? AppColors.darkSubText
                                      : AppColors.lightSubText),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final bool isDark;
  final double screenW;

  const _SectionTitle(this.title,
      {required this.isDark, required this.screenW});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: GoogleFonts.ibmPlexSansArabic(
        fontSize: screenW * 0.04,
        fontWeight: FontWeight.bold,
        color: isDark ? AppColors.darkSubText : AppColors.lightSubText,
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final double amount;
  final bool isDark;
  final bool isBold;

  const _SummaryRow(this.label, this.amount,
      {required this.isDark, this.isBold = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: 14,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: isDark ? AppColors.darkText : AppColors.lightText,
            ),
          ),
          Text(
            "${amount.toStringAsFixed(2)} JOD",
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: 14,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: isDark ? AppColors.darkText : AppColors.lightText,
            ),
          ),
        ],
      ),
    );
  }
}
