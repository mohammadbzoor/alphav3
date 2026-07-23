import 'package:flutter/foundation.dart';
import 'package:alpha_app/services/onboarding_service.dart';
import 'package:alpha_app/services/api_service.dart';

class OnboardingProvider extends ChangeNotifier {
  String _nextStep = 'otp_verification';
  bool _isOnboarded = false;
  bool _canCreateCycle = false;
  bool _financialProfileComplete = false;
  List<String> _missingFinancialFields = [];
  bool _isLoading = false;
  String? _errorMessage;
  dynamic _allocation;

  String get nextStep => _nextStep;
  bool get isOnboarded => _isOnboarded;
  bool get canCreateCycle => _canCreateCycle;
  bool get financialProfileComplete => _financialProfileComplete;
  List<String> get missingFinancialFields => _missingFinancialFields;
  bool get isLoading => _isLoading;
  bool get isSaving => _isLoading;
  String? get errorMessage => _errorMessage;
  dynamic get allocation => _allocation;

  Future<bool> checkOnboardingStatus() async {
    if (_isLoading) return false;
    _setLoading(true);
    _clearError();
    try {
      final response = await ApiService.get('/onboarding/status');

      if (response.statusCode == 401 || response.statusCode == 403) {
        _errorMessage = 'UNAUTHORIZED';
        return false;
      }

      if (response.statusCode >= 500) {
        _errorMessage = 'SERVER_ERROR: ${response.statusCode}';
        return false;
      }

      final parsed = await ApiService.parseJson(response);

      if (parsed['success'] == true) {
        final data = parsed['data'] ?? parsed;
        if (!data.containsKey('isOnboarded') &&
            !data.containsKey('is_onboarded')) {
          _errorMessage = 'Contract Error: Backend did not return isOnboarded';
          return false;
        }
        if (!data.containsKey('nextStep') && !data.containsKey('next_step')) {
          _errorMessage = 'Contract Error: Backend did not return nextStep';
          return false;
        }
        if (!data.containsKey('canCreateCycle') &&
            !data.containsKey('can_create_cycle')) {
          _errorMessage =
              'Contract Error: Backend did not return canCreateCycle';
          return false;
        }

        _isOnboarded = data['isOnboarded'] ?? data['is_onboarded'];
        _nextStep = data['nextStep'] ?? data['next_step'];
        _canCreateCycle = data['canCreateCycle'] ?? data['can_create_cycle'];

        _financialProfileComplete = data['financialProfileComplete'] ??
            data['financial_profile_complete'] ??
            false;
        _missingFinancialFields = List<String>.from(
            data['missingFinancialFields'] ??
                data['missing_financial_fields'] ??
                []);

        final rawAllocation = data['allocation'] ?? {};
        _allocation = Map<String, dynamic>.from(rawAllocation);
        if (data.containsKey('income')) {
          _allocation['income'] = data['income'];
        }
        if (data.containsKey('tier')) {
          _allocation['tier'] = data['tier'];
        }
        notifyListeners();

        if (kDebugMode) {
          debugPrint('STATUS: nextStep=$_nextStep, isOnboarded=$_isOnboarded');
        }
        return true;
      }
      _errorMessage = parsed['message'] ?? 'Unknown error';
      return false;
    } catch (e, stack) {
      debugPrint('ONBOARDING_ERROR: $e');
      debugPrint('ONBOARDING_STACK: $stack');
      _errorMessage = e.toString();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> savePersonalInfo(Map<String, dynamic> data) async {
    _setLoading(true);
    _clearError();
    try {
      final response = await OnboardingService.savePersonalInfo(data);
      if (response['success'] == true) {
        final responseData = response['data'] ?? response;

        if (!responseData.containsKey('isOnboarded') &&
            !responseData.containsKey('is_onboarded')) {
          _errorMessage = 'Contract Error: Backend did not return isOnboarded';
          notifyListeners();
          return false;
        }
        if (!responseData.containsKey('nextStep') &&
            !responseData.containsKey('next_step')) {
          _errorMessage = 'Contract Error: Backend did not return nextStep';
          notifyListeners();
          return false;
        }
        if (!responseData.containsKey('canCreateCycle') &&
            !responseData.containsKey('can_create_cycle')) {
          _errorMessage =
              'Contract Error: Backend did not return canCreateCycle';
          notifyListeners();
          return false;
        }

        _isOnboarded =
            responseData['isOnboarded'] ?? responseData['is_onboarded'];
        _nextStep = responseData['nextStep'] ?? responseData['next_step'];
        _canCreateCycle =
            responseData['canCreateCycle'] ?? responseData['can_create_cycle'];
        _financialProfileComplete = responseData['financialProfileComplete'] ??
            responseData['financial_profile_complete'] ??
            false;
        _missingFinancialFields = List<String>.from(
            responseData['missingFinancialFields'] ??
                responseData['missing_financial_fields'] ??
                []);

        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> saveFinancialSetup({
    dynamic monthlyIncome,
    dynamic paymentDay,
    dynamic relationshipWithMoney,
    dynamic primaryFinancialGoal,
    dynamic monthlyExtraSavingsGoal,
    dynamic incomeSources,
    dynamic fixedExpenses,
    dynamic variableExpenses,
  }) async {
    _setLoading(true);
    _clearError();
    try {
      final data = {
        if (monthlyIncome != null) 'monthlyIncome': monthlyIncome,
        if (paymentDay != null) 'paymentDay': paymentDay,
        if (relationshipWithMoney != null)
          'relationshipWithMoney': relationshipWithMoney,
        if (primaryFinancialGoal != null)
          'primaryFinancialGoal': primaryFinancialGoal,
        if (monthlyExtraSavingsGoal != null)
          'monthlyExtraSavingsGoal': monthlyExtraSavingsGoal,
        if (incomeSources != null) 'incomeSources': incomeSources,
        if (fixedExpenses != null) 'fixedExpenses': fixedExpenses,
        if (variableExpenses != null) 'variableExpenses': variableExpenses,
      };

      final response = await OnboardingService.saveFinancialSetup(data);
      if (response['success'] == true) {
        final responseData = response['data'] ?? response;

        if (!responseData.containsKey('income') ||
            responseData['income'] == null) {
          _errorMessage = 'Contract Error: Backend did not return income';
          notifyListeners();
          return false;
        }

        if (!responseData.containsKey('isOnboarded') &&
            !responseData.containsKey('is_onboarded')) {
          _errorMessage = 'Contract Error: Backend did not return isOnboarded';
          notifyListeners();
          return false;
        }
        if (!responseData.containsKey('nextStep') &&
            !responseData.containsKey('next_step')) {
          _errorMessage = 'Contract Error: Backend did not return nextStep';
          notifyListeners();
          return false;
        }
        if (!responseData.containsKey('canCreateCycle') &&
            !responseData.containsKey('can_create_cycle')) {
          _errorMessage =
              'Contract Error: Backend did not return canCreateCycle';
          notifyListeners();
          return false;
        }

        _isOnboarded =
            responseData['isOnboarded'] ?? responseData['is_onboarded'];
        _nextStep = responseData['nextStep'] ?? responseData['next_step'];
        _canCreateCycle =
            responseData['canCreateCycle'] ?? responseData['can_create_cycle'];
        _financialProfileComplete = responseData['financialProfileComplete'] ??
            responseData['financial_profile_complete'] ??
            false;
        _missingFinancialFields = List<String>.from(
            responseData['missingFinancialFields'] ??
                responseData['missing_financial_fields'] ??
                []);

        final rawAllocation = responseData['allocation'] ?? {};
        _allocation = Map<String, dynamic>.from(rawAllocation);
        _allocation['income'] = responseData['income'];

        if (responseData.containsKey('tier')) {
          _allocation['tier'] = responseData['tier'];
        }

        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> approveAllocation(Map<String, dynamic> data) async {
    _setLoading(true);
    _clearError();
    try {
      final response = await OnboardingService.approveAllocation(data);
      if (response['success'] == true) {
        final responseData = response['data'] ?? response;

        if (!responseData.containsKey('nextStep') &&
            !responseData.containsKey('next_step')) {
          _errorMessage = 'Contract Error: Backend did not return nextStep';
          notifyListeners();
          return false;
        }

        if (!responseData.containsKey('isOnboarded') &&
            !responseData.containsKey('is_onboarded')) {
          _errorMessage = 'Contract Error: Backend did not return isOnboarded';
          notifyListeners();
          return false;
        }
        if (!responseData.containsKey('canCreateCycle') &&
            !responseData.containsKey('can_create_cycle')) {
          _errorMessage =
              'Contract Error: Backend did not return canCreateCycle';
          notifyListeners();
          return false;
        }

        _isOnboarded =
            responseData['isOnboarded'] ?? responseData['is_onboarded'];
        _nextStep = responseData['nextStep'] ?? responseData['next_step'];
        _canCreateCycle =
            responseData['canCreateCycle'] ?? responseData['can_create_cycle'];
        _financialProfileComplete = responseData['financialProfileComplete'] ??
            responseData['financial_profile_complete'] ??
            false;
        _missingFinancialFields = List<String>.from(
            responseData['missingFinancialFields'] ??
                responseData['missing_financial_fields'] ??
                []);

        if (_nextStep != 'dashboard' || _isOnboarded != true) {
          _errorMessage =
              'Contract Error: Invalid onboarding state after allocation';
          notifyListeners();
          return false;
        }

        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  void _setLoading(bool val) {
    _isLoading = val;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
  }

  void clearError() {
    _clearError();
    notifyListeners();
  }

  void clearData() {
    _nextStep = 'otp_verification';
    _isOnboarded = false;
    _canCreateCycle = false;
    _financialProfileComplete = false;
    _missingFinancialFields = [];
    _isLoading = false;
    _errorMessage = null;
    _allocation = null;
    notifyListeners();
  }
}
