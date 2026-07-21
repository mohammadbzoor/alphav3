import 'package:alpha_app/services/api_service.dart';
import 'package:flutter/material.dart';

import '../models/goal_model.dart';

class GoalProvider extends ChangeNotifier {
  GoalProvider() {
    Future.microtask(_initialize);
  }

  static const String _storageKey =
      'alpha_saved_goals';

  // ================= CONTROLLERS =================

  final TextEditingController customNameController =
      TextEditingController();

  final TextEditingController amountController =
      TextEditingController();

  final TextEditingController targetDateController =
      TextEditingController();

  // ================= CREATE GOAL DATA =================

  String? selectedCategory;
  DateTime? targetDate;

  int priority = 5;
  double emergencyPercentage = 10;

  // ================= STATE =================

  bool _isLoading = false;

  bool get isLoading => _isLoading;

  bool _isSaving = false;

  bool get isSaving => _isSaving;

  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;

  String? _errorMessage;

  String? get errorMessage => _errorMessage;

  // ================= GOALS =================

  final List<Goal> _goals = [];

  List<Goal> get goals {
    final sortedGoals =
        List<Goal>.from(_goals);

    sortedGoals.sort(
      (a, b) {
        final aDate =
            a.targetDate ?? DateTime(9999);

        final bDate =
            b.targetDate ?? DateTime(9999);

        return aDate.compareTo(bDate);
      },
    );

    return List.unmodifiable(sortedGoals);
  }

  List<Goal> get activeGoals {
    return goals
        .where(
          (goal) =>
              goal.isActive &&
              !goal.isCompleted,
        )
        .toList();
  }

  List<Goal> get completedGoals {
    return goals
        .where(
          (goal) =>
              !goal.isActive ||
              goal.isCompleted,
        )
        .toList();
  }

  int get activeGoalsCount =>
      activeGoals.length;

  // ================= CATEGORIES =================

  final List<String> goalCategories = [
    "Emergency Fund",
    "Laptop",
    "Travel",
    "Car",
    "Education",
    "House",
    "Business",
    "Furniture",
    "Other",
  ];

  // ================= INITIALIZE =================

