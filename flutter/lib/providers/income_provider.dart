import 'package:alpha_app/models/income_model.dart';
import 'package:alpha_app/services/api_service.dart';
import 'package:flutter/material.dart';

class IncomeProvider extends ChangeNotifier {
  final List<IncomeModel> _incomes = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<IncomeModel> get incomes => List.unmodifiable(_incomes);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  double get totalIncome {
    return _incomes.fold(0.0, (sum, item) => sum + item.amount);
  }

  Future<void> loadIncomes() async {
    if (_isLoading) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await ApiService.get('/incomes');
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final body = await ApiService.parseJson(response);
        final data = body['data'];
        final items = data['items'] ?? data;

        if (items is List) {
          final loadedIncomes = items
              .map((item) {
                final map = Map<String, dynamic>.from(item);
                return IncomeModel.fromJson(map);
              })
              .where((e) => e.id.isNotEmpty)
              .toList();

          _incomes.clear();
          _incomes.addAll(loadedIncomes);
        }
      } else {
        _errorMessage = await ApiService.getErrorMessage(response,
            fallback: 'Could not load incomes');
      }
    } catch (e) {
      _errorMessage = _cleanError(e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> createIncome(IncomeModel income) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final String idempotencyKey =
          DateTime.now().millisecondsSinceEpoch.toString();
      final response = await ApiService.post(
        '/incomes',
        body: income.toJson(),
        headers: {'Idempotency-Key': idempotencyKey},
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final body = await ApiService.parseJson(response);
        final data = body['data'] ?? {};
        final newId = data['id']?.toString() ?? income.id;
        _incomes.insert(
            0,
            IncomeModel(
              id: newId,
              amount: income.amount,
              source: income.source,
              description: income.description,
              incomeDate: income.incomeDate,
              isRecurring: income.isRecurring,
              createdAt: DateTime.now(),
            ));
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = await ApiService.getErrorMessage(response,
            fallback: 'Failed to create income');
      }
    } catch (e) {
      _errorMessage = _cleanError(e);
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<bool> deleteIncome(String id) async {
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await ApiService.delete('/incomes/$id');
      if (response.statusCode >= 200 && response.statusCode < 300) {
        _incomes.removeWhere((element) => element.id == id);
        notifyListeners();
        return true;
      } else {
        _errorMessage = await ApiService.getErrorMessage(response,
            fallback: 'Failed to delete income');
      }
    } catch (e) {
      _errorMessage = _cleanError(e);
    }
    notifyListeners();
    return false;
  }

  String _cleanError(Object error) {
    return error.toString().replaceFirst('Exception: ', '');
  }

  void clearData() {
    _incomes.clear();
    _isLoading = false;
    _errorMessage = null;
    notifyListeners();
  }
}
