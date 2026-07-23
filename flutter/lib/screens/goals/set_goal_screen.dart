import 'package:alpha_app/core/utils/app_colors.dart';
import 'package:alpha_app/core/utils/device.dart';
import 'package:alpha_app/providers/goal_provider.dart';

import 'package:alpha_app/providers/themeprovider.dart';
import 'package:alpha_app/screens/auth/login.dart';
import 'package:alpha_app/screens/goals/goal_date.dart';
import 'package:alpha_app/screens/goals/goal_history.dart';
import 'package:alpha_app/screens/main_screen.dart';
import 'package:alpha_app/widgets/app_button.dart';
import 'package:alpha_app/widgets/custom_textfield.dart';
import 'package:alpha_app/widgets/multi_select_chip.dart';
import 'package:alpha_app/widgets/goals/priority_card.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';
import 'package:provider/provider.dart';

class SetGoalScreen extends StatelessWidget {
  const SetGoalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GoalProvider>();

    final themeProvider = context.watch<Themeprovider>();

    final screenW = Device.width(context);
    final screenH = Device.height(context);

    return Scaffold(
      backgroundColor: themeProvider.isDark
          ? AppColors.darkBackground
          : AppColors.lightBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: screenW * 0.05,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: screenW * 0.03),
              Text(
                "Step 3 of 3",
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: screenW * 0.04,
                  fontWeight: FontWeight.w500,
                  color: themeProvider.isDark
                      ? AppColors.darkAccent
                      : AppColors.lightAccent,
                ),
              ),
              SizedBox(
                height: screenH * 0.02,
              ),
              Text(
                "Set your first goal",
                style: GoogleFonts.ibmPlexSansArabic(
                  color: themeProvider.isDark
                      ? AppColors.darkText
                      : AppColors.lightText,
                  fontSize: screenW * 0.075,
                  fontWeight: FontWeight.bold,
                ),
              ),

              SizedBox(
                height: screenH * 0.01,
              ),

              Text(
                "You can add more anytime later",
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: screenW * 0.035,
                  fontWeight: FontWeight.w500,
                  color: themeProvider.isDark
                      ? AppColors.darkSubText
                      : AppColors.lightSubText,
                ),
              ),

              const SizedBox(height: 25),

              // ================= PROGRESS =================

              LinearPercentIndicator(
                lineHeight: screenH * 0.02, // سماكة الشريط
                percent: provider.pageProgress, // النسبة المئوية للتقدم
                backgroundColor: themeProvider.isDark
                    ? AppColors.darkBorder
                    : AppColors.lightBorder,
                progressColor: themeProvider.isDark
                    ? AppColors.darkSecondary
                    : AppColors.lightSecondary,
                barRadius: Radius.circular(10),
                animation: false,
                animationDuration: 1000,
              ),

              SizedBox(
                height: screenH * 0.03,
              ),

              Text(
                "Choose your goal",
                style: TextStyle(
                    fontSize: screenW * 0.04,
                    color: themeProvider.isDark
                        ? AppColors.darkSubText
                        : AppColors.lightSubText,
                    fontWeight: FontWeight.bold),
              ),

              SizedBox(
                height: screenH * 0.01,
              ),

              MultiSelectChip(
                items: provider.goalCategories,
                selectedItems: provider.selectedCategory == null
                    ? []
                    : [provider.selectedCategory!],
                onTap: provider.setCategory,
              ),

              SizedBox(
                height: screenH * 0.02,
              ),

              // ================= OTHER NAME =================

              if (provider.selectedCategory == "Other")
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: screenH * 0.02,
                    ),
                    Text(
                      "Goal name",
                      style: TextStyle(
                          fontSize: screenW * 0.04,
                          color: themeProvider.isDark
                              ? AppColors.darkSubText
                              : AppColors.lightSubText,
                          fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    CustomTextfield(
                      controller: provider.customNameController,
                      hint: "Enter goal name",
                      type: TextFieldType.name,
                      onChanged: (_) {
                        provider.refresh();
                      },
                    ),
                  ],
                ),

              SizedBox(
                height: screenH * 0.02,
              ),

              Text(
                "Monthly saving amount",
                style: TextStyle(
                    fontSize: screenW * 0.04,
                    color: themeProvider.isDark
                        ? AppColors.darkSubText
                        : AppColors.lightSubText,
                    fontWeight: FontWeight.bold),
              ),

              SizedBox(
                height: screenH * 0.01,
              ),

              CustomTextfield(
                suffix: const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text("JOD"),
                ),
                controller: provider.amountController,
                hint: "Amount per month",
                type: TextFieldType.number,
                icon: Icons.payments_outlined,
                onChanged: (_) {
                  provider.refresh();
                },
              ),

              SizedBox(
                height: screenH * 0.02,
              ),

              Text(
                "Priority",
                style: TextStyle(
                  fontSize: screenW * 0.04,
                  color: themeProvider.isDark
                      ? AppColors.darkSubText
                      : AppColors.lightSubText,
                  fontWeight: FontWeight.bold,
                ),
              ),

              SizedBox(height: screenH * 0.012),

              PriorityCard(
                priority: provider.priority,
                isDark: themeProvider.isDark,
                screenW: screenW,
                onChanged: (value) {
                  provider.setPriority(
                    value.toInt(),
                  );
                },
              ),

              SizedBox(height: screenH * 0.02),

              Text(
                "Target date",
                style: TextStyle(
                    fontSize: screenW * 0.04,
                    color: themeProvider.isDark
                        ? AppColors.darkSubText
                        : AppColors.lightSubText,
                    fontWeight: FontWeight.bold),
              ),

              SizedBox(
                height: screenH * 0.01,
              ),

              CustomTextfield(
                controller: provider.targetDateController,
                hint: "Select your target date",
                icon: Icons.calendar_month,
                type: TextFieldType.date,
                readOnly: true,
                onTap: () async {
                  final date = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => GoalDateScreen(
                        initialDate: provider.targetDate,
                      ),
                    ),
                  );

                  if (date != null) {
                    provider.setDate(date);
                  }
                },
              ),

              SizedBox(
                height: screenH * 0.02,
              ),

              // ============== BASIRA SUGGESTION ==============

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: themeProvider.isDark
                      ? AppColors.darkSecondary.withOpacity(.1)
                      : AppColors.lightSecondary.withOpacity(.1),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.lightbulb_outline,
                      color: themeProvider.isDark
                          ? AppColors.darkPrimary
                          : AppColors.lightPrimary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        "Alpha suggests\nChoose a realistic monthly amount to reach your goal comfortably.",
                        style: TextStyle(
                          color: themeProvider.isDark
                              ? AppColors.darkText
                              : AppColors.lightText,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: screenH * 0.03),
              Padding(
                padding: EdgeInsets.only(
                  bottom: screenH * 0.02,
                ),
                child: AppButton(
                  text: "Finish",
                  isDark: themeProvider.isDark,
                  width: screenW,
                  height: screenH * 0.065,
                  isLoading: provider.isSaving,
                  onPressed: () async {
                    if (provider.isValid) {
                      final saved = await provider.saveCurrentGoal();

                      if (saved) {
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const MainNavigationScreen(),
                          ),
                          (route) => false,
                        );
                      }
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
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
