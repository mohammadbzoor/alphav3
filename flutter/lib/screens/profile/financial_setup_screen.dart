import 'package:alpha_app/core/utils/app_colors.dart';
import 'package:alpha_app/core/utils/device.dart';
import 'package:alpha_app/providers/financial_setup_provider.dart';
import 'package:alpha_app/providers/themeprovider.dart';
import 'package:alpha_app/screens/goals/set_goal_screen.dart';
import 'package:alpha_app/widgets/custom_textfield.dart';
import 'package:alpha_app/widgets/multi_select_chip.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';
import 'package:provider/provider.dart';

class FinancialSetupScreen extends StatelessWidget {
  const FinancialSetupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final screenW = Device.width(context);
    final screenH = Device.height(context);
    final themeProvider = Provider.of<Themeprovider>(context);
    final financialProvider = context.watch<FinancialProvider>();

    return Scaffold(
      backgroundColor: themeProvider.isDark
          ? AppColors.darkBackground
          : AppColors.lightBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: screenW * 0.05),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: screenH * 0.03),

              Text(
                "Step 2 of 3",
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: screenW * 0.04,
                  fontWeight: FontWeight.w500,
                  color: themeProvider.isDark
                      ? AppColors.darkAccent
                      : AppColors.lightAccent,
                ),
              ),

              SizedBox(height: screenH * 0.02),

              Text(
                "Financial Information",
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: screenW * 0.075,
                  fontWeight: FontWeight.bold,
                  color: themeProvider.isDark
                      ? AppColors.darkText
                      : AppColors.lightText,
                ),
              ),

              SizedBox(height: screenH * 0.01),

              Text(
                "Accurate data means sharper advice from Alpha",
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: screenW * 0.035,
                  fontWeight: FontWeight.w500,
                  color: themeProvider.isDark
                      ? AppColors.darkSubText
                      : AppColors.lightSubText,
                ),
              ),

              SizedBox(height: screenH * 0.02),

              LinearPercentIndicator(
                lineHeight: screenH * 0.02,
                percent: financialProvider.pageProgress,
                backgroundColor: themeProvider.isDark
                    ? AppColors.darkBorder
                    : AppColors.lightBorder,
                progressColor: themeProvider.isDark
                    ? AppColors.darkSecondary
                    : AppColors.lightSecondary,
                barRadius: const Radius.circular(10),
              ),

              SizedBox(height: screenH * 0.03),

              Text(
                "How do you describe your relationship with money?",
                style: TextStyle(
                  fontSize: screenW * 0.04,
                  fontWeight: FontWeight.bold,
                  color: themeProvider.isDark
                      ? AppColors.darkSubText
                      : AppColors.lightSubText,
                ),
              ),

              SizedBox(height: screenH * 0.01),

              MultiSelectChip(
                items: const [
                  "Careful spending",
                  "Balanced spending",
                  "Emotional spending",
                ],
                selectedItems: financialProvider.financialKnowledge == null
                    ? []
                    : [financialProvider.financialKnowledge!],
                onTap: (value) {
                  financialProvider.setFinancialKnowledge(value);
                },
              ),

              SizedBox(height: screenH * 0.02),

              Text(
                "Main financial goal",
                style: TextStyle(
                  fontSize: screenW * 0.04,
                  fontWeight: FontWeight.bold,
                  color: themeProvider.isDark
                      ? AppColors.darkSubText
                      : AppColors.lightSubText,
                ),
              ),

              SizedBox(height: screenH * 0.01),

              MultiSelectChip(
                items: const [
                  "Saving",
                  "Debt payment",
                  "Daily budget",
                  "Other",
                ],
                selectedItems: financialProvider.primaryFinancialGoal == null
                    ? []
                    : [financialProvider.primaryFinancialGoal!],
                onTap: (value) {
                  financialProvider.setPrimaryFinancialGoal(value);
                },
              ),

              SizedBox(height: screenH * 0.02),

              Text("Average household income",
                  style: TextStyle(
                      fontSize: screenW * 0.04,
                      color: themeProvider.isDark
                          ? AppColors.darkSubText
                          : AppColors.lightSubText,
                      fontWeight: FontWeight.bold)),

              SizedBox(height: screenH * 0.01),

              CustomTextfield(
                controller: financialProvider.monthlyIncomeController,
                hint: "Enter income",
                type: TextFieldType.number,
                suffix: const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text("JOD"),
                ),
                onChanged: financialProvider.setMonthlyIncome,
              ),

              SizedBox(height: screenH * 0.05),

              Padding(
                padding: EdgeInsets.only(bottom: screenH * 0.02),
                child: ElevatedButton(
                  onPressed: () {
                    if (financialProvider.isValid) {
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const SetGoalScreen(),
                          ));
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: themeProvider.isDark
                              ? AppColors.darkError
                              : AppColors.lightError,
                          content: Text(
                            "Please complete all required fields",
                            style: TextStyle(
                              fontSize: screenW * 0.04,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                  style: ButtonStyle(
                    backgroundColor: WidgetStatePropertyAll(
                      themeProvider.isDark
                          ? AppColors.darkPrimary
                          : AppColors.lightPrimary,
                    ),
                    fixedSize: WidgetStatePropertyAll(
                      Size(screenW, screenH * 0.065),
                    ),
                    shape: WidgetStatePropertyAll(
                      RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  child: Text(
                    "Next",
                    style: TextStyle(
                      fontSize: screenW * 0.055,
                      color: AppColors.darkBorder,
                      fontWeight: FontWeight.w600,
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
