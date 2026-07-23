import 'package:alpha_app/models/home_model.dart';
import 'package:alpha_app/services/home_service.dart';
import 'package:flutter/material.dart';

class HomeProvider extends ChangeNotifier {
  // =====================================================
  // STATE
  // =====================================================

  HomeModel? _homeData;

  HomeModel? get homeData => _homeData;

  bool _isLoading = false;

  bool get isLoading => _isLoading;

  String? _errorMessage;

  String? get errorMessage => _errorMessage;

  bool get hasData => _homeData != null;

  bool get hasError {
    return _errorMessage != null && _errorMessage!.trim().isNotEmpty;
  }

  // =====================================================
  // LOAD HOME DATA
  // =====================================================

  Future<void> loadHomeData({
    bool forceRefresh = false,
  }) async {
    if (_isLoading) {
      return;
    }

    if (_homeData != null && !forceRefresh) {
      return;
    }

    _isLoading = true;
    _errorMessage = null;

    notifyListeners();

    try {
      // Load consolidated dashboard data from single backend endpoint
      final dashboardData = await HomeService.loadDashboard();

      _homeData = _buildHomeModel(dashboardData);

      _errorMessage = null;
    } catch (error) {
      debugPrint(
        'LOAD HOME DATA ERROR: $error',
      );

      _errorMessage = 'Failed to load home data';
    } finally {
      _isLoading = false;

      notifyListeners();
    }
  }

  // =====================================================
  // BUILD HOME MODEL
  // =====================================================

  HomeModel _buildHomeModel(
    Map<String, dynamic> dashboardData,
  ) {
    debugPrint(
        'HOME STATUS: hasActiveCycle=${dashboardData['cycle'] != null}, setupRequired=${dashboardData['setupRequired']}, warningCodes=${dashboardData['warnings']}');

    return HomeModel.fromJson(dashboardData);
  }

  // =====================================================
  // LOCAL UPDATES
  // =====================================================

  void setHomeData(
    HomeModel homeData,
  ) {
    _homeData = homeData;
    _errorMessage = null;

    notifyListeners();
  }

  // =====================================================
  // REFRESH
  // =====================================================

  Future<void> refreshHomeData() {
    return loadHomeData(
      forceRefresh: true,
    );
  }

  // =====================================================
  // ERROR
  // =====================================================

  void setError(
    String message,
  ) {
    _errorMessage = message;
    _isLoading = false;

    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;

    notifyListeners();
  }

  // =====================================================
  // CLEAR
  // =====================================================

  void clearData() {
    _homeData = null;
    _errorMessage = null;
    _isLoading = false;

    notifyListeners();
  }
}
