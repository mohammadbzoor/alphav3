import 'package:alpha_app/core/utils/app_colors.dart';
import 'package:alpha_app/core/utils/device.dart';
import 'package:alpha_app/models/expense_model.dart';
import 'package:alpha_app/providers/expense_provider.dart';
import 'package:alpha_app/providers/themeprovider.dart';
import 'package:alpha_app/screens/expenses/new_expense_screen.dart';
import 'package:alpha_app/widgets/dashed_action_button.dart';
import 'package:alpha_app/widgets/delete_dialog.dart';
import 'package:alpha_app/widgets/empty_screen.dart';
import 'package:alpha_app/widgets/expenses/expense_card.dart';
import 'package:alpha_app/core/utils/onboarding_guard.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

enum _AnalyticsType {
  payment,
  movement,
  source,
  needWant,
  category,
}

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({
    super.key,
  });

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  _AnalyticsType _selectedAnalytics = _AnalyticsType.payment;

  @override
  Widget build(BuildContext context) {
    final expenseProvider = context.watch<ExpenseProvider>();

    final themeProvider = context.watch<Themeprovider>();

    final bool isDark = themeProvider.isDark;

    final double screenW = Device.width(context);

    final double screenH = Device.height(context);

    final List<ExpenseModel> expenses = expenseProvider.expenses;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: screenW * 0.055,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: screenH * 0.025,
              ),
              _Header(
                isDark: isDark,
                screenW: screenW,
                expenseCount: expenses.length,
                onAddPressed: () {
                  _openNewExpenseScreen(
                    context,
                  );
                },
              ),
              SizedBox(
                height: screenH * 0.025,
              ),
              Expanded(
                child: expenses.isEmpty
                    ? EmptyStateView(
                        isDark: isDark,
                        screenW: screenW,
                        title: "No expenses yet",
                        description:
                            "Start recording your expenses to unlock spending analysis and personalized Alpha insights.",
                        buttonText: "Add your first expense",
                        icon: Icons.account_balance_wallet_outlined,
                        color: isDark
                            ? AppColors.darkSecondary
                            : AppColors.lightSecondary,
                        onPressed: () {
                          _openNewExpenseScreen(
                            context,
                          );
                        },
                      )
                    : ListView(
                        physics: const BouncingScrollPhysics(),
                        padding: EdgeInsets.only(
                          bottom: screenH * 0.14,
                        ),
                        children: [
                          _ThisMonthCard(
                            total: expenseProvider.currentMonthTotal,
                            expenseCount: expenses.length,
                            isDark: isDark,
                          ),
                          SizedBox(
                            height: screenH * 0.018,
                          ),
                          _AnalyticsCard(
                            expenses: expenses,
                            selectedType: _selectedAnalytics,
                            isDark: isDark,
                            onTypeChanged: (
                              type,
                            ) {
                              setState(() {
                                _selectedAnalytics = type;
                              });
                            },
                          ),
                          SizedBox(
                            height: screenH * 0.018,
                          ),
                          _AlphaInsightCard(
                            insight: expenseProvider.spendingInsight,
                            isDark: isDark,
                          ),
                          SizedBox(
                            height: screenH * 0.025,
                          ),
                          _RecentExpensesHeader(
                            count: expenses.length,
                            isDark: isDark,
                            screenW: screenW,
                          ),
                          SizedBox(
                            height: screenH * 0.014,
                          ),
                          ...expenses.map(
                            (expense) => ExpenseCard(
                              expense: expense,
                              onDelete: () {
                                DeleteDialog.show(
                                  context: context,
                                  title: "Delete Expense",
                                  message:
                                      'Are you sure you want to delete "${expense.title}"?',
                                  onDelete: () {
                                    context
                                        .read<ExpenseProvider>()
                                        .deleteExpense(
                                          expense.id,
                                        );

                                    ScaffoldMessenger.of(
                                      context,
                                    ).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          "Expense deleted successfully",
                                          style:
                                              GoogleFonts.ibmPlexSansArabic(),
                                        ),
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                          ),
                          const SizedBox(
                            height: 4,
                          ),
                          DashedActionButton(
                            text: "Add a new expense",
                            isDark: isDark,
                            onTap: () {
                              _openNewExpenseScreen(
                                context,
                              );
                            },
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openNewExpenseScreen(
    BuildContext context,
  ) {
    if (!requireOnboarding(context)) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const NewExpenseScreen(),
      ),
    );
  }
}

// =====================================================
// HEADER
// =====================================================

class _Header extends StatelessWidget {
  final bool isDark;
  final double screenW;
  final int expenseCount;
  final VoidCallback onAddPressed;

  const _Header({
    required this.isDark,
    required this.screenW,
    required this.expenseCount,
    required this.onAddPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Expenses",
                style: GoogleFonts.ibmPlexSansArabic(
                  color: isDark ? AppColors.darkText : AppColors.lightText,
                  fontSize: screenW * 0.07,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                "$expenseCount ${expenseCount == 1 ? "expense" : "expenses"} recorded",
                style: GoogleFonts.ibmPlexSansArabic(
                  color:
                      isDark ? AppColors.darkSubText : AppColors.lightSubText,
                  fontSize: screenW * 0.034,
                ),
              ),
            ],
          ),
        ),
        InkWell(
          onTap: onAddPressed,
          borderRadius: BorderRadius.circular(13),
          child: Container(
            width: screenW * 0.12,
            height: screenW * 0.12,
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.darkPrimary.withOpacity(0.10)
                  : AppColors.lightPrimary.withOpacity(0.10),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              Icons.add_rounded,
              color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
              size: screenW * 0.075,
            ),
          ),
        ),
      ],
    );
  }
}

