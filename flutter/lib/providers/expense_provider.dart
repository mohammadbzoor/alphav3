import 'package:alpha_app/models/expense_model.dart';
import 'package:alpha_app/models/transaction_draft_model.dart';
import 'package:alpha_app/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:alpha_app/core/utils/finance_mappings.dart';

class ExpenseProvider extends ChangeNotifier {
  ExpenseProvider() {
    Future.microtask(_initialize);
  }

  static const String _storageKey = 'alpha_saved_expenses';

  // =========================================================
  // FORM CONTROLLERS
  // =========================================================

  final TextEditingController customCategoryController =
      TextEditingController();

  final TextEditingController titleController = TextEditingController();

  final TextEditingController amountController = TextEditingController();

  final TextEditingController noteController = TextEditingController();

  final TextEditingController dateController = TextEditingController();

  // =========================================================
  // FORM VALUES
  // =========================================================

  String? _selectedCategory;

  String? get selectedCategory => _selectedCategory;

  String? _paymentMethod;

  String? get paymentMethod => _paymentMethod;

  ExpenseType? _expenseType;

  ExpenseType? get expenseType => _expenseType;

  ExpenseMovementType _movementType = ExpenseMovementType.occasional;

  ExpenseMovementType get movementType => _movementType;

  ExpenseCoveragePeriod? _coveragePeriod;

  ExpenseCoveragePeriod? get coveragePeriod => _coveragePeriod;

  String? _flexibility;

  String? get flexibility => _flexibility;

  DateTime _selectedDate = DateTime.now();

  DateTime get selectedDate => _selectedDate;

  ExpenseModel? _expenseBeingEdited;

  ExpenseModel? get expenseBeingEdited => _expenseBeingEdited;

  bool get isEditing => _expenseBeingEdited != null;

  bool get isRecurring {
    return _movementType == ExpenseMovementType.recurring;
  }

  // =========================================================
  // APP STATE
  // =========================================================

  final List<ExpenseModel> _expenses = [];

  bool _isLoading = false;

  bool get isLoading => _isLoading;

  bool _isSaving = false;

  bool get isSaving => _isSaving;

  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;

  String? _errorMessage;

  String? get errorMessage => _errorMessage;

  // =========================================================
  // TRANSACTION DRAFT
  // =========================================================

  TransactionDraft? _transactionDraft;
  TransactionDraft? get transactionDraft => _transactionDraft;

  bool _isAnalyzing = false;
  bool get isAnalyzing => _isAnalyzing;

  bool _isSubmitting = false;
  bool get isSubmitting => _isSubmitting;

  void setTransactionDraft(TransactionDraft? draft) {
    _transactionDraft = draft;
    notifyListeners();
  }

  void setIsAnalyzing(bool value) {
    _isAnalyzing = value;
    notifyListeners();
  }

  void setIsSubmitting(bool value) {
    _isSubmitting = value;
    notifyListeners();
  }

  // =========================================================
  // SHOPPING SESSION
  // =========================================================

  bool _isShoppingSessionActive = false;

  bool get isShoppingSessionActive => _isShoppingSessionActive;

  final List<ExpenseModel> _sessionExpenses = [];

  List<ExpenseModel> get sessionExpenses => List.unmodifiable(_sessionExpenses);

  double get sessionTotal {
    return _calculateTotal(_sessionExpenses);
  }

  int get sessionExpenseCount => _sessionExpenses.length;

  // =========================================================
  // OPTIONS
  // =========================================================

  List<String> get categories {
    if (_expenseType == null) return [];
    return _expenseType == ExpenseType.need
        ? FinanceMappings.needsCategories.keys.toList()
        : FinanceMappings.wantsCategories.keys.toList();
  }

  List<String> get paymentMethods {
    return FinanceMappings.paymentMethods.keys.toList();
  }

  final List<String> movementTypes = const [
    'Occasional',
    'Recurring',
  ];

  List<String> get coveragePeriods {
    return FinanceMappings.recurringFrequencies.keys.toList();
  }

