import 'package:flutter/material.dart';
import 'package:alpha_app/models/income_source.dart';
import 'package:alpha_app/models/expense_item.dart';

class FinancialProvider extends ChangeNotifier {
  String? moneyRelationship;
  double? savingTarget; // mapped to monthlyExtraSavingsGoal
  String? mainGoal;
  int? paymentDay; // mapped to salaryPaymentDay

  double? regularSalary;
  final regularSalaryController = TextEditingController();
  final savingTargetController = TextEditingController();

  List<IncomeSource> incomeSources = [
    IncomeSource(name: "Temporary Job"),
    IncomeSource(name: "Family Support"),
    IncomeSource(name: "External Support"),
    IncomeSource(name: "Rent Income"),
    IncomeSource(name: "Other"),
  ];

  List<ExpenseItem> fixedExpenses = [
    ExpenseItem(name: "Education"),
    ExpenseItem(name: "House Rent"),
    ExpenseItem(name: "Loan"),
    ExpenseItem(name: "Bills"),
    ExpenseItem(name: "Treatment"),
    ExpenseItem(name: "Saving"),
    ExpenseItem(name: "Other"),
  ];

  List<ExpenseItem> flexibleExpenses = [
    ExpenseItem(name: "Food"),
    ExpenseItem(name: "Transport"),
    ExpenseItem(name: "Clothes"),
    ExpenseItem(name: "Entertainment"),
    ExpenseItem(name: "Personal Care"),
    ExpenseItem(name: "Other"),
  ];

  void setMoneyRelationship(String value) {
    switch (value) {
      case 'Careful spending':
        moneyRelationship = 'careful_spending';
        break;
      case 'Balanced spending':
        moneyRelationship = 'balanced_spending';
        break;
      case 'Emotional spending':
        moneyRelationship = 'emotional_spending';
        break;
      default:
        moneyRelationship = value;
    }
    notifyListeners();
  }

  String? get moneyRelationshipDisplay {
    switch (moneyRelationship) {
      case 'careful_spending':
        return 'Careful spending';
      case 'balanced_spending':
        return 'Balanced spending';
      case 'emotional_spending':
        return 'Emotional spending';
      default:
        return moneyRelationship;
    }
  }

  void setMainGoal(String value) {
    switch (value) {
      case 'Saving':
        mainGoal = 'saving';
        break;
      case 'Debt payment':
        mainGoal = 'debt_payment';
        break;
      case 'Daily budget':
        mainGoal = 'daily_budget';
        break;
      case 'Emergency fund':
        mainGoal = 'emergency_fund';
        break;
      case 'Other':
        mainGoal = 'other';
        break;
      default:
        mainGoal = value;
    }
    notifyListeners();
  }

  String? get mainGoalDisplay {
    switch (mainGoal) {
      case 'saving':
        return 'Saving';
      case 'debt_payment':
        return 'Debt payment';
      case 'daily_budget':
        return 'Daily budget';
      case 'emergency_fund':
        return 'Emergency fund';
      case 'other':
        return 'Other';
      default:
        return mainGoal;
    }
  }

  void setSavingTarget(String value) {
    if (value.isEmpty) {
      savingTarget = null;
    } else {
      savingTarget = double.tryParse(value.replaceAll(",", "."));
    }
    notifyListeners();
  }

  void setRegularSalary(String value) {
    if (value.isEmpty) {
      regularSalary = null;
    } else {
      regularSalary = double.tryParse(value.replaceAll(",", "."));
    }
    notifyListeners();
  }

  void setPaymentDay(int? value) {
    paymentDay = value;
    notifyListeners();
  }

  void toggleIncome(IncomeSource item) {
    item.selected = !item.selected;
    if (!item.selected) {
      item.amount = 0;
      item.controller.clear();
    }
    notifyListeners();
  }

  void updateIncomeAmount(IncomeSource item, String value) {
    item.amount = double.tryParse(value.replaceAll(",", ".")) ?? 0;
    notifyListeners();
  }

  void toggleExpense(ExpenseItem item, {bool isFixed = true}) {
    item.selected = !item.selected;
    if (!item.selected) {
      item.amount = 0;
      item.controller.clear();
    }
    notifyListeners();
  }

  void updateExpenseAmount(ExpenseItem item, String value) {
    item.amount = double.tryParse(value.replaceAll(",", ".")) ?? 0;
    notifyListeners();
  }

  double get totalIncome {
    final salary = regularSalary ?? 0.0;
    final otherIncome = incomeSources
        .where((e) => e.selected)
        .fold(0.0, (sum, item) => sum + item.amount);
    return salary + otherIncome;
  }