// =====================================================
// THIS MONTH
// =====================================================

class _ThisMonthCard extends StatelessWidget {
  final double total;
  final int expenseCount;
  final bool isDark;

  const _ThisMonthCard({
    required this.total,
    required this.expenseCount,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final monthLabel = _monthName(now.month);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(
        isDark,
        radius: 24,
      ),
      child: Row(
        children: [
          Container(
            width: 47,
            height: 47,
            decoration: BoxDecoration(
              color: (isDark ? AppColors.darkPrimary : AppColors.lightPrimary)
                  .withOpacity(0.13),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(
              Icons.account_balance_wallet_outlined,
              color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
              size: 24,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "This Month",
                  style: GoogleFonts.ibmPlexSansArabic(
                    color:
                        isDark ? AppColors.darkSubText : AppColors.lightSubText,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  "${total.toStringAsFixed(2)} JOD",
                  style: GoogleFonts.ibmPlexSansArabic(
                    color: isDark ? AppColors.darkText : AppColors.lightText,
                    fontSize: 23,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "$expenseCount ${expenseCount == 1 ? "expense" : "expenses"} • $monthLabel ${now.year}",
                  style: GoogleFonts.ibmPlexSansArabic(
                    color:
                        isDark ? AppColors.darkSubText : AppColors.lightSubText,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =====================================================
// ANALYTICS CARD
// =====================================================

class _AnalyticsCard extends StatelessWidget {
  final List<ExpenseModel> expenses;
  final _AnalyticsType selectedType;
  final bool isDark;
  final ValueChanged<_AnalyticsType> onTypeChanged;

  const _AnalyticsCard({
    required this.expenses,
    required this.selectedType,
    required this.isDark,
    required this.onTypeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final Map<String, double> data = _buildAnalyticsData(
      expenses,
      selectedType,
    );

    final double total = data.values.fold(
      0,
      (
        sum,
        value,
      ) =>
          sum + value,
    );

    final List<MapEntry<String, double>> entries = data.entries.toList()
      ..sort(
        (
          a,
          b,
        ) =>
            b.value.compareTo(a.value),
      );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(
        isDark,
        radius: 24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  "Spending Analytics",
                  style: GoogleFonts.ibmPlexSansArabic(
                    color: isDark ? AppColors.darkText : AppColors.lightText,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Icon(
                Icons.donut_large_outlined,
                color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
              ),
            ],
          ),
          const SizedBox(height: 15),
          _AnalyticsSelector(
            selectedType: selectedType,
            isDark: isDark,
            onChanged: onTypeChanged,
          ),
          const SizedBox(height: 20),
          if (entries.isEmpty || total <= 0)
            SizedBox(
              height: 200,
              child: Center(
                child: Text(
                  "No analytics data yet",
                  style: GoogleFonts.ibmPlexSansArabic(
                    color:
                        isDark ? AppColors.darkSubText : AppColors.lightSubText,
                  ),
                ),
              ),
            )
          else
            Column(
              children: [
                SizedBox(
                  height: 225,
                  child: Row(
                    children: [
                      Expanded(
                        flex: 5,
                        child: _AnalyticsPieChart(
                          entries: entries,
                          total: total,
                          selectedType: selectedType,
                          isDark: isDark,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        flex: 4,
                        child: _AnalyticsLegend(
                          entries: entries,
                          total: total,
                          isDark: isDark,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                _WeeklySpendingChart(
                  expenses: expenses,
                  isDark: isDark,
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _AnalyticsSelector extends StatelessWidget {
  final _AnalyticsType selectedType;
  final bool isDark;
  final ValueChanged<_AnalyticsType> onChanged;

  const _AnalyticsSelector({
    required this.selectedType,
    required this.isDark,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 66,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkBorder.withOpacity(0.5)
            : AppColors.lightBorder.withOpacity(0.5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        children: [
          _AnalyticsTab(
            label: "Payment",
            icon: Icons.credit_card_outlined,
            isSelected: selectedType == _AnalyticsType.payment,
            isDark: isDark,
            onTap: () => onChanged(_AnalyticsType.payment),
          ),
          _AnalyticsTab(
            label: "Movement",
            icon: Icons.repeat_rounded,
            isSelected: selectedType == _AnalyticsType.movement,
            isDark: isDark,
            onTap: () => onChanged(_AnalyticsType.movement),
          ),
          _AnalyticsTab(
            label: "Source",
            icon: Icons.input_rounded,
            isSelected: selectedType == _AnalyticsType.source,
            isDark: isDark,
            onTap: () => onChanged(_AnalyticsType.source),
          ),
          _AnalyticsTab(
            label: "Need / Want",
            icon: Icons.balance_rounded,
            isSelected: selectedType == _AnalyticsType.needWant,
            isDark: isDark,
            onTap: () => onChanged(_AnalyticsType.needWant),
          ),
          _AnalyticsTab(
            label: "Category",
            icon: Icons.category_outlined,
            isSelected: selectedType == _AnalyticsType.category,
            isDark: isDark,
            onTap: () => onChanged(_AnalyticsType.category),
          ),
        ],
      ),
    );
  }
}

class _AnalyticsTab extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  const _AnalyticsTab({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color selectedColor =
        isDark ? AppColors.darkPrimary : AppColors.lightPrimary;

    return SizedBox(
      width: 104,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(11),
        child: AnimatedContainer(
          duration: const Duration(
            milliseconds: 180,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: 5,
            vertical: 10,
          ),
          decoration: BoxDecoration(
            color: isSelected
                ? selectedColor.withOpacity(0.13)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
            border: isSelected
                ? Border.all(
                    color: selectedColor.withOpacity(0.28),
                  )
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected
                    ? selectedColor
                    : (isDark ? AppColors.darkSubText : AppColors.lightSubText),
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  style: GoogleFonts.ibmPlexSansArabic(
                    color: isSelected
                        ? selectedColor
                        : (isDark
                            ? AppColors.darkSubText
                            : AppColors.lightSubText),
                    fontSize: 10,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
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

class _AnalyticsPieChart extends StatelessWidget {
  final List<MapEntry<String, double>> entries;
  final double total;
  final _AnalyticsType selectedType;
  final bool isDark;

  const _AnalyticsPieChart({
    required this.entries,
    required this.total,
    required this.selectedType,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        PieChart(
          PieChartData(
            centerSpaceRadius: 48,
            sectionsSpace: 3,
            startDegreeOffset: -90,
            borderData: FlBorderData(
              show: false,
            ),
            sections: List.generate(
              entries.length,
              (
                index,
              ) {
                final entry = entries[index];

                final double percentage =
                    total == 0 ? 0 : entry.value / total * 100;

                return PieChartSectionData(
                  value: entry.value,
                  color: _analyticsColor(
                    index,
                  ),
                  radius: 27,
                  showTitle: percentage >= 12,
                  title: "${percentage.round()}%",
                  titleStyle: TextStyle(
                    color: isDark ? AppColors.darkText : AppColors.lightText,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                );
              },
            ),
          ),
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _analyticsCenterIcon(
                selectedType,
              ),
              color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
              size: 20,
            ),
            const SizedBox(height: 4),
            Text(
              _analyticsCenterText(
                selectedType,
              ),
              style: GoogleFonts.ibmPlexSansArabic(
                color: isDark ? AppColors.darkText : AppColors.lightText,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _AnalyticsLegend extends StatelessWidget {
  final List<MapEntry<String, double>> entries;
  final double total;
  final bool isDark;

  const _AnalyticsLegend({
    required this.entries,
    required this.total,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: entries.length,
      separatorBuilder: (
        context,
        index,
      ) =>
          const SizedBox(height: 12),
      itemBuilder: (
        context,
        index,
      ) {
        final entry = entries[index];

        final double percentage = total == 0 ? 0 : entry.value / total * 100;

        return Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: _analyticsColor(
                  index,
                ),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                entry.key,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.ibmPlexSansArabic(
                  color: isDark ? AppColors.darkText : AppColors.lightText,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 5),
            Text(
              "${percentage.round()}%",
              style: GoogleFonts.ibmPlexSansArabic(
                color: isDark ? AppColors.darkSubText : AppColors.lightSubText,
                fontSize: 9,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        );
      },
    );
  }
}

// =====================================================
// WEEKLY SPENDING
// =====================================================

class _WeeklySpendingChart extends StatelessWidget {
  final List<ExpenseModel> expenses;
  final bool isDark;

  const _WeeklySpendingChart({
    required this.expenses,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final values = _weeklyTotals(expenses);
    final maxValue = values.fold<double>(
      0,
      (current, value) => value > current ? value : current,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkBorder.withOpacity(0.42)
            : AppColors.lightBorder.withOpacity(0.42),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.show_chart_rounded,
                size: 19,
                color: isDark ? AppColors.darkAccent : AppColors.lightAccent,
              ),
              const SizedBox(width: 7),
              Text(
                "Last 7 Days",
                style: GoogleFonts.ibmPlexSansArabic(
                  color: isDark ? AppColors.darkText : AppColors.lightText,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 125,
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: maxValue <= 0 ? 10 : maxValue * 1.22,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxValue <= 0 ? 2 : (maxValue * 1.22) / 4,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: (isDark
                              ? AppColors.darkBorder
                              : AppColors.lightBorder)
                          .withOpacity(0.75),
                      strokeWidth: 1,
                    );
                  },
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 1,
                      reservedSize: 24,
                      getTitlesWidget: (value, meta) {
                        final labels = _lastSevenDayLabels();
                        final index = value.toInt();
                        if (index < 0 || index >= labels.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            labels[index],
                            style: GoogleFonts.ibmPlexSansArabic(
                              color: isDark
                                  ? AppColors.darkSubText
                                  : AppColors.lightSubText,
                              fontSize: 8,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                lineTouchData: LineTouchData(
                  enabled: true,
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (spots) {
                      return spots
                          .map(
                            (spot) => LineTooltipItem(
                              "${spot.y.toStringAsFixed(1)} JOD",
                              GoogleFonts.ibmPlexSansArabic(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                              ),
                            ),
                          )
                          .toList();
                    },
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: List.generate(
                      values.length,
                      (index) => FlSpot(
                        index.toDouble(),
                        values[index],
                      ),
                    ),
                    isCurved: true,
                    curveSmoothness: 0.28,
                    color:
                        isDark ? AppColors.darkAccent : AppColors.lightAccent,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        return FlDotCirclePainter(
                          radius: 3,
                          color: isDark
                              ? AppColors.darkAccent
                              : AppColors.lightAccent,
                          strokeWidth: 2,
                          strokeColor: isDark
                              ? AppColors.darkBackground
                              : AppColors.lightBackground,
                        );
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      color: (isDark
                              ? AppColors.darkAccent
                              : AppColors.lightAccent)
                          .withOpacity(0.10),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =====================================================
// ALPHA INSIGHT
// =====================================================

class _AlphaInsightCard extends StatelessWidget {
  final String insight;
  final bool isDark;

  const _AlphaInsightCard({
    required this.insight,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkAccent.withOpacity(0.2)
            : AppColors.lightAccent.withOpacity(0.2),
        borderRadius: BorderRadius.circular(21),
        border: Border.all(
          color: isDark ? AppColors.darkAccent : AppColors.lightAccent,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 43,
            height: 43,
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.darkAccent.withOpacity(0.12)
                  : AppColors.lightAccent.withOpacity(0.12),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              Icons.auto_awesome_rounded,
              color: isDark ? AppColors.darkAccent : AppColors.lightAccent,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Alpha Insight",
                  style: GoogleFonts.ibmPlexSansArabic(
                    color: isDark ? AppColors.darkText : AppColors.lightText,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  insight.trim().isEmpty
                      ? "Your personalized spending insight will appear here."
                      : insight,
                  style: GoogleFonts.ibmPlexSansArabic(
                    color: isDark ? AppColors.darkText : AppColors.lightText,
                    fontSize: 13,
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
}

// =====================================================
// RECENT EXPENSES
// =====================================================

class _RecentExpensesHeader extends StatelessWidget {
  final int count;
  final bool isDark;
  final double screenW;

  const _RecentExpensesHeader({
    required this.count,
    required this.isDark,
    required this.screenW,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            "Recent Expenses",
            style: GoogleFonts.ibmPlexSansArabic(
              color: isDark ? AppColors.darkText : AppColors.lightText,
              fontSize: screenW * 0.048,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}

// =====================================================
// ANALYTICS HELPERS
// =====================================================

Map<String, double> _buildAnalyticsData(
  List<ExpenseModel> expenses,
  _AnalyticsType type,
) {
  final Map<String, double> result = {};

  for (final expense in expenses) {
    final Map<String, dynamic> json = expense.toJson();

    final double amount = _toDouble(
      json['amount'] ?? json['expenseAmount'] ?? json['value'],
    );

    final String label;

    switch (type) {
      case _AnalyticsType.payment:
        label = _readLabel(
          json,
          const [
            'paymentMethod',
            'payment_method',
            'payment',
          ],
          fallback: 'Unknown',
        );
        break;

      case _AnalyticsType.movement:
        label = _readLabel(
          json,
          const [
            'movementType',
            'movement_type',
            'movement',
          ],
          fallback: 'One-time',
        );
        break;

      case _AnalyticsType.source:
        label = _readLabel(
          json,
          const [
            'source',
            'expenseSource',
            'expense_source',
            'inputSource',
            'input_source',
          ],
          fallback: 'Manual',
        );
        break;

      case _AnalyticsType.needWant:
        label = _readLabel(
          json,
          const [
            'expenseType',
            'expense_type',
            'type',
          ],
          fallback: 'Need',
        );
        break;

      case _AnalyticsType.category:
        label = _readLabel(
          json,
          const [
            'category',
            'categoryName',
            'category_name',
          ],
          fallback: 'Other',
        );
        break;
    }

    result[label] = (result[label] ?? 0) + (amount > 0 ? amount : 1);
  }

  result.removeWhere(
    (
      key,
      value,
    ) =>
        value <= 0,
  );

  return result;
}

String _readLabel(
  Map<String, dynamic> json,
  List<String> keys, {
  required String fallback,
}) {
  for (final key in keys) {
    final dynamic value = json[key];

    if (value == null) {
      continue;
    }

    final String cleaned = _cleanEnumText(
      value.toString(),
    );

    if (cleaned.isNotEmpty) {
      return cleaned;
    }
  }

  return fallback;
}

String _cleanEnumText(
  String value,
) {
  String cleaned = value.trim();

  if (cleaned.contains('.')) {
    cleaned = cleaned.split('.').last;
  }

  cleaned = cleaned.replaceAll(
    '_',
    ' ',
  );

  if (cleaned.isEmpty) {
    return '';
  }

  return cleaned
      .split(' ')
      .where(
        (
          word,
        ) =>
            word.isNotEmpty,
      )
      .map(
        (
          word,
        ) =>
            '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}',
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

List<double> _weeklyTotals(
  List<ExpenseModel> expenses,
) {
  final now = DateTime.now();
  final start = DateTime(
    now.year,
    now.month,
    now.day,
  ).subtract(const Duration(days: 6));

  final totals = List<double>.filled(7, 0);

  for (final expense in expenses) {
    final json = expense.toJson();
    final date = _readExpenseDate(json);

    if (date == null) {
      continue;
    }

    final normalized = DateTime(
      date.year,
      date.month,
      date.day,
    );

    final index = normalized.difference(start).inDays;

    if (index < 0 || index >= 7) {
      continue;
    }

    totals[index] += _toDouble(
      json['amount'] ?? json['expenseAmount'] ?? json['value'],
    );
  }

  return totals;
}

DateTime? _readExpenseDate(
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
    return DateTime.fromMillisecondsSinceEpoch(value);
  }

  if (value != null) {
    return DateTime.tryParse(value.toString());
  }

  return null;
}

List<String> _lastSevenDayLabels() {
  final now = DateTime.now();

  return List.generate(
    7,
    (index) {
      final date = now.subtract(
        Duration(days: 6 - index),
      );

      const labels = [
        'M',
        'T',
        'W',
        'T',
        'F',
        'S',
        'S',
      ];

      return labels[date.weekday - 1];
    },
  );
}

String _monthName(
  int month,
) {
  const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  return months[month - 1];
}

Color _analyticsColor(
  int index,
) {
  const colors = [
    Color(0xFF34D399),
    Color(0xFF14B8A6),
    Color(0xFFF4C95D),
    Color(0xFF4F9CF9),
    Color(0xFF9B7EDE),
    Color(0xFFFF6B6B),
    Color(0xFFEC76A8),
  ];

  return colors[index % colors.length];
}

IconData _analyticsCenterIcon(
  _AnalyticsType type,
) {
  switch (type) {
    case _AnalyticsType.payment:
      return Icons.credit_card_outlined;

    case _AnalyticsType.movement:
      return Icons.repeat_rounded;

    case _AnalyticsType.source:
      return Icons.input_rounded;

    case _AnalyticsType.needWant:
      return Icons.balance_rounded;

    case _AnalyticsType.category:
      return Icons.category_outlined;
  }
}

String _analyticsCenterText(
  _AnalyticsType type,
) {
  switch (type) {
    case _AnalyticsType.payment:
      return "Payment";

    case _AnalyticsType.movement:
      return "Movement";

    case _AnalyticsType.source:
      return "Source";

    case _AnalyticsType.needWant:
      return "Need / Want";

    case _AnalyticsType.category:
      return "Category";
  }
}

BoxDecoration _cardDecoration(
  bool isDark, {
  required double radius,
}) {
  return BoxDecoration(
    color: isDark
        ? AppColors.darkPrimary.withOpacity(0.04)
        : AppColors.lightPrimary.withOpacity(0.04),
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(
      color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
    ),
  );
}
