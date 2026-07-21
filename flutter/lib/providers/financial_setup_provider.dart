import 'package:flutter/material.dart';

class FinancialProvider extends ChangeNotifier {
  String? financialKnowledge;
  String? primaryFinancialGoal;
  double? monthlyIncome;

  final monthlyIncomeController = TextEditingController();

  void setFinancialKnowledge(String value) {
    financialKnowledge = value;
    notifyListeners();
  }

  void setPrimaryFinancialGoal(String value) {
    primaryFinancialGoal = value;
    notifyListeners();
  }

  void setMonthlyIncome(String value) {
    monthlyIncome = double.tryParse(value.replaceAll(",", "."));
    notifyListeners();
  }

  double get pageProgress {
    const int totalQuestions = 3;
    int completed = 0;

    if (financialKnowledge != null) {
      completed++;
    }

    if (primaryFinancialGoal != null) {
      completed++;
    }

    if (monthlyIncome != null) {
      completed++;
    }

    // Since this is Step 2 of 3 in onboarding, maybe progress starts from 1/3?
    // Let's preserve the logic: 1/3 + (completed/totalQuestions) * 1/3
    return (1 / 3) + ((completed / totalQuestions) * (1 / 3));
  }

  bool get isValid {
    return financialKnowledge != null &&
        primaryFinancialGoal != null &&
        monthlyIncome != null;
  }

  bool get canSave => isValid;

  Map<String, dynamic> get data => {
        "financialKnowledge": financialKnowledge,
        "primaryFinancialGoal": primaryFinancialGoal,
        "monthlyIncome": monthlyIncome,
      };

  @override
  void dispose() {
    monthlyIncomeController.dispose();
    super.dispose();
  }
}