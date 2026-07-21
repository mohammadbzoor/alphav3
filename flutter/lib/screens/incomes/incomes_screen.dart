import 'package:alpha_app/core/utils/app_colors.dart';
import 'package:alpha_app/models/income_model.dart';
import 'package:alpha_app/providers/income_provider.dart';
import 'package:alpha_app/providers/themeprovider.dart';
import 'package:alpha_app/screens/incomes/add_income_screen.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class IncomesScreen extends StatefulWidget {
  const IncomesScreen({super.key});

  @override
  State<IncomesScreen> createState() => _IncomesScreenState();
}

class _IncomesScreenState extends State<IncomesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<IncomeProvider>().loadIncomes();
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<Themeprovider>();
    final isDark = themeProvider.isDark;
    final incomeProvider = context.watch<IncomeProvider>();

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: Text('Incomes', style: GoogleFonts.ibmPlexSansArabic(
          color: isDark ? AppColors.darkText : AppColors.lightText,
        )),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: isDark ? AppColors.darkText : AppColors.lightText),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const AddIncomeScreen()));
        },
        backgroundColor: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: incomeProvider.isLoading
          ? Center(child: CircularProgressIndicator(color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary))
          : incomeProvider.errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(incomeProvider.errorMessage!, style: TextStyle(color: isDark ? AppColors.darkError : AppColors.lightError)),
                      ElevatedButton(
                        onPressed: () => incomeProvider.loadIncomes(),
                        child: const Text('Retry'),
                      )
                    ],
                  ),
                )
              : incomeProvider.incomes.isEmpty
                  ? Center(
                      child: Text('No incomes recorded yet.', style: TextStyle(color: isDark ? AppColors.darkSubText : AppColors.lightSubText)),
                    )
                  : ListView.builder(
                      itemCount: incomeProvider.incomes.length,
                      padding: const EdgeInsets.all(16),
                      itemBuilder: (context, index) {
                        final income = incomeProvider.incomes[index];
                        return _IncomeCard(income: income, isDark: isDark, onDelete: () {
                          incomeProvider.deleteIncome(income.id).then((success) {
                            if (!success && context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text(incomeProvider.errorMessage ?? 'Delete failed'),
                                backgroundColor: AppColors.darkError,
                              ));
                            }
                          });
                        });
                      },
                    ),
    );
  }
}

class _IncomeCard extends StatelessWidget {
  final IncomeModel income;
  final bool isDark;
  final VoidCallback onDelete;

  const _IncomeCard({required this.income, required this.isDark, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: isDark ? AppColors.darkCard : AppColors.lightCard,
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        title: Text(income.source.toUpperCase(), style: TextStyle(
          color: isDark ? AppColors.darkText : AppColors.lightText,
          fontWeight: FontWeight.bold,
        )),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(DateFormat('MMM dd, yyyy').format(income.incomeDate), style: TextStyle(color: isDark ? AppColors.darkSubText : AppColors.lightSubText)),
            if (income.description.isNotEmpty)
              Text(income.description, style: TextStyle(color: isDark ? AppColors.darkSubText : AppColors.lightSubText)),
            Text(income.isRecurring ? 'Recurring' : 'Unexpected', style: TextStyle(
              color: income.isRecurring ? Colors.blue : Colors.orange,
              fontWeight: FontWeight.w500,
            )),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${income.amount} JOD', style: TextStyle(
              color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            )),
            IconButton(
              icon: Icon(Icons.delete, color: isDark ? AppColors.darkError : AppColors.lightError),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}