  Future<void> _initialize() async {
    _isLoading = true;
    _errorMessage = null;

    notifyListeners();

    try {
      await loadGoals();
      _isInitialized = true;
    } catch (error) {
      _errorMessage =
          _cleanError(error);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ================= BACKEND API =================

  Future<void> loadGoals() async {
    try {
      final response = await ApiService.get('/goals');
      final body = await ApiService.parseJson(response);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = body['data'];
        final items = data['items'] ?? data;
        
        if (items is List) {
          final loadedGoals = items.map((item) {
            final map = Map<String, dynamic>.from(item);
            
            // Map backend fields to what Goal.fromJson expects
            return Goal(
              id: map['id']?.toString(),
              category: map['name']?.toString() ?? 'Other',
              customName: map['name']?.toString(),
              monthlySaving: (map['monthlyContribution'] ?? 0).toDouble(),
              priority: (map['priority'] ?? 5).toInt(),
              targetDate: null, // Backend does not return targetDate in getGoals
              savedAmount: (map['currentBalance'] ?? 0).toDouble(),
              targetAmount: (map['targetAmount'] ?? 0).toDouble(),
              isActive: map['status'] == 'active',
            );
          }).where((g) => g.id != null && g.id!.isNotEmpty).toList();

          _goals.clear();
          _goals.addAll(loadedGoals);
        }
      }
    } catch (error) {
      _errorMessage = _cleanError(error);
    }
  }

  // ================= VALUES =================

  double get monthlySaving {
    final value = amountController.text
        .trim()
        .replaceAll(",", "");

    return double.tryParse(value) ?? 0;
  }

  String get goalName {
    if (selectedCategory == "Other") {
      return customNameController.text.trim();
    }

    return selectedCategory ?? "";
  }

  // ================= SETTERS =================

  void setCategory(String value) {
    selectedCategory = value;

    if (value != "Other") {
      customNameController.clear();
    }

    _errorMessage = null;

    notifyListeners();
  }

  void setPriority(int value) {
    priority = value;
    _errorMessage = null;

    notifyListeners();
  }

  void setEmergencyPercentage(
    double value,
  ) {
    emergencyPercentage = value;
    _errorMessage = null;

    notifyListeners();
  }

  void setDate(DateTime date) {
    targetDate = DateTime(
      date.year,
      date.month,
      date.day,
    );

    targetDateController.text =
        "${date.day}/${date.month}/${date.year}";

    _errorMessage = null;

    notifyListeners();
  }

  void refresh() {
    _errorMessage = null;
    notifyListeners();
  }

  // ================= VALIDATION =================

  bool get isValid {
    final categoryValid =
        selectedCategory != null;

    final customNameValid =
        selectedCategory != "Other" ||
            customNameController.text
                .trim()
                .isNotEmpty;

    final amountValid =
        monthlySaving > 0;

    final targetDateValid =
        targetDate != null;

    return categoryValid &&
        customNameValid &&
        amountValid &&
        targetDateValid;
  }

  String? get validationMessage {
    if (selectedCategory == null) {
      return "Please select a goal category";
    }

    if (selectedCategory == "Other" &&
        customNameController.text
            .trim()
            .isEmpty) {
      return "Please enter the goal name";
    }

    if (monthlySaving <= 0) {
      return "Please enter a valid monthly saving amount";
    }

    if (targetDate == null) {
      return "Please select a target date";
    }

    return null;
  }

  // ================= PAGE PROGRESS =================

  double get pageProgress {
    const int totalSteps = 4;
    int completedSteps = 0;

    if (selectedCategory != null) {
      completedSteps++;
    }

    if (selectedCategory != null &&
        (selectedCategory != "Other" ||
            customNameController.text
                .trim()
                .isNotEmpty)) {
      completedSteps++;
    }

    if (monthlySaving > 0) {
      completedSteps++;
    }

    if (targetDate != null) {
      completedSteps++;
    }

    final value =
        (2 / 3) +
            ((completedSteps / totalSteps) *
                (1 / 3));

    return value.clamp(
      0.0,
      1.0,
    );
  }

  // ================= CREATE MODEL =================

  Goal get currentGoal {
    return Goal(
      id: DateTime.now()
          .microsecondsSinceEpoch
          .toString(),

      category:
          selectedCategory ?? "",

      customName:
          selectedCategory == "Other"
              ? customNameController.text
                  .trim()
              : null,

      monthlySaving:
          monthlySaving,

      priority:
          priority,

      targetDate:
          targetDate,

      savedAmount:
          null,

      targetAmount:
          null,

      recommendedMonthlySaving:
          null,

      isActive:
          true,
    );
  }

  Goal get goal => currentGoal;

  // ================= SAVE CURRENT GOAL =================

  Future<bool> saveCurrentGoal() async {
    if (!isValid) {
      _errorMessage =
          validationMessage;

      notifyListeners();

      return false;
    }

    final newGoal =
        currentGoal;

    _goals.add(newGoal);

    notifyListeners();

    try {
      final response = await ApiService.post('/goals', body: {
        'goalType': newGoal.category == 'Other' ? 'custom' : newGoal.category.toLowerCase().replaceAll(' ', '_'),
        'targetAmount': newGoal.monthlySaving, // UI currently sets targetAmount via monthlySaving amountController
        'planningMode': newGoal.targetDate != null ? 'deadline_based' : 'contribution_based',
        'plannedContribution': newGoal.monthlySaving,
        'targetDate': newGoal.targetDate?.toIso8601String(),
        'priority': newGoal.priority,
        'customName': newGoal.customName,
      });

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final body = await ApiService.parseJson(response);
        final newId = body['data']?['goalId']?.toString() ?? newGoal.id;
        
        final idx = _goals.indexWhere((g) => g.id == newGoal.id);
        if (idx != -1) {
          _goals[idx] = newGoal.copyWith(id: newId);
        }
        
        clearForm(notify: false);
        notifyListeners();
        return true;
      }
      
      _errorMessage = 'Failed to create goal on backend';
    } catch (e) {
      _errorMessage = _cleanError(e);
    }

    _goals.removeWhere((goal) => goal.id == newGoal.id);
    notifyListeners();
    return false;

    clearForm(
      notify: false,
    );

    notifyListeners();

    return true;
  }

  // ================= SET / ADD DATA =================

  Future<bool> setGoals(
    List<Goal> goals,
  ) async {
    final backup =
        List<Goal>.from(_goals);

    _goals
      ..clear()
      ..addAll(goals);

    notifyListeners();

    // Adding/setting multiple goals at once is not supported directly by backend.
    // We will just replace local state, but they won't be saved on server.
    return true;

    return true;
  }