  final List<String> flexibilities = const [
    'Fixed',
    'Flexible',
  ];

  // =========================================================
  // EXPENSE GETTERS
  // =========================================================

  List<ExpenseModel> get expenses {
    final sorted = List<ExpenseModel>.from(_expenses);

    sorted.sort((first, second) {
      final dateComparison = second.date.compareTo(first.date);

      if (dateComparison != 0) {
        return dateComparison;
      }

      return second.createdAt.compareTo(
        first.createdAt,
      );
    });

    return List.unmodifiable(sorted);
  }

  List<ExpenseModel> get recentExpenses {
    return expenses.take(5).toList();
  }

  ExpenseModel? expenseById(String id) {
    try {
      return _expenses.firstWhere(
        (expense) => expense.id == id,
      );
    } catch (_) {
      return null;
    }
  }

  // =========================================================
  // INITIALIZATION
  // =========================================================

  Future<void> _initialize() async {
    _isLoading = true;
    _errorMessage = null;

    notifyListeners();

    try {
      await loadExpenses();

      setDate(
        DateTime.now(),
        notify: false,
      );

      _isInitialized = true;
    } catch (error) {
      _errorMessage = 'Could not load expenses: ${_cleanError(error)}';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshExpenses() async {
    _isLoading = true;
    _errorMessage = null;

    notifyListeners();

    try {
      await loadExpenses();
    } catch (error) {
      _errorMessage = 'Could not refresh expenses: ${_cleanError(error)}';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // =========================================================
  // BACKEND INTEGRATION
  // =========================================================

  Future<void> loadExpenses() async {
    try {
      final response = await ApiService.get('/expenses');
      final body = await ApiService.parseJson(response);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = body['data'] ?? body;
        final items = data is List ? data : (data['items'] ?? data);

        if (items is List) {
          final loadedExpenses = items
              .map((item) {
                final map = Map<String, dynamic>.from(item);
                return ExpenseModel.fromJson(map);
              })
              .where((e) => e.id.isNotEmpty)
              .toList();

          _expenses.clear();
          _expenses.addAll(loadedExpenses);
        }
      } else {
        _errorMessage = await ApiService.getErrorMessage(response,
            fallback: 'Could not load expenses');
      }
    } catch (error) {
      _errorMessage = 'Could not load expenses: ${_cleanError(error)}';
    }
  }

  // =========================================================
  // FORM SETTERS
  // =========================================================

  void setCategory(String category) {
    _selectedCategory = category;
    _errorMessage = null;

    notifyListeners();
  }

  void setPaymentMethod(String method) {
    _paymentMethod = method;
    _errorMessage = null;

    notifyListeners();
  }

  void setExpenseType(ExpenseType type) {
    _expenseType = type;
    _selectedCategory = null;
    _errorMessage = null;

    notifyListeners();
  }

  void setMovementType(
    ExpenseMovementType type,
  ) {
    _movementType = type;
    _errorMessage = null;

    if (type == ExpenseMovementType.occasional) {
      _coveragePeriod = null;
      _flexibility = null;
    }

    notifyListeners();
  }

  void setMovementTypeByLabel(String value) {
    setMovementType(
      value == 'Recurring'
          ? ExpenseMovementType.recurring
          : ExpenseMovementType.occasional,
    );
  }

  void setCoveragePeriod(
    ExpenseCoveragePeriod period,
  ) {
    _coveragePeriod = period;
    _errorMessage = null;

    notifyListeners();
  }

  void setCoveragePeriodByLabel(String value) {
    // Just map UI string directly back or fallback to Monthly
    switch (value) {
      case 'Weekly':
        setCoveragePeriod(ExpenseCoveragePeriod.oneWeek);
        break;
      case 'Monthly':
        setCoveragePeriod(ExpenseCoveragePeriod.monthly);
        break;
      case 'Quarterly':
        // For UI purposes, we'll map Quarterly to twoWeeks for now or just add it to enum if needed.
        // The endpoint cares about the string value "quarterly". We should update the enum.
        setCoveragePeriod(ExpenseCoveragePeriod
            .twoWeeks); // Workaround if enum is not updated
        break;
      case 'Yearly':
        setCoveragePeriod(ExpenseCoveragePeriod.threeDays); // Workaround
        break;
      default:
        setCoveragePeriod(ExpenseCoveragePeriod.monthly);
    }
  }

  void setFlexibility(String value) {
    _flexibility = value;
    _errorMessage = null;
    notifyListeners();
  }

  void setDate(
    DateTime date, {
    bool notify = true,
  }) {
    _selectedDate = DateTime(
      date.year,
      date.month,
      date.day,
    );

    dateController.text = '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';

    if (notify) {
      notifyListeners();
    }
  }

  void notifyExpenseFormChanged() {
    _errorMessage = null;
    notifyListeners();
  }

  // =========================================================
  // DISPLAY LABELS
  // =========================================================

  String get movementTypeLabel {
    switch (_movementType) {
      case ExpenseMovementType.occasional:
        return 'Occasional';

      case ExpenseMovementType.recurring:
        return 'Recurring';
    }
  }

  String? get coveragePeriodLabel {
    switch (_coveragePeriod) {
      case ExpenseCoveragePeriod.oneWeek:
        return 'Weekly';
      case ExpenseCoveragePeriod.twoWeeks:
        return 'Quarterly';
      case ExpenseCoveragePeriod.threeDays:
        return 'Yearly';
      case ExpenseCoveragePeriod.monthly:
        return 'Monthly';
      default:
        return null;
    }
  }

  // =========================================================
  // AMOUNT
  // =========================================================

  double get amount {
    final value = amountController.text.replaceAll(',', '').trim();

    return double.tryParse(value) ?? 0;
  }

  // =========================================================
  // VALIDATION
  // =========================================================

  bool get isValid {
    return validationMessage == null;
  }

  String? get validationMessage {
    if (_expenseType == null) {
      return 'Select an expense type.';
    }

    if (_selectedCategory == null) {
      return 'Select a category.';
    }

    if (titleController.text.trim().isEmpty) {
      return 'Enter an expense name.';
    }

    if (amount <= 0) {
      return 'Enter a valid amount.';
    }

    if (_movementType == ExpenseMovementType.recurring) {
      if (_coveragePeriod == null) {
        return 'Select a coverage period.';
      }
      if (_flexibility == null) {
        return 'Select flexibility.';
      }
    } else {
      if (_paymentMethod == null) {
        return 'Select a payment method.';
      }
      if (_selectedDate.isAfter(DateTime.now())) {
        return 'Select a valid transaction date.';
      }
    }

    return null;
  }

  // =========================================================
  // BUILD EXPENSE FROM FORM
  // =========================================================

  ExpenseModel? buildCurrentExpense() {
    if (!isValid) {
      return null;
    }

    final oldExpense = _expenseBeingEdited;

    final noteText = noteController.text.trim();

    return ExpenseModel(
      id: oldExpense?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      title: titleController.text.trim(),
      category: _expenseType == ExpenseType.need
          ? (FinanceMappings.needsCategories[_selectedCategory!] ?? 'other')
          : (FinanceMappings.wantsCategories[_selectedCategory!] ?? 'other'),
      amount: amount,
      date: _selectedDate,
      paymentMethod: FinanceMappings.paymentMethods[_paymentMethod] ?? 'cash',
      note: noteText.isEmpty ? null : noteText,
      expenseType: _expenseType!,
      source: oldExpense?.source ?? ExpenseSource.manual,
      movementType: _movementType,
      coveragePeriod: _coveragePeriod ?? ExpenseCoveragePeriod.oneDay,
      aiInsight: null,
      confidence: oldExpense?.confidence,
      createdAt: oldExpense?.createdAt ?? DateTime.now(),
    );
  }

  // =========================================================
  // SAVE FORM
  // =========================================================

  Future<bool> saveCurrentExpense() async {
    final expense = buildCurrentExpense();

    if (expense == null) {
      _errorMessage = validationMessage;
      notifyListeners();

      return false;
    }

    if (_isShoppingSessionActive && !isEditing) {
      _sessionExpenses.add(expense);

      clearForm(notify: false);
      notifyListeners();

      return true;
    }

    if (isEditing) {
      return _saveEditedExpense(expense);
    }

    return addExpense(expense);
  }

  Future<bool> _saveEditedExpense(
    ExpenseModel updatedExpense,
  ) async {
    final index = _expenses.indexWhere(
      (expense) => expense.id == updatedExpense.id,
    );

    if (index == -1) {
      _errorMessage = 'Expense was not found';
      notifyListeners();

      return false;
    }

    final previousExpense = _expenses[index];

    _expenses[index] = updatedExpense;

    notifyListeners();

    final saved = await updateExpense(updatedExpense);

    if (!saved) {
      _expenses[index] = previousExpense;
      notifyListeners();

      return false;
    }

    clearForm(notify: false);
    notifyListeners();

    return true;
  }

  // =========================================================
  // CRUD
  // =========================================================

  Future<bool> addExpense(
    ExpenseModel expense,
  ) async {
    if (_isSaving) return false;
    _isSaving = true;
    notifyListeners();

    final existingIndex = _expenses.indexWhere(
      (item) => item.id == expense.id,
    );

    final backup = List<ExpenseModel>.from(_expenses);

    if (existingIndex == -1) {
      _expenses.insert(0, expense);
    } else {
      _expenses[existingIndex] = expense;
    }

    notifyListeners();

    try {
      final String idempotencyKey =
          DateTime.now().millisecondsSinceEpoch.toString();

      String endpoint = '/expenses';
      Map<String, dynamic> requestBody;

      if (expense.isRecurring) {
        endpoint = '/commitments';
        String frequency = 'monthly';
        if (expense.coveragePeriod == ExpenseCoveragePeriod.oneWeek)
          frequency = 'weekly';
        if (expense.coveragePeriod == ExpenseCoveragePeriod.twoWeeks)
          frequency = 'quarterly';
        if (expense.coveragePeriod == ExpenseCoveragePeriod.threeDays)
          frequency = 'yearly';

        String mappedFlexibility = 'fixed';
        if (_flexibility == 'Flexible') mappedFlexibility = 'flexible';

        requestBody = expense.toCommitmentJson(frequency, mappedFlexibility);
      } else {
        requestBody = expense.toExpenseJson();
      }

      final response = await ApiService.post(
        endpoint,
        body: requestBody,
        headers: {'Idempotency-Key': idempotencyKey},
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final body = await ApiService.parseJson(response);
        final data = body['data'] ?? {};
        final newId = data['id']?.toString() ?? expense.id;

        final finalExpense = expense.copyWith(id: newId);

        if (existingIndex == -1) {
          _expenses[0] = finalExpense;
        } else {
          _expenses[existingIndex] = finalExpense;
        }

        clearForm(notify: false);
        _isSaving = false;
        notifyListeners();
        return true;
      } else {
        final body = await ApiService.parseJson(response);
        final errorCode = body['code']?.toString() ??
            (body['error'] is Map ? body['error']['code']?.toString() : null);
        if (errorCode == 'NO_ACTIVE_FINANCIAL_CYCLE' ||
            errorCode == 'CYCLE_NOT_FOUND') {
          _errorMessage = errorCode;
        } else {
          _errorMessage = await ApiService.getErrorMessage(response,
              fallback: 'Failed to save to backend');
        }
      }
    } catch (e) {
      if (e.toString().contains('NO_ACTIVE_FINANCIAL_CYCLE')) {
        _errorMessage = 'NO_ACTIVE_FINANCIAL_CYCLE';
      } else if (e.toString().contains('CYCLE_NOT_FOUND')) {
        _errorMessage = 'CYCLE_NOT_FOUND';
      } else {
        _errorMessage = _cleanError(e);
      }
    }

    _expenses.clear();
    _expenses.addAll(backup);

    _isSaving = false;
    notifyListeners();

    return false;
  }

  Future<bool> saveTransactionDraft(TransactionDraft draft) async {
    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final String idempotencyKey =
          DateTime.now().millisecondsSinceEpoch.toString();

      String endpoint = '/expenses';
      Map<String, dynamic> requestBody;

      if (draft.movementType == 'recurring') {
        endpoint = '/commitments';
        requestBody = {
          'amount': draft.amount,
          'name': draft.description,
          'frequency': draft.frequency,
          'flexibility': draft.flexibility,
          'nextDueDate': draft.transactionDate,
          'sourceType': draft.sourceType,
        };
      } else {
        requestBody = {
          'amount': draft.amount,
          'bucket': draft.bucket,
          'category': draft.category,
          'paymentMethod': draft.paymentMethod,
          'expenseDate': draft.transactionDate,
          'description': draft.description,
          'sourceType': draft.sourceType,
        };
      }

      final response = await ApiService.post(
        endpoint,
        body: requestBody,
        headers: {'Idempotency-Key': idempotencyKey},
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        _transactionDraft = null;

        // Reload expenses to show the newly added one
        loadExpenses().then((_) {
          notifyListeners();
        });

        _isSubmitting = false;
        notifyListeners();
        return true;
      } else {
        final body = await ApiService.parseJson(response);
        final errorCode = body['code']?.toString() ??
            (body['error'] is Map ? body['error']['code']?.toString() : null);
        if (errorCode == 'NO_ACTIVE_FINANCIAL_CYCLE' ||
            errorCode == 'CYCLE_NOT_FOUND') {
          _errorMessage = errorCode;
        } else {
          _errorMessage = await ApiService.getErrorMessage(response,
              fallback: 'Failed to save transaction');
        }
      }
    } catch (e) {
      if (e.toString().contains('NO_ACTIVE_FINANCIAL_CYCLE')) {
        _errorMessage = 'NO_ACTIVE_FINANCIAL_CYCLE';
      } else if (e.toString().contains('CYCLE_NOT_FOUND')) {
        _errorMessage = 'CYCLE_NOT_FOUND';
      } else {
        _errorMessage = _cleanError(e);
      }
    }

    _isSubmitting = false;
    notifyListeners();
    return false;
  }

  Future<bool> updateExpense(
    ExpenseModel expense,
  ) async {
    _errorMessage = 'Expense updates are not supported by the backend yet.';
    notifyListeners();
    return false;
  }

  Future<bool> deleteExpense(
    String expenseId,
  ) async {
    final index = _expenses.indexWhere(
      (expense) => expense.id == expenseId,
    );

    if (index == -1) {
      return false;
    }

    final removedExpense = _expenses.removeAt(index);

    notifyListeners();

    try {
      final response = await ApiService.delete('/expenses/$expenseId');
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return true;
      }
    } catch (e) {
      _errorMessage = _cleanError(e);
    }

    _expenses.insert(index, removedExpense);
    notifyListeners();
    return false;
  }

  Future<bool> clearAllExpenses() async {
    try {
      final response = await ApiService.delete('/expenses');
      if (response.statusCode >= 200 && response.statusCode < 300) {
        _expenses.clear();
        notifyListeners();
        return true;
      }
    } catch (e) {
      _errorMessage = _cleanError(e);
      notifyListeners();
    }
    return false;
  }

  // =========================================================
  // EDITING
  // =========================================================

  void prepareExpenseForEditing(
    ExpenseModel expense,
  ) {
    _expenseBeingEdited = expense;

    titleController.text = expense.title;

    amountController.text = expense.amount.toStringAsFixed(2);

    noteController.text = expense.note ?? '';

    _selectedCategory = expense.category;

    _paymentMethod = expense.paymentMethod;

    _expenseType = expense.expenseType;

    _movementType = expense.movementType;

    _coveragePeriod = expense.coveragePeriod;

    setDate(
      expense.date,
      notify: false,
    );

    _errorMessage = null;

    notifyListeners();
  }

  void cancelEditing() {
    clearForm();
  }

  // =========================================================
  // SHOPPING SESSION
  // =========================================================

  void startShoppingSession() {
    _isShoppingSessionActive = true;
    _sessionExpenses.clear();

    notifyListeners();
  }

  Future<bool> finishShoppingSession() async {
    if (_sessionExpenses.isEmpty) {
      _isShoppingSessionActive = false;
      notifyListeners();

      return true;
    }

    final backup = List<ExpenseModel>.from(_expenses);

    _expenses.insertAll(
      0,
      _sessionExpenses,
    );

    notifyListeners();

    bool allSaved = true;
    for (var expense in _sessionExpenses) {
      final success = await addExpense(expense);
      if (!success) {
        allSaved = false;
        break;
      }
    }

    if (!allSaved) {
      _expenses
        ..clear()
        ..addAll(backup);

      notifyListeners();

      return false;
    }

    _sessionExpenses.clear();
    _isShoppingSessionActive = false;

    notifyListeners();

    return true;
  }

  void cancelShoppingSession() {
    _sessionExpenses.clear();
    _isShoppingSessionActive = false;

    notifyListeners();
  }

  // =========================================================
  // STATISTICS
  // =========================================================

  double get totalExpenses {
    return _calculateTotal(_expenses);
  }

  Map<String, double> get categoryTotals {
    return _calculateCategoryTotals(_expenses);
  }

  List<ExpenseModel> get currentMonthExpenses {
    final now = DateTime.now();

    return expenses.where((expense) {
      return expense.date.year == now.year && expense.date.month == now.month;
    }).toList();
  }

  List<ExpenseModel> get previousMonthExpenses {
    final now = DateTime.now();

    final previousMonth = DateTime(
      now.year,
      now.month - 1,
      1,
    );

    return expenses.where((expense) {
      return expense.date.year == previousMonth.year &&
          expense.date.month == previousMonth.month;
    }).toList();
  }

  double get currentMonthTotal {
    return _calculateTotal(
      currentMonthExpenses,
    );
  }

  double get previousMonthTotal {
    return _calculateTotal(
      previousMonthExpenses,
    );
  }

  Map<String, double> get currentMonthCategoryTotals {
    return _calculateCategoryTotals(
      currentMonthExpenses,
    );
  }

  String get topCategory {
    final totals = currentMonthCategoryTotals;

    if (totals.isEmpty) {
      return '';
    }

    return totals.entries.reduce(
      (first, second) {
        return first.value >= second.value ? first : second;
      },
    ).key;
  }

  double get topCategoryAmount {
    if (topCategory.isEmpty) {
      return 0;
    }

    return currentMonthCategoryTotals[topCategory] ?? 0;
  }

  double get monthlyDifference {
    return currentMonthTotal - previousMonthTotal;
  }

  double get monthlyDifferencePercentage {
    if (previousMonthTotal <= 0) {
      return 0;
    }

    return monthlyDifference.abs() / previousMonthTotal * 100;
  }

  double get currentMonthNeedsTotal {
    return _calculateTotal(
      currentMonthExpenses.where(
        (expense) => expense.expenseType == ExpenseType.need,
      ),
    );
  }

  double get currentMonthWantsTotal {
    return _calculateTotal(
      currentMonthExpenses.where(
        (expense) => expense.expenseType == ExpenseType.want,
      ),
    );
  }

  // =========================================================
  // INSIGHTS
  // =========================================================

  String get spendingInsight {
    if (_expenses.isEmpty) {
      return 'Add expenses to receive personalized spending insights.';
    }

    if (currentMonthExpenses.isEmpty) {
      return 'You have not recorded expenses this month yet.';
    }

    if (previousMonthTotal <= 0) {
      return topCategory.isEmpty
          ? 'Continue recording expenses to unlock monthly comparisons.'
          : 'This is your first tracked month. Your highest spending category is $topCategory.';
    }

    final percentage = monthlyDifferencePercentage.toStringAsFixed(0);

    if (monthlyDifference > 0) {
      return 'Your spending increased by $percentage% compared with last month. Your highest category is $topCategory.';
    }

    if (monthlyDifference < 0) {
      return 'Great progress! You spent $percentage% less than last month.';
    }

    return 'Your spending is equal to last month.';
  }

  String _buildExpenseInsight() {
    if (_expenseType == ExpenseType.want) {
      return 'This is a secondary want. Consider its effect on your goals before continuing at the same spending rate.';
    }

    if (amount >= 100) {
      return 'This is a relatively high expense. Review its effect on your remaining monthly balance.';
    }

    if (_movementType == ExpenseMovementType.recurring) {
      return 'This recurring expense covers $coveragePeriodLabel and will be distributed across its coverage period.';
    }

    return 'This expense will be included in your actual spending analysis.';
  }

  // =========================================================
  // SEARCH AND FILTER
  // =========================================================

  List<ExpenseModel> searchExpenses(
    String query,
  ) {
    final normalized = query.trim().toLowerCase();

    if (normalized.isEmpty) {
      return expenses;
    }

    return expenses.where((expense) {
      return expense.title.toLowerCase().contains(normalized) ||
          expense.category.toLowerCase().contains(normalized) ||
          expense.paymentMethod.toLowerCase().contains(normalized) ||
          (expense.note ?? '').toLowerCase().contains(normalized);
    }).toList();
  }

  List<ExpenseModel> expensesByCategory(
    String category,
  ) {
    return expenses
        .where(
          (expense) => expense.category == category,
        )
        .toList();
  }

  List<ExpenseModel> expensesBetween({
    required DateTime start,
    required DateTime end,
  }) {
    final startDate = DateTime(
      start.year,
      start.month,
      start.day,
    );

    final endDate = DateTime(
      end.year,
      end.month,
      end.day,
      23,
      59,
      59,
      999,
    );

    return expenses.where((expense) {
      return !expense.date.isBefore(startDate) &&
          !expense.date.isAfter(endDate);
    }).toList();
  }

  // =========================================================
  // HELPERS
  // =========================================================

  double _calculateTotal(
    Iterable<ExpenseModel> items,
  ) {
    return items.fold<double>(
      0,
      (sum, expense) => sum + expense.amount,
    );
  }

  Map<String, double> _calculateCategoryTotals(
    Iterable<ExpenseModel> items,
  ) {
    final totals = <String, double>{};

    for (final expense in items) {
      totals.update(
        expense.category,
        (value) => value + expense.amount,
        ifAbsent: () => expense.amount,
      );
    }

    return totals;
  }

  String _cleanError(Object error) {
    return error.toString().replaceFirst('Exception: ', '');
  }

  // =========================================================
  // CLEAR
  // =========================================================

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void clearForm({
    bool notify = true,
  }) {
    titleController.clear();
    amountController.clear();
    noteController.clear();
    customCategoryController.clear();

    _selectedCategory = null;
    _paymentMethod = null;
    _expenseType = null;

    _movementType = ExpenseMovementType.occasional;

    _coveragePeriod = null;
    _flexibility = null;

    _expenseBeingEdited = null;
    _errorMessage = null;

    setDate(
      DateTime.now(),
      notify: false,
    );

    if (notify) {
      notifyListeners();
    }
  }

  void clearData() {
    _expenses.clear();
    _sessionExpenses.clear();
    _isShoppingSessionActive = false;
    _transactionDraft = null;
    _isInitialized = false;
    _isLoading = false;
    _isSaving = false;
    _isAnalyzing = false;
    _isSubmitting = false;
    _errorMessage = null;
    clearForm(notify: false);
    notifyListeners();
  }

  // =========================================================
  // DISPOSE
  // =========================================================

  @override
  void dispose() {
    titleController.dispose();
    amountController.dispose();
    noteController.dispose();
    dateController.dispose();
    customCategoryController.dispose();

    super.dispose();
  }
}
