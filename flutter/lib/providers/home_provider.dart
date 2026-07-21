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
    return _errorMessage != null &&
        _errorMessage!.trim().isNotEmpty;
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

      _errorMessage =
          'Failed to load home data';
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
    // Extract data from consolidated dashboard response
    final String userName = 'User'; // No user name in dashboard response
    
    // Calculate financial score from bucket status
    final Map<String, dynamic> buckets = 
        dashboardData['buckets'] is Map
        ? Map<String, dynamic>.from(dashboardData['buckets'])
        : {};
    
    int financialScore = 100;
    final String scoreMessage = 'Analyzing your financial health...';
    String scoreLevel = 'Good';
    
    // Adjust score based on bucket statuses
    if (buckets.isNotEmpty) {
      final needsStatus = buckets['needs']?['status'] ?? 'unavailable';
      final wantsStatus = buckets['wants']?['status'] ?? 'unavailable';
      final savingsStatus = buckets['savings']?['status'] ?? 'unavailable';
      
      if (needsStatus == 'exceeded' || wantsStatus == 'exceeded') {
        financialScore = 40;
        scoreLevel = 'Critical';
      } else if (needsStatus == 'critical' || wantsStatus == 'critical') {
        financialScore = 50;
        scoreLevel = 'Warning';
      } else if (needsStatus == 'warning' || wantsStatus == 'warning') {
        financialScore = 70;
        scoreLevel = 'Fair';
      }
    }

    // Extract income from consolidated response
    final Map<String, dynamic> income = 
        dashboardData['income'] is Map
        ? Map<String, dynamic>.from(dashboardData['income'])
        : {};
    final double incomeValue = 
        (income['recorded'] is num ? income['recorded'] as num : 0).toDouble();

    // Extract expenses from buckets
    final double expenses = ((buckets['needs']?['actual'] ?? 0) as num).toDouble() +
                           ((buckets['wants']?['actual'] ?? 0) as num).toDouble();

    // Extract savings
    final double savings = 
        ((buckets['savings']?['actual'] ?? 0) as num).toDouble();

    // Get setup required flag
    final bool setupRequired = dashboardData['setupRequired'] == true;
    
    // Extract first active goal if available
    HomeGoal? goal;
    final Map<String, dynamic> goalsData =
        dashboardData['goals'] is Map
        ? Map<String, dynamic>.from(dashboardData['goals'])
        : {};
    
    if (goalsData.isNotEmpty) {
      final List<dynamic> goalsItems =
          goalsData['items'] is List
          ? List<dynamic>.from(goalsData['items'])
          : [];
      
      if (goalsItems.isNotEmpty) {
        // Get first active goal
        final dynamic firstGoal = goalsItems.firstWhere(
          (g) => g is Map && g['status'] == 'active',
          orElse: () => goalsItems.first,
        );
        
        if (firstGoal is Map) {
          final goalMap = Map<String, dynamic>.from(firstGoal);
          goal = HomeGoal(
            id: goalMap['id']?.toString() ?? '',
            name: goalMap['name']?.toString() ?? 'Goal',
            progress: _normalizeProgress(
              ((goalMap['currentBalance'] ?? 0) is num
                  ? (goalMap['currentBalance'] as num) / 
                    ((goalMap['targetAmount'] ?? 1) as num)
                  : 0.0).toDouble()
            ),
          );
        }
      }
    }
    
    // Build from real data only - no dummy values
    debugPrint('HOME DASHBOARD DATA: $dashboardData');

    return HomeModel(
      userName: userName,
      financialScore: financialScore.clamp(0, 100),
      scoreMessage: scoreMessage,
      scoreLevel: scoreLevel,
      income: setupRequired ? 0 : incomeValue,
      expenses: setupRequired ? 0 : expenses,
      savings: setupRequired ? 0 : (savings < 0 ? 0 : savings),
      todayInsight: setupRequired ? 'Complete financial-cycle setup to activate the dashboard.' : 'No financial insight available yet.',
      goal: goal,
      challenge: null, // Challenges will be displayed separately
    );
  }

  double _normalizeProgress(double value) {
    if (value > 1) {
      return (value / 100).clamp(0.0, 1.0);
    }
    return value.clamp(0.0, 1.0);
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

  void clear() {
    _homeData = null;
    _errorMessage = null;
    _isLoading = false;

    notifyListeners();
  }
}