  Future<bool> addGoal(
    Goal goal,
  ) async {
    _goals.add(goal);

    notifyListeners();

    try {
      final response = await ApiService.post('/goals', body: {
        'goalType': goal.category == 'Other' ? 'custom' : goal.category.toLowerCase().replaceAll(' ', '_'),
        'targetAmount': goal.monthlySaving,
        'planningMode': goal.targetDate != null ? 'deadline_based' : 'contribution_based',
        'plannedContribution': goal.monthlySaving,
        'targetDate': goal.targetDate?.toIso8601String(),
        'priority': goal.priority,
        'customName': goal.customName,
      });

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final body = await ApiService.parseJson(response);
        final newId = body['data']?['goalId']?.toString() ?? goal.id;
        
        final idx = _goals.indexWhere((g) => g.id == goal.id);
        if (idx != -1) {
          _goals[idx] = goal.copyWith(id: newId);
        }
        return true;
      }
    } catch (e) {
      _errorMessage = _cleanError(e);
    }

    _goals.removeWhere((item) => item.id == goal.id);
    notifyListeners();
    return false;

    return true;
  }

  Future<bool> addGoals(
    List<Goal> goals,
  ) async {
    final backup =
        List<Goal>.from(_goals);

    _goals.addAll(goals);

    notifyListeners();

    // Not supported by backend as a batch operation.
    return true;

    return true;
  }

  // ================= UPDATE =================

  Future<bool> updateGoal(
    Goal updatedGoal,
  ) async {
    final index =
        _goals.indexWhere(
      (goal) =>
          goal.id == updatedGoal.id,
    );

    if (index == -1) {
      _errorMessage =
          "Goal not found";

      notifyListeners();

      return false;
    }

    final oldGoal =
        _goals[index];

    _goals[index] =
        updatedGoal;

    notifyListeners();

    try {
      final response = await ApiService.put('/goals/${updatedGoal.id}', body: {
        'goalType': updatedGoal.category == 'Other' ? 'custom' : updatedGoal.category.toLowerCase().replaceAll(' ', '_'),
        'targetAmount': updatedGoal.monthlySaving,
        'planningMode': updatedGoal.targetDate != null ? 'deadline_based' : 'contribution_based',
        'plannedContribution': updatedGoal.monthlySaving,
        'targetDate': updatedGoal.targetDate?.toIso8601String(),
        'priority': updatedGoal.priority,
        'customName': updatedGoal.customName,
      });

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return true;
      }
    } catch (e) {
      _errorMessage = _cleanError(e);
    }

    _goals[index] = oldGoal;
    notifyListeners();
    return false;

    return true;
  }

  Future<bool> updateGoalProgress({
    required String goalId,
    required double savedAmount,
    required double targetAmount,
    double? recommendedMonthlySaving,
  }) async {
    final index =
        _goals.indexWhere(
      (goal) =>
          goal.id == goalId,
    );

    if (index == -1) {
      return false;
    }

    final oldGoal =
        _goals[index];

    _goals[index] =
        oldGoal.copyWith(
      savedAmount:
          savedAmount,
      targetAmount:
          targetAmount,
      recommendedMonthlySaving:
          recommendedMonthlySaving,
    );

    notifyListeners();

    // We can't save this arbitrarily via the backend since progress is managed via cycles/allocations.
    // For now we just return true.
    return true;

    return true;
  }

  Future<bool> addSavingToGoal({
    required String goalId,
    required double amount,
  }) async {
    if (amount <= 0) {
      return false;
    }

    final index =
        _goals.indexWhere(
      (goal) =>
          goal.id == goalId,
    );

    if (index == -1) {
      return false;
    }

    final oldGoal =
        _goals[index];

    final currentSavedAmount =
        oldGoal.savedAmount ?? 0;

    _goals[index] =
        oldGoal.copyWith(
      savedAmount:
          currentSavedAmount + amount,
    );

    notifyListeners();

    // Manual contribution addition requires backend support via /goals/:id/contributions
    try {
      final response = await ApiService.post('/goals/$goalId/contributions', body: {
        'amount': amount,
      });

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return true;
      }
    } catch (e) {
      _errorMessage = _cleanError(e);
    }

    _goals[index] = oldGoal;
    notifyListeners();
    return false;

    return true;
  }

  // ================= COMPLETE =================

  Future<bool> markGoalCompleted(
    String goalId,
  ) async {
    final index =
        _goals.indexWhere(
      (goal) =>
          goal.id == goalId,
    );

    if (index == -1) {
      return false;
    }

    final oldGoal =
        _goals[index];

    _goals[index] =
        oldGoal.copyWith(
      isActive: false,
    );

    notifyListeners();

    try {
      // Assuming completing a goal is done via updating its status
      final response = await ApiService.put('/goals/$goalId', body: {
        'status': 'completed',
      });

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return true;
      } else {
        _errorMessage = await ApiService.getErrorMessage(response, fallback: 'Failed to complete goal');
      }
    } catch (e) {
      _errorMessage = _cleanError(e);
    }

    _goals[index] = oldGoal;
    notifyListeners();
    return false;
  }

  // ================= DELETE =================

  Future<bool> removeGoal(
    String goalId,
  ) async {
    final index =
        _goals.indexWhere(
      (goal) =>
          goal.id == goalId,
    );

    if (index == -1) {
      return false;
    }

    final removedGoal =
        _goals.removeAt(index);

    notifyListeners();

    try {
      final response = await ApiService.delete('/goals/$goalId');
      
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return true;
      } else {
        final body = await ApiService.parseJson(response);
        final errorCode = body['meta']?['code']?.toString() ?? body['code']?.toString() ?? body['error']?['code']?.toString();
        
        if (errorCode == 'GOAL_HAS_LEDGER_HISTORY' || response.statusCode == 409) {
          _errorMessage = 'Cannot delete a goal that has transaction history. Please archive or complete it instead.';
        } else {
          _errorMessage = await ApiService.getErrorMessage(response, fallback: 'Failed to delete goal');
        }
      }
    } catch (e) {
      _errorMessage = _cleanError(e);
    }

    _goals.insert(index, removedGoal);
    notifyListeners();
    return false;
  }

  // ================= ADVANCED ACTIONS =================

  Future<dynamic> planningPreview(Map<String, dynamic> data) async {
    final response = await ApiService.post('/goals/planning-preview', body: data);
    return _parseOrError(response);
  }

  Future<dynamic> getReadyGoals() async {
    final response = await ApiService.get('/goals/ready');
    return _parseOrError(response);
  }

  Future<bool> executeGoal(String id) async {
    final response = await ApiService.post('/goals/$id/execute');
    return _isSuccess(response);
  }

  Future<bool> deferGoal(String id) async {
    final response = await ApiService.post('/goals/$id/defer');
    return _isSuccess(response);
  }

  Future<bool> reallocateGoal(String id, Map<String, dynamic> body) async {
    final response = await ApiService.post('/goals/$id/reallocate', body: body);
    return _isSuccess(response);
  }

  Future<dynamic> getLedgerHistory(String id) async {
    final response = await ApiService.get('/goals/$id/transactions');
    return _parseOrError(response);
  }

  Future<bool> addContribution(String id, double amount, {String sourceType = 'manual'}) async {
    final String idempotencyKey = DateTime.now().millisecondsSinceEpoch.toString();
    final response = await ApiService.post('/goals/$id/contributions', body: {
      'amount': amount,
      'sourceType': sourceType,
    }, headers: {'Idempotency-Key': idempotencyKey});
    return _isSuccess(response);
  }

  Future<bool> pauseGoal(String id) async {
    final response = await ApiService.post('/goals/$id/pause');
    return _isSuccess(response);
  }

  Future<bool> resumeGoal(String id) async {
    final response = await ApiService.post('/goals/$id/resume');
    return _isSuccess(response);
  }

  Future<dynamic> _parseOrError(dynamic response) async {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final body = await ApiService.parseJson(response);
      return body['data'];
    } else {
      _errorMessage = await ApiService.getErrorMessage(response);
      notifyListeners();
      return null;
    }
  }

  Future<bool> _isSuccess(dynamic response) async {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return true;
    } else {
      _errorMessage = await ApiService.getErrorMessage(response);
      notifyListeners();
      return false;
    }
  }

  // ================= CLEAR FORM =================

  void clearForm({
    bool notify = true,
  }) {
    customNameController.clear();
    amountController.clear();
    targetDateController.clear();

    selectedCategory = null;
    targetDate = null;
    priority = 5;
    emergencyPercentage = 10;
    _errorMessage = null;

    if (notify) {
      notifyListeners();
    }
  }

  // ================= API BODY =================

  Map<String, dynamic> get data {
    return currentGoal.toJson();
  }

  // ================= ERROR =================

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  String _cleanError(
    Object error,
  ) {
    return error
        .toString()
        .replaceFirst(
          'Exception: ',
          '',
        );
  }

  // ================= DISPOSE =================

  @override
  void dispose() {
    customNameController.dispose();
    amountController.dispose();
    targetDateController.dispose();

    super.dispose();
  }
}