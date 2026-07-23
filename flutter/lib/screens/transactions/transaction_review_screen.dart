import 'package:flutter/material.dart';
import 'package:alpha_app/models/transaction_draft_model.dart';
import 'package:alpha_app/services/api_service.dart';
import 'package:alpha_app/core/utils/finance_mappings.dart';
import 'package:alpha_app/core/utils/dashboard_action_result.dart';
import 'package:alpha_app/providers/cycle_provider.dart';
import 'package:alpha_app/providers/financial_profile_provider.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import 'package:alpha_app/core/utils/app_colors.dart';
import 'package:alpha_app/core/utils/device.dart';
import 'package:alpha_app/providers/themeprovider.dart';
import 'package:alpha_app/screens/expenses/expense_date_screen.dart';
import 'package:alpha_app/widgets/custom_textfield.dart';
import 'package:alpha_app/widgets/multi_select_chip.dart';
import 'package:alpha_app/widgets/option_chip.dart';
import 'package:alpha_app/widgets/app_button.dart';
import 'package:google_fonts/google_fonts.dart';

class TransactionReviewScreen extends StatefulWidget {
  final List<TransactionDraft> transactions;
  final int currentIndex;

  const TransactionReviewScreen({
    super.key,
    required this.transactions,
    required this.currentIndex,
  });

  @override
  State<TransactionReviewScreen> createState() =>
      _TransactionReviewScreenState();
}

class _TransactionReviewScreenState extends State<TransactionReviewScreen> {
  final _formKey = GlobalKey<FormState>();

  late TransactionDraft _draft;

  String? _transactionType;
  String? _bucket;
  String? _category;
  String? _paymentMethod;
  String? _movementType;
  String? _frequency;
  String? _flexibility;
  String? _nextDueDate;

  bool _isSaving = false;

  final List<String> _buckets = ['needs', 'wants', 'savings'];

  bool _initFailed = false;

  int _currentIndex = 0;
  bool _hasSavedAny = false;
  final Set<int> _savedIndexes = {};

  late TextEditingController _nameController;
  late TextEditingController _amountController;
  late TextEditingController _dateController;
  late TextEditingController _noteController;
  late TextEditingController _sourceController;

  @override
  void initState() {
    super.initState();
    debugPrint('VOICE reviewOpened=true');
    _currentIndex = widget.currentIndex;
    _nameController = TextEditingController();
    _amountController = TextEditingController();
    _dateController = TextEditingController();
    _noteController = TextEditingController();
    _sourceController = TextEditingController();
    _loadTransactionAtIndex(_currentIndex);
  }

