import 'package:alpha_app/models/challenge_model.dart';
import 'package:alpha_app/services/api_service.dart';
import 'package:flutter/material.dart';

class ChallengeProvider extends ChangeNotifier {
  final List<ChallengeModel> _available = [];
  final List<ChallengeModel> _current = [];
  final List<ChallengeModel> _completed = [];

  bool _isLoading = false;
  String? _errorMessage;

  ChallengeType _selectedType = ChallengeType.individual;
  ChallengeStatus _selectedStatus = ChallengeStatus.current;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  ChallengeType get selectedType => _selectedType;
  ChallengeStatus get selectedStatus => _selectedStatus;

  List<ChallengeModel> get challenges {
    return [..._available, ..._current, ..._completed];
  }

  List<ChallengeModel> get filteredChallenges {
    if (_selectedStatus == ChallengeStatus.available) {
      return _available.where((c) => c.type == _selectedType).toList();
    } else if (_selectedStatus == ChallengeStatus.current) {
      return _current.where((c) => c.type == _selectedType).toList();
    } else if (_selectedStatus == ChallengeStatus.completed) {
      return _completed.where((c) => c.type == _selectedType).toList();
    }
    return [];
  }

  List<ChallengeModel> get activeChallenges {
    return _current;
  }

  ChallengeModel? get firstActiveChallenge {
    if (_current.isEmpty) return null;
    return _current.first;
  }

  Future<void> loadChallenges() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await ApiService.get('/challenges');
      if (ApiService.isSuccess(response)) {
        final body = await ApiService.parseJson(response);
        if (body['success'] == true) {
          final data = body['data'];
          _available.clear();
          _current.clear();
          _completed.clear();

          if (data['available'] != null) {
            _available.addAll((data['available'] as List)
                .map((e) => ChallengeModel.fromJson(e)));
          }
          if (data['current'] != null) {
            _current.addAll((data['current'] as List)
                .map((e) => ChallengeModel.fromJson(e)));
          }
          if (data['completed'] != null) {
            _completed.addAll((data['completed'] as List)
                .map((e) => ChallengeModel.fromJson(e)));
          }
        }
      } else {
        _errorMessage = "Failed to load challenges";
      }
    } catch (error) {
      _errorMessage = "Unable to load challenges";
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void selectType(ChallengeType type) {
    _selectedType = type;
    notifyListeners();
  }

  void selectStatus(ChallengeStatus status) {
    _selectedStatus = status;
    notifyListeners();
  }

  Future<void> acceptChallenge(String templateId) async {
    try {
      final response = await ApiService.post('/challenges/$templateId/accept', body: {});
      if (ApiService.isSuccess(response)) {
        final body = await ApiService.parseJson(response);
        if (body['success'] == true && body['data'] != null) {
          final newChallenge = ChallengeModel.fromJson(body['data']);
          _available.removeWhere((c) => c.templateId == templateId || c.id == templateId);
          _current.add(newChallenge);
          notifyListeners();
        }
      } else {
        throw Exception("Failed to accept challenge");
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> cancelChallenge(String userChallengeId) async {
    try {
      final response = await ApiService.post('/challenges/$userChallengeId/cancel', body: {});
      if (ApiService.isSuccess(response)) {
        _current.removeWhere((c) => c.id == userChallengeId);
        notifyListeners();
        // optionally reload all challenges to get it back into available
        await loadChallenges();
      } else {
        throw Exception("Failed to cancel challenge");
      }
    } catch (e) {
      rethrow;
    }
  }
}