  double get totalFixedExpenses {
    return fixedExpenses
        .where((e) => e.selected)
        .fold(0.0, (sum, item) => sum + item.amount);
  }

  double get totalVariableExpenses {
    return flexibleExpenses
        .where((e) => e.selected)
        .fold(0.0, (sum, item) => sum + item.amount);
  }

  double get totalExpenses {
    return totalFixedExpenses + totalVariableExpenses;
  }

  double get estimatedBalance {
    return totalIncome - totalExpenses;
  }

  double get surplus {
    return estimatedBalance > 0 ? estimatedBalance : 0.0;
  }

  double get deficit {
    return estimatedBalance < 0 ? estimatedBalance.abs() : 0.0;
  }

  double get pageProgress {
    return 2 / 3;
  }

  String? get disabledReason {
    if (moneyRelationship == null) {
      return "Select your relationship with money.";
    }
    if (regularSalary == null || regularSalary! <= 0) {
      return "Enter your regular monthly salary.";
    }
    if (incomeSources.any((e) => e.selected && e.amount <= 0)) {
      return "Enter valid amounts for selected additional income sources.";
    }
    if (paymentDay == null || paymentDay! < 1 || paymentDay! > 31) {
      return "Select your salary payment day.";
    }
    if (fixedExpenses.any((e) => e.selected && e.amount <= 0) ||
        flexibleExpenses.any((e) => e.selected && e.amount <= 0)) {
      return "Enter valid amounts for selected expenses.";
    }
    if (mainGoal == null) {
      return "Select your main financial goal.";
    }

    final hasNegativeAmounts = (regularSalary != null && regularSalary! < 0) ||
        incomeSources.any((e) => e.amount < 0) ||
        fixedExpenses.any((e) => e.amount < 0) ||
        flexibleExpenses.any((e) => e.amount < 0) ||
        (savingTarget != null && savingTarget! < 0);

    if (hasNegativeAmounts) {
      return "Amounts cannot be negative.";
    }

    return null;
  }

  bool get isValid => disabledReason == null;

  Map<String, dynamic> get personalInfoData {
    // Collect regular salary distinctly
    final List<Map<String, dynamic>> finalIncomeSources = [];
    if (regularSalary != null && regularSalary! > 0) {
      finalIncomeSources.add({
        "type": "regular_salary",
        "amount": regularSalary,
      });
    }

    // Add other selected sources, ensuring no duplicate "regular_salary"
    for (var e in incomeSources.where((e) => e.selected)) {
      final type = e.name.toLowerCase().replaceAll(' ', '_');
      if (type != 'regular_salary') {
        finalIncomeSources.add({"type": type, "amount": e.amount});
      }
    }

    return {
      "relationshipWithMoney": moneyRelationship,
      "primaryFinancialGoal": mainGoal,
      "monthlyExtraSavingsGoal": savingTarget,
      "incomeSources": finalIncomeSources,
      "fixedExpenses": fixedExpenses
          .where((e) => e.selected)
          .map((e) => {
                "type": e.name.toLowerCase().replaceAll(' ', '_'),
                "amount": e.amount
              })
          .toList(),
      "variableExpenses": flexibleExpenses
          .where((e) => e.selected)
          .map((e) => {
                "type": e.name.toLowerCase().replaceAll(' ', '_'),
                "amount": e.amount
              })
          .toList(),
    };
  }

  Map<String, dynamic> get financialSetupData => {
        "monthlyIncome": totalIncome,
        "salaryPaymentDay": paymentDay,
      };

  void clearData() {
    moneyRelationship = null;
    savingTarget = null;
    mainGoal = null;
    paymentDay = null;
    regularSalary = null;
    regularSalaryController.clear();
    savingTargetController.clear();

    for (var item in incomeSources) {
      item.selected = false;
      item.amount = 0;
      item.controller.clear();
    }
    for (var item in fixedExpenses) {
      item.selected = false;
      item.amount = 0;
      item.controller.clear();
    }
    for (var item in flexibleExpenses) {
      item.selected = false;
      item.amount = 0;
      item.controller.clear();
    }
    notifyListeners();
  }

  @override
  void dispose() {
    regularSalaryController.dispose();
    savingTargetController.dispose();
    for (var item in incomeSources) {
      item.controller.dispose();
    }
    for (var item in fixedExpenses) {
      item.controller.dispose();
    }
    for (var item in flexibleExpenses) {
      item.controller.dispose();
    }
    super.dispose();
  }
}
