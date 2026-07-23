import 'package:alpha_app/core/utils/app_colors.dart';
import 'package:alpha_app/models/income_model.dart';
import 'package:alpha_app/providers/income_provider.dart';
import 'package:alpha_app/providers/themeprovider.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import 'package:alpha_app/core/utils/dashboard_action_result.dart';
import 'package:alpha_app/screens/main_screen.dart';

class AddIncomeScreen extends StatefulWidget {
  const AddIncomeScreen({super.key});

  @override
  State<AddIncomeScreen> createState() => _AddIncomeScreenState();
}

class _AddIncomeScreenState extends State<AddIncomeScreen> {
  final _amountController = TextEditingController();
  final _sourceController = TextEditingController();
  final _descriptionController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  bool _isRecurring = false;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _amountController.dispose();
    _sourceController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _submit() async {
    if (_isSubmitting) return;

    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a valid amount')));
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    final income = IncomeModel(
      id: '',
      amount: amount,
      source: _sourceController.text.isEmpty ? 'other' : _sourceController.text,
      description: _descriptionController.text,
      incomeDate: _selectedDate,
      isRecurring: _isRecurring,
      createdAt: DateTime.now(),
    );

    final provider = context.read<IncomeProvider>();
    final success = await provider.createIncome(income);

    if (success && mounted) {
      Navigator.pop(context, DashboardActionResult.created);
    } else if (mounted) {
      setState(() {
        _isSubmitting = false;
      });
      final error = provider.errorMessage ?? 'An error occurred';
      if (error.contains('NO_ACTIVE_FINANCIAL_CYCLE') ||
          error.contains('CYCLE_NOT_FOUND')) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('No Active Financial Cycle'),
            content: const Text(
                'Start a financial cycle before adding transactions.'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel')),
              ElevatedButton(
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
                child: const Text('Start Financial Cycle'),
              )
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(error),
          backgroundColor: AppColors.darkError,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<Themeprovider>().isDark;
    final isLoading = context.watch<IncomeProvider>().isLoading;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: Text('Add Income',
            style: GoogleFonts.ibmPlexSansArabic(
                color: isDark ? AppColors.darkText : AppColors.lightText)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(
            color: isDark ? AppColors.darkText : AppColors.lightText),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _amountController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              style: TextStyle(
                  color: isDark ? AppColors.darkText : AppColors.lightText),
              decoration: InputDecoration(
                labelText: 'Amount',
                labelStyle: TextStyle(
                    color: isDark
                        ? AppColors.darkSubText
                        : AppColors.lightSubText),
                filled: true,
                fillColor: isDark ? AppColors.darkCard : AppColors.lightCard,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _sourceController,
              style: TextStyle(
                  color: isDark ? AppColors.darkText : AppColors.lightText),
              decoration: InputDecoration(
                labelText: 'Source (e.g. Salary, Gift, Bonus)',
                labelStyle: TextStyle(
                    color: isDark
                        ? AppColors.darkSubText
                        : AppColors.lightSubText),
                filled: true,
                fillColor: isDark ? AppColors.darkCard : AppColors.lightCard,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descriptionController,
              style: TextStyle(
                  color: isDark ? AppColors.darkText : AppColors.lightText),
              decoration: InputDecoration(
                labelText: 'Description (Optional)',
                labelStyle: TextStyle(
                    color: isDark
                        ? AppColors.darkSubText
                        : AppColors.lightSubText),
                filled: true,
                fillColor: isDark ? AppColors.darkCard : AppColors.lightCard,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              tileColor: isDark ? AppColors.darkCard : AppColors.lightCard,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              title: Text('Date',
                  style: TextStyle(
                      color:
                          isDark ? AppColors.darkText : AppColors.lightText)),
              trailing: Text(DateFormat('yyyy-MM-dd').format(_selectedDate),
                  style: TextStyle(
                      color: isDark
                          ? AppColors.darkPrimary
                          : AppColors.lightPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
              onTap: _pickDate,
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              tileColor: isDark ? AppColors.darkCard : AppColors.lightCard,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              title: Text('Is this a recurring income?',
                  style: TextStyle(
                      color:
                          isDark ? AppColors.darkText : AppColors.lightText)),
              value: _isRecurring,
              onChanged: (val) => setState(() => _isRecurring = val),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: isLoading ? null : _submit,
              child: isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Save Income',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
