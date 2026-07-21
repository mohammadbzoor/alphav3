import 'dart:convert';

import 'package:alpha_app/models/profile_completion_model.dart';
import 'package:alpha_app/models/profile_model.dart';
import 'package:alpha_app/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfileProvider extends ChangeNotifier {
  ProfileProvider();

  final String? _storageKey = null; // Unused, we now use API

  ProfileModel? _profile;
  ProfileModel? get profile => _profile;

  ProfileCompletionModel? _profileCompletion;
  ProfileCompletionModel? get profileCompletion => _profileCompletion;

  // Additional data for Profile screen
  String _financialLevel = 'Intermediate';
  String get financialLevel => _financialLevel;

  String _financialTier = 'low';
  String get financialTier => _financialTier;

  int _activeGoalsCount = 0;
  int get activeGoalsCount => _activeGoalsCount;

  int _confirmedCycleExpensesCount = 0;
  int get confirmedCycleExpensesCount => _confirmedCycleExpensesCount;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _isSaving = false;
  bool get isSaving => _isSaving;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  String? _errorCode;
  String? get errorCode => _errorCode;

  bool get hasProfile => _profile != null;

  String get displayName {
    final value = _profile?.name.trim() ?? '';
    return value.isEmpty ? 'Not available' : value;
  }

  String get email {
    return (_profile?.email ?? '').isEmpty ? 'Not available' : _profile!.email;
  }

  String? get photoUrl {
    return _profile?.photoUrl;
  }

  /// Load profile summary once after auth is ready.
  /// Only call this once, after AuthProvider confirms user is authenticated.
  Future<void> loadProfileSummary() async {
    // Prevent concurrent duplicate requests
    if (_isLoading) {
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    _errorCode = null;
    notifyListeners();

    try {
      final response = await ApiService.get('/users/profile/summary');
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final body = jsonDecode(response.body);
        final data = body['data'];
        final user = data['user'] ?? {};
        final financial = data['financialProfile'] ?? {};
        final stats = data['statistics'] ?? {};

        _profile = ProfileModel(
          id: user['id']?.toString(),
          name: user['fullName']?.toString() ?? '',
          email: user['email']?.toString() ?? '',
          joinedAt: user['memberSince'] != null ? DateTime.parse(user['memberSince']) : null,
          photoUrl: user['avatarUrl'],
        );

        _financialLevel = financial['level']?.toString() ?? 'Intermediate';
        _financialTier = financial['tier']?.toString() ?? 'low';
        _activeGoalsCount = stats['activeGoals'] ?? 0;
        _confirmedCycleExpensesCount = stats['confirmedCycleExpenses'] ?? 0;

        if (data['profileCompletion'] != null) {
          _profileCompletion = ProfileCompletionModel.fromJson(data['profileCompletion']);
        }

        _errorMessage = null;
        _errorCode = null;
      } else if (response.statusCode == 403) {
        // Account not verified
        try {
          final body = jsonDecode(response.body);
          _errorCode = body['code'];
          _errorMessage = body['message'] ?? 'Account not verified. Please verify your email.';
        } catch (_) {
          _errorCode = 'ACCOUNT_NOT_VERIFIED';
          _errorMessage = 'Account not verified. Please verify your email.';
        }
      } else if (response.statusCode == 401) {
        // Unauthorized - token invalid or expired
        _errorCode = 'UNAUTHORIZED';
        _errorMessage = 'Your session has expired. Please log in again.';
      } else {
        _errorCode = 'LOAD_FAILED';
        _errorMessage = 'Failed to load profile summary (${response.statusCode})';
      }
    } catch (e) {
      _errorCode = 'NETWORK_ERROR';
      _errorMessage = 'Error loading profile: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshProfileSummary() async {
    await loadProfileSummary();
  }

  // Load full profile details for Editing
  Future<bool> loadFullProfile() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await ApiService.get('/users/profile');
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final body = jsonDecode(response.body);
        final data = body['data'];
        // getProfile returns a flat object: { id, fullName, email, phoneNumber, birthDate, gender, ... }
        _profile = ProfileModel(
          id: data['id']?.toString(),
          name: data['fullName']?.toString() ?? '',
          email: data['email']?.toString() ?? '',
          phone: data['phoneNumber']?.toString(),
          birthDate: data['birthDate'] != null
              ? DateTime.tryParse(data['birthDate'].toString())
              : null,
          gender: data['gender']?.toString(),
        );
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = 'Failed to load full profile';
      }
    } catch (e) {
      _errorMessage = 'Error loading full profile: $e';
    }
    
    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<bool> updateProfile({
    String? name,
    String? email,
    String? phone,
    String? photoUrl,
    String? gender,
    DateTime? birthDate,
  }) async {
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final Map<String, dynamic> updateData = {};
      if (name != null) updateData['fullName'] = name;
      if (email != null) updateData['email'] = email;
      if (phone != null) updateData['phone'] = phone;
      if (gender != null) updateData['gender'] = gender;
      if (birthDate != null) updateData['birthDate'] = birthDate.toIso8601String().split('T').first;

      final response = await ApiService.patch('/users/profile', body: updateData);
      
      if (response.statusCode >= 200 && response.statusCode < 300) {
        // Success — reload both full profile and summary (for completion)
        await loadFullProfile();
        // Fire and forget summary refresh to update profileCompletion
        loadProfileSummary();
        _isSaving = false;
        notifyListeners();
        return true;
      } else {
        final body = jsonDecode(response.body);
        _errorMessage = body['message'] ?? 'Failed to update profile';
      }
    } catch (e) {
      _errorMessage = 'Error updating profile: $e';
    }
    
    _isSaving = false;
    notifyListeners();
    return false;
  }

  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await ApiService.post('/auth/change-password', body: {
        'currentPassword': currentPassword,
        'newPassword': newPassword,
        'confirmPassword': confirmPassword,
      });

      if (response.statusCode >= 200 && response.statusCode < 300) {
        _isSaving = false;
        notifyListeners();
        return true;
      } else {
        final body = jsonDecode(response.body);
        _errorMessage = body['message'] ?? 'Failed to change password';
      }
    } catch (e) {
      _errorMessage = 'Network error during password change';
    }
    
    _isSaving = false;
    notifyListeners();
    return false;
  }

  Future<void> logout() async {
    try {
      await ApiService.post('/auth/logout', body: {});
    } catch (_) {}

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    await prefs.remove('refresh_token');

    _profile = null;
    _activeGoalsCount = 0;
    _confirmedCycleExpensesCount = 0;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}