  void _loadTransactionAtIndex(int index) {
    debugPrint('RECEIPT reviewInitStarted index=$index');
    try {
      _draft = widget.transactions[index];

      _transactionType = _draft.transactionType;
      if (_draft.sourceType == 'image' && _transactionType == null) {
        _transactionType = 'expense';
      }

      _bucket = _draft.bucket;
      if (_bucket != null && !_buckets.contains(_bucket)) {
        _bucket = null;
      }

      _category = _draft.category;
      if (_bucket == 'needs' &&
          _category != null &&
          !FinanceMappings.needsCategories.values.contains(_category)) {
        _category = null;
      } else if (_bucket == 'wants' &&
          _category != null &&
          !FinanceMappings.wantsCategories.values.contains(_category)) {
        _category = null;
      } else if (_bucket == null) {
        _category = null;
      }

      if (_transactionType == 'income') {
        _category = _draft.category;
      }

      _paymentMethod = _draft.paymentMethod;
      if (_paymentMethod != null &&
          !FinanceMappings.paymentMethods.values.contains(_paymentMethod)) {
        _paymentMethod = null;
      }

      _movementType = _draft.movementType ?? 'occasional';
      _frequency = _draft.frequency;
      _flexibility = _draft.flexibility;
      _nextDueDate = _draft.transactionDate?.toIso8601String().split('T')[0];

      _nameController.text = _draft.description ?? '';

      String initialAmount = '';
      if (_draft.amount != null) {
        initialAmount = _draft.amount!.toString();
        if (initialAmount.endsWith('.0')) {
          initialAmount = initialAmount.substring(0, initialAmount.length - 2);
        }
      }
      _amountController.text = initialAmount;

      _dateController.text = _draft.transactionDate != null
          ? DateFormat('yyyy-MM-dd').format(_draft.transactionDate!)
          : '';

      _noteController.text = '';
      _sourceController.text =
          _transactionType == 'income' ? (_category ?? '') : '';

      debugPrint('RECEIPT reviewInitCompleted index=$index');
    } catch (e) {
      debugPrint('RECEIPT reviewInitFailed: $e');
      _initFailed = true;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _dateController.dispose();
    _noteController.dispose();
    _sourceController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSaving || _savedIndexes.contains(_currentIndex)) return;

    final cycleProvider = context.read<CycleProvider>();
    if (!cycleProvider.hasActiveCycle) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Start a financial cycle before adding transactions.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final isExpense = _transactionType == 'expense';
      final isRecurring = _movementType == 'recurring';

      String endpoint;
      Map<String, dynamic> payload;

      final amount =
          double.tryParse(_amountController.text.replaceAll(',', ''));

      if (isExpense && isRecurring) {
        endpoint = '/commitments';
        payload = {
          'amount': amount,
          'name': _draft.description,
          'frequency': _frequency,
          'flexibility': _flexibility,
          'nextDueDate': _nextDueDate,
          'sourceType': _draft.sourceType ?? 'manual',
        };
      } else if (isExpense && !isRecurring) {
        endpoint = '/expenses';
        payload = {
          'amount': amount,
          'bucket': _bucket,
          'category': _category,
          'paymentMethod': _paymentMethod,
          'expenseDate':
              _draft.transactionDate?.toIso8601String().split('T')[0] ??
                  DateTime.now().toIso8601String().split('T')[0],
          'description': _draft.description,
          'sourceType': _draft.sourceType ?? 'manual',
        };
      } else {
        endpoint = '/incomes';
        payload = {
          'amount': amount,
          'source': _category,
          'description': _draft.description,
          'incomeDate':
              _draft.transactionDate?.toIso8601String().split('T')[0] ??
                  DateTime.now().toIso8601String().split('T')[0],
          'isRecurring': isRecurring,
          'sourceType': _draft.sourceType ?? 'manual',
        };
      }

      final response = await ApiService.post(endpoint, body: payload);

      if (response.statusCode == 200 || response.statusCode == 201) {
        _hasSavedAny = true;
        _savedIndexes.add(_currentIndex);
        _goToNext();
      } else {
        final error = await ApiService.getErrorMessage(response);
        if (mounted) {
          if (error.contains('CYCLE_NOT_FOUND') ||
              error.contains('NO_ACTIVE_FINANCIAL_CYCLE')) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text(
                    'Start a financial cycle before adding transactions.')));
          } else if (response.statusCode == 401 || response.statusCode == 403) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Authentication failed. Please log in again.')));
          } else if (response.statusCode >= 500) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content:
                    Text('Unable to save the transaction. Please try again.')));
          } else {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(error)));
          }
        }
      }
    } catch (e) {
      if (mounted) {
        if (e.toString().contains('SocketException') ||
            e.toString().contains('TimeoutException')) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text(
                  'Unable to connect to the server. Check your connection and try again.')));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content:
                  Text('Unable to save the transaction. Please try again.')));
        }
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _goToNext() async {
    if (_currentIndex < widget.transactions.length - 1) {
      setState(() {
        _currentIndex++;
        _loadTransactionAtIndex(_currentIndex);
      });
    } else {
      Navigator.pop(context, DashboardActionResult.created);
    }
  }

  bool _isDateInFuture(DateTime? date) {
    if (date == null) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final toCheck = DateTime(date.year, date.month, date.day);
    return toCheck.isAfter(today);
  }

  bool get _isValid {
    if (_transactionType == null) return false;
    final amountText = _amountController.text.replaceAll(',', '');
    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0 || amount.isNaN || amount.isInfinite)
      return false;

    if (_movementType == 'occasional') {
      if (_transactionType == 'expense') {
        if (_bucket == null || _category == null || _paymentMethod == null)
          return false;
        if (_nameController.text.trim().isEmpty) return false;
        if (_draft.transactionDate == null) return false;
        if (_isDateInFuture(_draft.transactionDate)) return false;
      } else {
        if (_category == null || _category!.trim().isEmpty) return false;
        if (_nameController.text.trim().isEmpty) return false;
        if (_draft.transactionDate == null) return false;
        if (_isDateInFuture(_draft.transactionDate)) return false;
      }
    } else {
      if (_frequency == null || _nextDueDate == null) return false;
      if (_nameController.text.trim().isEmpty) return false;
      if (_transactionType == 'expense' && _flexibility == null) return false;
      if (_transactionType == 'expense' && _category == null) return false;
      if (_transactionType == 'expense' && _bucket == null) return false;
      if (_transactionType == 'income' &&
          (_category == null || _category!.trim().isEmpty)) return false;
    }
    return true;
  }

  List<String> _getWarnings(String? currency) {
    final List<String> warnings = [];
    final amountText = _amountController.text.replaceAll(',', '');
    final amount = double.tryParse(amountText);

    if (_movementType == null) warnings.add('Movement Type');
    if (_transactionType == null) warnings.add('Transaction Type');

    if (_transactionType == 'expense') {
      if (_bucket == null) warnings.add('Expense Type');
      if (_category == null) warnings.add('Category');
      if (_nameController.text.trim().isEmpty) warnings.add('Expense Name');
      if (amount == null || amount <= 0) warnings.add('Amount');

      if (_movementType == 'occasional') {
        if (_paymentMethod == null) warnings.add('Payment Method');
        if (_draft.transactionDate == null) {
          warnings.add('Transaction Date');
        } else if (_isDateInFuture(_draft.transactionDate)) {
          warnings.add('Transaction Date (must not be in the future)');
        }
      } else {
        if (_frequency == null) warnings.add('Coverage Period');
        if (_flexibility == null) warnings.add('Flexibility');
        if (_nextDueDate == null) warnings.add('Next Due Date');
      }
    } else if (_transactionType == 'income') {
      if (_category == null || _category!.trim().isEmpty)
        warnings.add('Source');
      if (_nameController.text.trim().isEmpty) warnings.add('Description');
      if (amount == null || amount <= 0) warnings.add('Amount');
      if (_movementType == 'occasional') {
        if (_draft.transactionDate == null) {
          warnings.add('Income Date');
        } else if (_isDateInFuture(_draft.transactionDate)) {
          warnings.add('Income Date (must not be in the future)');
        }
      } else {
        if (_frequency == null) warnings.add('Coverage Period');
        if (_nextDueDate == null) warnings.add('Next Due Date');
      }
    }

    if (currency == null) warnings.add('Currency profile missing');

    return warnings;
  }

  String? get _disabledReason {
    if (_movementType == null) return 'Select a movement type.';
    if (_transactionType == null) return 'Select a transaction type.';

    final amountText = _amountController.text.replaceAll(',', '');
    final amount = double.tryParse(amountText);

    if (_movementType == 'occasional') {
      if (_transactionType == 'expense') {
        if (_bucket == null) return 'Select an expense type.';
        if (_category == null) return 'Select a category.';
        if (_nameController.text.trim().isEmpty)
          return 'Enter an expense name.';
        if (amount == null || amount <= 0) return 'Enter a valid amount.';
        if (_paymentMethod == null) return 'Select a payment method.';
        if (_draft.transactionDate == null ||
            _isDateInFuture(_draft.transactionDate))
          return 'Select a valid transaction date.';
      } else {
        if (_category == null || _category!.trim().isEmpty)
          return 'Select a source.';
        if (_nameController.text.trim().isEmpty) return 'Enter a description.';
        if (amount == null || amount <= 0) return 'Enter a valid amount.';
        if (_draft.transactionDate == null ||
            _isDateInFuture(_draft.transactionDate))
          return 'Select a valid transaction date.';
      }
    } else {
      if (_transactionType == 'expense') {
        if (_bucket == null) return 'Select an expense type.';
        if (_category == null) return 'Select a category.';
        if (_nameController.text.trim().isEmpty)
          return 'Enter an expense name.';
        if (amount == null || amount <= 0) return 'Enter a valid amount.';
        if (_frequency == null) return 'Select a coverage period.';
        if (_flexibility == null) return 'Select flexibility.';
        if (_nextDueDate == null) return 'Select a valid next due date.';
      } else {
        if (_category == null || _category!.trim().isEmpty)
          return 'Select a source.';
        if (_nameController.text.trim().isEmpty) return 'Enter a description.';
        if (amount == null || amount <= 0) return 'Enter a valid amount.';
        if (_frequency == null) return 'Select a coverage period.';
        if (_nextDueDate == null) return 'Select a valid next due date.';
      }
    }

    return null;
  }

  final List<String> _movementTypeLabels = ['Occasional', 'Recurring'];
  String? get _movementTypeLabel => _movementType == 'occasional'
      ? 'Occasional'
      : (_movementType == 'recurring' ? 'Recurring' : null);

  final List<String> _expenseTypeLabels = ['Need', 'Want'];
  String? get _expenseTypeLabel =>
      _bucket == 'needs' ? 'Need' : (_bucket == 'wants' ? 'Want' : null);

  final List<String> _frequencyLabels = [
    'Weekly',
    'Monthly',
    'Quarterly',
    'Yearly'
  ];
  String? get _frequencyLabel {
    if (_frequency == 'weekly') return 'Weekly';
    if (_frequency == 'monthly') return 'Monthly';
    if (_frequency == 'quarterly') return 'Quarterly';
    if (_frequency == 'yearly') return 'Yearly';
    return null;
  }

  final List<String> _flexibilityLabels = ['Fixed', 'Flexible'];
  String? get _flexibilityLabel {
    if (_flexibility == 'fixed') return 'Fixed';
    if (_flexibility == 'flexible') return 'Flexible';
    return null;
  }

  List<String> get _paymentMethodLabels =>
      FinanceMappings.paymentMethods.keys.toList();
  String? get _paymentMethodLabel {
    if (_paymentMethod == null) return null;
    return FinanceMappings.paymentMethods.entries
        .firstWhere((e) => e.value == _paymentMethod,
            orElse: () => const MapEntry('', ''))
        .key;
  }

  List<String> get _categoryLabels {
    if (_bucket == 'needs')
      return FinanceMappings.needsCategories.keys.toList();
    if (_bucket == 'wants')
      return FinanceMappings.wantsCategories.keys.toList();
    return [];
  }

  String? get _categoryLabel {
    if (_category == null) return null;
    if (_bucket == 'needs') {
      return FinanceMappings.needsCategories.entries
          .firstWhere((e) => e.value == _category,
              orElse: () => const MapEntry('', ''))
          .key;
    } else if (_bucket == 'wants') {
      return FinanceMappings.wantsCategories.entries
          .firstWhere((e) => e.value == _category,
              orElse: () => const MapEntry('', ''))
          .key;
    }
    return _category;
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('RECEIPT reviewBuildStarted');

    if (_initFailed) {
      return Scaffold(
        appBar: AppBar(title: const Text('Review Error')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Unable to open the transaction review.'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Back'),
              ),
            ],
          ),
        ),
      );
    }

    final themeProvider = context.watch<Themeprovider>();
    final bool isDark = themeProvider.isDark;
    final double screenW = Device.width(context);
    final double screenH = Device.height(context);

    final isExpense = _transactionType == 'expense';
    final isRecurring = _movementType == 'recurring';
    final profileProvider = context.watch<FinancialProfileProvider>();
    final currency = profileProvider.profileData?['currency']?.toString();

    final warnings = _getWarnings(currency);

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;
        if (_hasSavedAny) {
          Navigator.pop(context, DashboardActionResult.created);
        } else {
          Navigator.pop(context, null);
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
                padding: EdgeInsets.symmetric(horizontal: screenW * 0.05),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: screenH * 0.022),

                    _buildHeader(isDark: isDark, screenW: screenW),

                    SizedBox(height: screenH * 0.022),

                    _buildAISummary(
                        isDark: isDark,
                        screenW: screenW,
                        needsReview: warnings.isNotEmpty),

                    SizedBox(height: screenH * 0.03),

                    if (isExpense) ...[
                      // Movement Type
                      _SectionTitle(
                          title: "Movement Type",
                          screenW: screenW,
                          isDark: isDark),
                      SizedBox(height: screenH * 0.012),
                      OptionChip(
                        items: _movementTypeLabels,
                        selected: _movementTypeLabel,
                        onTap: (val) {
                          setState(() {
                            _movementType = val == 'Occasional'
                                ? 'occasional'
                                : 'recurring';
                            if (_movementType == 'occasional') {
                              _frequency = null;
                              _flexibility = null;
                              _nextDueDate = null;
                            }
                          });
                        },
                      ),
                      SizedBox(height: screenH * 0.022),

                      // Expense Type
                      _SectionTitle(
                          title: "Expense Type",
                          screenW: screenW,
                          isDark: isDark),
                      SizedBox(height: screenH * 0.012),
                      OptionChip(
                        items: _expenseTypeLabels,
                        selected: _expenseTypeLabel,
                        onTap: (val) {
                          setState(() {
                            _bucket = val == 'Need' ? 'needs' : 'wants';
                            _category = null;
                          });
                        },
                      ),
                      SizedBox(height: screenH * 0.022),

                      // Category
                      _SectionTitle(
                          title: "Category", screenW: screenW, isDark: isDark),
                      SizedBox(height: screenH * 0.012),
                      if (_bucket == null)
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
                          items: _categoryLabels,
                          selectedItems:
                              _categoryLabel != null ? [_categoryLabel!] : [],
                          onTap: (val) {
                            setState(() {
                              if (_bucket == 'needs') {
                                _category =
                                    FinanceMappings.needsCategories[val];
                              } else {
                                _category =
                                    FinanceMappings.wantsCategories[val];
                              }
                            });
                          },
                        ),
                      SizedBox(height: screenH * 0.025),

                      // Expense Name
                      _SectionTitle(
                          title: "Expense Name",
                          screenW: screenW,
                          isDark: isDark),
                      SizedBox(height: screenH * 0.01),
                      CustomTextfield(
                        controller: _nameController,
                        hint: "Enter expense name",
                        type: TextFieldType.name,
                        icon: Icons.receipt_long_outlined,
                        onChanged: (val) {
                          _draft.description = val;
                          setState(() {});
                        },
                      ),
                      SizedBox(height: screenH * 0.022),

                      // Amount
                      _SectionTitle(
                          title: "Amount", screenW: screenW, isDark: isDark),
                      SizedBox(height: screenH * 0.01),
                      CustomTextfield(
                        controller: _amountController,
                        hint: "Enter amount",
                        type: TextFieldType.number,
                        icon: Icons.payments_outlined,
                        suffix: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(currency ?? ""),
                        ),
                        onChanged: (val) {
                          final raw = val.replaceAll(',', '');
                          _draft.amount = double.tryParse(raw);
                          setState(() {});
                        },
                      ),
                      SizedBox(height: screenH * 0.022),

                      if (isRecurring) ...[
                        // Coverage Period
                        _SectionTitle(
                            title: "Coverage Period",
                            screenW: screenW,
                            isDark: isDark),
                        SizedBox(height: screenH * 0.012),
                        MultiSelectChip(
                          items: _frequencyLabels,
                          selectedItems:
                              _frequencyLabel != null ? [_frequencyLabel!] : [],
                          onTap: (val) {
                            setState(() {
                              if (val == 'Weekly') _frequency = 'weekly';
                              if (val == 'Monthly') _frequency = 'monthly';
                              if (val == 'Quarterly') _frequency = 'quarterly';
                              if (val == 'Yearly') _frequency = 'yearly';
                            });
                          },
                        ),
                        SizedBox(height: screenH * 0.022),

                        // Flexibility
                        _SectionTitle(
                            title: "Flexibility",
                            screenW: screenW,
                            isDark: isDark),
                        SizedBox(height: screenH * 0.012),
                        OptionChip(
                          items: _flexibilityLabels,
                          selected: _flexibilityLabel,
                          onTap: (val) {
                            setState(() {
                              if (val == 'Fixed') _flexibility = 'fixed';
                              if (val == 'Flexible') _flexibility = 'flexible';
                            });
                          },
                        ),
                        SizedBox(height: screenH * 0.022),

                        // Next Due Date
                        _SectionTitle(
                            title: "Next Due Date",
                            screenW: screenW,
                            isDark: isDark),
                        SizedBox(height: screenH * 0.01),
                        CustomTextfield(
                          controller: _dateController,
                          hint: "Select due date",
                          type: TextFieldType.date,
                          icon: Icons.calendar_month_outlined,
                          readOnly: true,
                          onTap: () async {
                            final picked = await Navigator.push<DateTime>(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ExpenseDateScreen(
                                  initialDate: _draft.transactionDate,
                                  isRecurring: true,
                                ),
                              ),
                            );
                            if (picked != null && mounted) {
                              setState(() {
                                _draft.transactionDate = picked;
                                _nextDueDate =
                                    picked.toIso8601String().split('T')[0];
                                _dateController.text =
                                    DateFormat('yyyy-MM-dd').format(picked);
                              });
                            }
                          },
                        ),
                        SizedBox(height: screenH * 0.022),
                      ] else ...[
                        // Payment Method
                        _SectionTitle(
                            title: "Payment Method",
                            screenW: screenW,
                            isDark: isDark),
                        SizedBox(height: screenH * 0.012),
                        OptionChip(
                          items: _paymentMethodLabels,
                          selected: _paymentMethodLabel,
                          onTap: (val) {
                            setState(() {
                              _paymentMethod =
                                  FinanceMappings.paymentMethods[val];
                            });
                          },
                        ),
                        SizedBox(height: screenH * 0.022),

                        // Transaction Date
                        _SectionTitle(
                            title: "Transaction Date",
                            screenW: screenW,
                            isDark: isDark),
                        SizedBox(height: screenH * 0.01),
                        CustomTextfield(
                          controller: _dateController,
                          hint: "Select transaction date",
                          type: TextFieldType.date,
                          icon: Icons.calendar_month_outlined,
                          readOnly: true,
                          onTap: () async {
                            final picked = await Navigator.push<DateTime>(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ExpenseDateScreen(
                                  initialDate: _draft.transactionDate,
                                  isRecurring: false,
                                ),
                              ),
                            );
                            if (picked != null && mounted) {
                              setState(() {
                                _draft.transactionDate = picked;
                                _dateController.text =
                                    DateFormat('yyyy-MM-dd').format(picked);
                              });
                            }
                          },
                        ),
                        if (_draft.transactionDate != null &&
                            _isDateInFuture(_draft.transactionDate))
                          Padding(
                            padding: EdgeInsets.only(top: screenH * 0.01),
                            child: Text(
                              "The extracted date is in the future. Please select a valid transaction date.",
                              style: GoogleFonts.ibmPlexSansArabic(
                                color: isDark
                                    ? AppColors.darkError
                                    : AppColors.lightError,
                                fontSize: screenW * 0.035,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        SizedBox(height: screenH * 0.022),
                      ],
                    ],

                    if (!isExpense) ...[
                      // Transaction Type
                      _SectionTitle(
                          title: "Transaction Type",
                          screenW: screenW,
                          isDark: isDark),
                      SizedBox(height: screenH * 0.012),
                      OptionChip(
                        items: const ["Expense", "Income"],
                        selected: "Income",
                        onTap: (val) {
                          setState(() {
                            _transactionType = val.toLowerCase();
                          });
                        },
                      ),
                      SizedBox(height: screenH * 0.022),

                      // Income Type or Source
                      _SectionTitle(
                          title: "Income Type or Source",
                          screenW: screenW,
                          isDark: isDark),
                      SizedBox(height: screenH * 0.01),
                      CustomTextfield(
                        controller: _sourceController,
                        hint: "Enter source",
                        type: TextFieldType.name,
                        icon: Icons.source_outlined,
                        onChanged: (val) {
                          _category = val;
                          setState(() {});
                        },
                      ),
                      SizedBox(height: screenH * 0.022),

                      // Description
                      _SectionTitle(
                          title: "Description",
                          screenW: screenW,
                          isDark: isDark),
                      SizedBox(height: screenH * 0.01),
                      CustomTextfield(
                        controller: _nameController,
                        hint: "Enter description",
                        type: TextFieldType.name,
                        icon: Icons.receipt_long_outlined,
                        onChanged: (val) {
                          _draft.description = val;
                          setState(() {});
                        },
                      ),
                      SizedBox(height: screenH * 0.022),

                      // Amount
                      _SectionTitle(
                          title: "Amount", screenW: screenW, isDark: isDark),
                      SizedBox(height: screenH * 0.01),
                      CustomTextfield(
                        controller: _amountController,
                        hint: "Enter amount",
                        type: TextFieldType.number,
                        icon: Icons.payments_outlined,
                        suffix: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(currency ?? ""),
                        ),
                        onChanged: (val) {
                          final raw = val.replaceAll(',', '');
                          _draft.amount = double.tryParse(raw);
                          setState(() {});
                        },
                      ),
                      SizedBox(height: screenH * 0.022),

                      // Income Date
                      _SectionTitle(
                          title: "Income Date",
                          screenW: screenW,
                          isDark: isDark),
                      SizedBox(height: screenH * 0.01),
                      CustomTextfield(
                        controller: _dateController,
                        hint: "Select income date",
                        type: TextFieldType.date,
                        icon: Icons.calendar_month_outlined,
                        readOnly: true,
                        onTap: () async {
                          final picked = await Navigator.push<DateTime>(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ExpenseDateScreen(
                                initialDate: _draft.transactionDate,
                                isRecurring: isRecurring,
                              ),
                            ),
                          );
                          if (picked != null && mounted) {
                            setState(() {
                              _draft.transactionDate = picked;
                              _dateController.text =
                                  DateFormat('yyyy-MM-dd').format(picked);
                              if (isRecurring) {
                                _nextDueDate =
                                    picked.toIso8601String().split('T')[0];
                              }
                            });
                          }
                        },
                      ),
                      if (!isRecurring &&
                          _draft.transactionDate != null &&
                          _isDateInFuture(_draft.transactionDate))
                        Padding(
                          padding: EdgeInsets.only(top: screenH * 0.01),
                          child: Text(
                            "The extracted date is in the future. Please select a valid transaction date.",
                            style: GoogleFonts.ibmPlexSansArabic(
                              color: isDark
                                  ? AppColors.darkError
                                  : AppColors.lightError,
                              fontSize: screenW * 0.035,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      SizedBox(height: screenH * 0.022),

                      // Movement Type
                      _SectionTitle(
                          title: "Movement Type",
                          screenW: screenW,
                          isDark: isDark),
                      SizedBox(height: screenH * 0.012),
                      OptionChip(
                        items: _movementTypeLabels,
                        selected: _movementTypeLabel,
                        onTap: (val) {
                          setState(() {
                            _movementType = val == 'Occasional'
                                ? 'occasional'
                                : 'recurring';
                            if (_movementType == 'occasional') {
                              _frequency = null;
                              _nextDueDate = null;
                            }
                          });
                        },
                      ),
                      SizedBox(height: screenH * 0.022),

                      if (isRecurring) ...[
                        // Coverage Period
                        _SectionTitle(
                            title: "Coverage Period",
                            screenW: screenW,
                            isDark: isDark),
                        SizedBox(height: screenH * 0.012),
                        MultiSelectChip(
                          items: _frequencyLabels,
                          selectedItems:
                              _frequencyLabel != null ? [_frequencyLabel!] : [],
                          onTap: (val) {
                            setState(() {
                              if (val == 'Weekly') _frequency = 'weekly';
                              if (val == 'Monthly') _frequency = 'monthly';
                              if (val == 'Quarterly') _frequency = 'quarterly';
                              if (val == 'Yearly') _frequency = 'yearly';
                            });
                          },
                        ),
                        SizedBox(height: screenH * 0.022),
                      ],
                    ],

                    // Note
                    _SectionTitle(
                        title: "Note (optional)",
                        screenW: screenW,
                        isDark: isDark),
                    SizedBox(height: screenH * 0.01),
                    CustomTextfield(
                      controller: _noteController,
                      hint: "Add a note",
                      type: TextFieldType.name,
                      icon: Icons.notes_rounded,
                    ),
                    SizedBox(height: screenH * 0.03),

                    _buildWarnings(
                        warnings: warnings, isDark: isDark, screenW: screenW),

                    if (!_isValid && _disabledReason != null) ...[
                      Padding(
                        padding: EdgeInsets.only(bottom: screenH * 0.015),
                        child: Text(
                          _disabledReason!,
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

                    AppButton(
                      text: "Confirm and Save",
                      isDark: isDark,
                      isLoading: _isSaving,
                      width: double.infinity,
                      height: screenH * 0.065,
                      onPressed: () {
                        if (!_isSaving && _isValid) {
                          _submit();
                        }
                      },
                    ),
                    SizedBox(height: screenH * 0.03),
                  ],
                ),
              ),
              if (_isSaving)
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
          onTap: () {
            if (_hasSavedAny) {
              Navigator.pop(context, DashboardActionResult.created);
            } else {
              Navigator.pop(context, null);
            }
          },
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Review Transaction",
                style: GoogleFonts.ibmPlexSansArabic(
                  color: isDark ? AppColors.darkText : AppColors.lightText,
                  fontSize: screenW * 0.065,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (widget.transactions.length > 1)
                Text(
                  "Transaction ${_currentIndex + 1} of ${widget.transactions.length}",
                  style: GoogleFonts.ibmPlexSansArabic(
                    color:
                        isDark ? AppColors.darkSubText : AppColors.lightSubText,
                    fontSize: screenW * 0.035,
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAISummary({
    required bool isDark,
    required double screenW,
    required bool needsReview,
  }) {
    final confidence = _draft.confidence ?? 0.0;
    final source = _draft.sourceType == 'voice'
        ? 'Voice'
        : (_draft.sourceType == 'image' ? 'Image' : 'Manual');

    return Container(
      padding: EdgeInsets.all(screenW * 0.04),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF203330)
            : AppColors.lightBackground.withOpacity(0.5),
        border: Border.all(
          color: needsReview
              ? Colors.orange.withOpacity(0.5)
              : (isDark
                  ? Colors.white.withOpacity(0.05)
                  : Colors.black.withOpacity(0.05)),
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome,
                  color:
                      isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
                  size: screenW * 0.05),
              SizedBox(width: screenW * 0.02),
              Text(
                "AI Analysis",
                style: GoogleFonts.ibmPlexSansArabic(
                  color: isDark ? AppColors.darkText : AppColors.lightText,
                  fontSize: screenW * 0.045,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: screenW * 0.02),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Confidence:",
                  style: GoogleFonts.ibmPlexSansArabic(
                      color: isDark
                          ? AppColors.darkSubText
                          : AppColors.lightSubText,
                      fontSize: screenW * 0.035)),
              Text("${confidence.toStringAsFixed(0)}%",
                  style: GoogleFonts.ibmPlexSansArabic(
                      color: isDark ? AppColors.darkText : AppColors.lightText,
                      fontSize: screenW * 0.035,
                      fontWeight: FontWeight.bold)),
            ],
          ),
          SizedBox(height: screenW * 0.01),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Source:",
                  style: GoogleFonts.ibmPlexSansArabic(
                      color: isDark
                          ? AppColors.darkSubText
                          : AppColors.lightSubText,
                      fontSize: screenW * 0.035)),
              Text(source,
                  style: GoogleFonts.ibmPlexSansArabic(
                      color: isDark ? AppColors.darkText : AppColors.lightText,
                      fontSize: screenW * 0.035,
                      fontWeight: FontWeight.bold)),
            ],
          ),
          SizedBox(height: screenW * 0.01),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Status:",
                  style: GoogleFonts.ibmPlexSansArabic(
                      color: isDark
                          ? AppColors.darkSubText
                          : AppColors.lightSubText,
                      fontSize: screenW * 0.035)),
              Text(needsReview ? "Review required" : "Ready to save",
                  style: GoogleFonts.ibmPlexSansArabic(
                      color: needsReview
                          ? Colors.orange
                          : (isDark
                              ? AppColors.darkPrimary
                              : AppColors.lightPrimary),
                      fontSize: screenW * 0.035,
                      fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWarnings({
    required List<String> warnings,
    required bool isDark,
    required double screenW,
  }) {
    if (warnings.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.only(bottom: screenW * 0.04),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(screenW * 0.04),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.1),
          border: Border.all(color: Colors.orange.withOpacity(0.5)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Review required before saving",
              style: GoogleFonts.ibmPlexSansArabic(
                color: Colors.orange,
                fontWeight: FontWeight.bold,
                fontSize: screenW * 0.04,
              ),
            ),
            SizedBox(height: screenW * 0.02),
            ...warnings.map((w) => Padding(
                  padding: EdgeInsets.only(top: screenW * 0.01),
                  child: Text(
                    "- $w",
                    style: GoogleFonts.ibmPlexSansArabic(
                      color: Colors.orange,
                      fontSize: screenW * 0.035,
                    ),
                  ),
                )),
          ],
        ),
      ),
    );
  }
}

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
