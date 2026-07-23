import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:alpha_app/providers/onboarding_provider.dart';
import 'package:alpha_app/services/api_service.dart';
import 'package:alpha_app/services/api_exception.dart';

class CycleProvider extends ChangeNotifier {
  dynamic _currentCycle;
  bool _isLoading = false;
  bool _isCreatingCycle = false;
  String? _error;

  dynamic get currentCycle => _currentCycle;
  bool get hasActiveCycle => _currentCycle != null;
  bool get isLoading => _isLoading;
  bool get isCreatingCycle => _isCreatingCycle;
  String? get error => _error;

  void clearData() {
    _currentCycle = null;
    _isLoading = false;
    _isCreatingCycle = false;
    _error = null;
    notifyListeners();
  }

  Future<void> loadCurrentCycle() async {
    if (_isLoading) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await ApiService.get('/financial-cycles/current');

      if (response == null) {
        throw const ApiException(message: "تعذر الاتصال بالخادم");
      }

      final Map<String, dynamic> body = await ApiService.parseJson(response);

      if (response.statusCode == 200) {
        _currentCycle = body['data'] ?? body;
        _error = null;
      } else if (response.statusCode == 404) {
        final code = body['error']?['code'] ?? body['code'];
        if (code == 'CYCLE_NOT_FOUND') {
          // Normal state: User has no active cycle
          _currentCycle = null;
          _error = null;
        } else {
          _currentCycle = null;
          throw ApiException(
            message: await ApiService.getErrorMessage(response,
                fallback: 'دورة مالية غير موجودة'),
            statusCode: 404,
            code: code,
          );
        }
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        // Leave to interceptors/session flow, but set error
        _currentCycle = null;
        throw ApiException(
          message: "انتهت الجلسة أو غير مصرح لك.",
          statusCode: response.statusCode,
        );
      } else {
        _currentCycle = null;
        throw ApiException(
          message: await ApiService.getErrorMessage(response,
              fallback: "تعذر تحميل الدورة المالية"),
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      if (e is ApiException) {
        _error = e.message;
      } else {
        _error = "تعذر الاتصال بالخادم";
      }
      _currentCycle = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> createCycle(
      Map<String, dynamic> cycleData, OnboardingProvider onboarding) async {
    if (!onboarding.isOnboarded || !onboarding.canCreateCycle) {
      _error = "الملف المالي غير مكتمل أو لا يمكنك إنشاء دورة حالياً.";
      notifyListeners();
      return false;
    }

    _isCreatingCycle = true;
    _error = null;
    notifyListeners();

    try {
      final response =
          await ApiService.post('/financial-cycles', body: cycleData);

      if (response == null) {
        throw const ApiException(message: "تعذر الاتصال بالخادم");
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        _currentCycle = data['data'] ?? data;
        return true;
      } else if (response.statusCode == 409) {
        throw ApiException(
          message: "توجد دورة مالية مفتوحة بالفعل.",
          statusCode: 409,
        );
      } else {
        throw ApiException(
          message: await ApiService.getErrorMessage(response,
              fallback: "فشل إنشاء الدورة المالية"),
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      if (e is ApiException) {
        _error = e.message;
      } else {
        _error = "تعذر الاتصال بالخادم";
      }
      return false;
    } finally {
      _isCreatingCycle = false;
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  Future<Map<String, dynamic>?> getCyclePlanningSummary(String cycleId) async {
    try {
      final response = await ApiService.get('/financial-cycles/$cycleId/planning-summary');
      if (response != null && response.statusCode == 200) {
        final body = await ApiService.parseJson(response);
        return body['data'];
      }
      return null;
    } catch (e) {
      debugPrint('Error getting cycle planning summary: $e');
      return null;
    }
  }

  Future<bool> linkSavingsAllocation(String cycleId, double emergencyFundPercentage) async {
    try {
      final response = await ApiService.post(
        '/financial-cycles/$cycleId/savings-allocation',
        body: {'emergencyFundPercentage': emergencyFundPercentage},
      );
      if (response != null && (response.statusCode == 200 || response.statusCode == 201)) {
        return true;
      }
      _error = await ApiService.getErrorMessage(response!, fallback: "فشل حفظ التخصيص");
      notifyListeners();
      return false;
    } catch (e) {
      if (e is ApiException) {
        _error = e.message;
      } else {
        _error = "تعذر الاتصال بالخادم";
      }
      notifyListeners();
      return false;
    }
  }

  String _cleanError(dynamic error) {
    return error.toString().replaceAll('Exception:', '').trim();
  }
}
