import 'package:flutter/foundation.dart';
import 'package:alpha_app/services/api_service.dart';

class FinancialProfileProvider extends ChangeNotifier {
  bool _isLoading = false;
  String? _errorMessage;
  Map<String, dynamic>? _profileData;
  Map<String, dynamic>? _previewData;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  Map<String, dynamic>? get profileData => _profileData;
  Map<String, dynamic>? get previewData => _previewData;

  Future<bool> fetchProfile() async {
    _setLoading(true);
    _clearError();
    try {
      final response = await ApiService.get('/financial-profile');
      if (response.statusCode == 200) {
        try {
          final parsed = await ApiService.parseJson(response);
          if (parsed['success'] == true) {
            _profileData = parsed['data'];
            notifyListeners();
            return true;
          }
          _errorMessage = parsed['message'] ??
              'The financial profile response is incomplete.';
        } catch (e) {
          _errorMessage = 'The financial profile response is incomplete.';
        }
      } else if (response.statusCode == 404) {
        _errorMessage = 'No financial profile was found.';
      } else if (response.statusCode >= 500) {
        _errorMessage =
            'Unable to load your financial profile. Please try again.';
      } else {
        _errorMessage = 'Failed to load profile (${response.statusCode})';
      }
    } catch (e) {
      if (e.toString().contains('SocketException') ||
          e.toString().contains('TimeoutException')) {
        _errorMessage =
            'Unable to connect to the server. Check your connection and try again.';
      } else {
        _errorMessage =
            'Unable to connect to the server. Check your connection and try again.';
      }
    } finally {
      _setLoading(false);
    }
    return false;
  }

  Future<bool> updateProfile(Map<String, dynamic> data) async {
    _setLoading(true);
    _clearError();
    try {
      final response = await ApiService.patch('/financial-profile', body: data);
      if (response.statusCode == 200) {
        final parsed = await ApiService.parseJson(response);
        if (parsed['success'] == true) {
          await fetchProfile(); // refresh data
          return true;
        }
        _errorMessage = parsed['message'];
      } else {
        _errorMessage = 'Failed to update profile (${response.statusCode})';
      }
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _setLoading(false);
    }
    return false;
  }

  Future<bool> previewAllocation(Map<String, dynamic> data) async {
    _setLoading(true);
    _clearError();
    try {
      final response = await ApiService.post(
          '/financial-profile/allocation-preview',
          body: data);
      if (response.statusCode == 200) {
        final parsed = await ApiService.parseJson(response);
        if (parsed['success'] == true) {
          _previewData = parsed['data'];
          notifyListeners();
          return true;
        }
        _errorMessage = parsed['message'];
      } else {
        _errorMessage = 'Failed to preview allocation (${response.statusCode})';
      }
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _setLoading(false);
    }
    return false;
  }

  Future<bool> approveAllocation(Map<String, dynamic> data) async {
    _setLoading(true);
    _clearError();
    try {
      final response = await ApiService.post(
          '/financial-profile/allocation-approve',
          body: data);
      if (response.statusCode == 200) {
        final parsed = await ApiService.parseJson(response);
        if (parsed['success'] == true) {
          await fetchProfile(); // refresh data
          return true;
        }
        _errorMessage = parsed['message'];
      } else {
        _errorMessage = 'Failed to approve allocation (${response.statusCode})';
      }
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _setLoading(false);
    }
    return false;
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
