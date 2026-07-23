class HomeCycle {
  final String? id;
  final String? status;
  final DateTime? startDate;
  final DateTime? endDate;
  final int? daysRemaining;

  const HomeCycle({
    this.id,
    this.status,
    this.startDate,
    this.endDate,
    this.daysRemaining,
  });

  factory HomeCycle.fromJson(Map<String, dynamic> json) {
    return HomeCycle(
      id: json['id']?.toString(),
      status: json['status']?.toString(),
      startDate: json['startDate'] != null
          ? DateTime.tryParse(json['startDate'].toString())
          : null,
      endDate: json['endDate'] != null
          ? DateTime.tryParse(json['endDate'].toString())
          : null,
      daysRemaining: json['daysRemaining'] != null
          ? int.tryParse(json['daysRemaining'].toString())
          : null,
    );
  }
}

class HomeIncome {
  final double? expected;
  final double? recorded;
  final double? recurring;
  final double? unexpected;

  const HomeIncome({
    this.expected,
    this.recorded,
    this.recurring,
    this.unexpected,
  });

  factory HomeIncome.fromJson(Map<String, dynamic> json) {
    return HomeIncome(
      expected: _toDouble(json['expected']),
      recorded: _toDouble(json['recorded']),
      recurring: _toDouble(json['recurring']),
      unexpected: _toDouble(json['unexpected']),
    );
  }
}

class HomeBucket {
  final double? target;
  final double? actual;
  final double? reserved;
  final double? availableVariable;
  final double? remaining;
  final double? usagePercent;
  final String? status;

  // Specific to savings bucket
  final double? plannedEmergencyFund;
  final double? plannedGoalAllocations;
  final double? unallocatedSavings;

  const HomeBucket({
    this.target,
    this.actual,
    this.reserved,
    this.availableVariable,
    this.remaining,
    this.usagePercent,
    this.status,
    this.plannedEmergencyFund,
    this.plannedGoalAllocations,
    this.unallocatedSavings,
  });

  factory HomeBucket.fromJson(Map<String, dynamic> json) {
    return HomeBucket(
      target: _toDouble(json['target']),
      actual: _toDouble(json['actual']),
      reserved: _toDouble(json['reserved']),
      availableVariable: _toDouble(json['availableVariable']),
      remaining: _toDouble(json['remaining']),
      usagePercent: _toDouble(json['usagePercent']),
      status: json['status']?.toString() ?? 'unavailable',
      plannedEmergencyFund: _toDouble(json['plannedEmergencyFund']),
      plannedGoalAllocations: _toDouble(json['plannedGoalAllocations']),
      unallocatedSavings: _toDouble(json['unallocatedSavings']),
    );
  }
}

class HomeBuckets {
  final HomeBucket? needs;
  final HomeBucket? wants;
  final HomeBucket? savings;

  const HomeBuckets({this.needs, this.wants, this.savings});

  factory HomeBuckets.fromJson(Map<String, dynamic> json) {
    return HomeBuckets(
      needs: json['needs'] is Map ? HomeBucket.fromJson(json['needs']) : null,
      wants: json['wants'] is Map ? HomeBucket.fromJson(json['wants']) : null,
      savings:
          json['savings'] is Map ? HomeBucket.fromJson(json['savings']) : null,
    );
  }
}

class HomeGoalsSummary {
  final int activeCount;
  final int readyCount;
  final List<dynamic> items;

  const HomeGoalsSummary({
    required this.activeCount,
    required this.readyCount,
    required this.items,
  });

  factory HomeGoalsSummary.fromJson(Map<String, dynamic> json) {
    return HomeGoalsSummary(
      activeCount: int.tryParse(json['activeCount']?.toString() ?? '0') ?? 0,
      readyCount: int.tryParse(json['readyCount']?.toString() ?? '0') ?? 0,
      items: json['items'] is List ? json['items'] : [],
    );
  }
}

class HomeCommitmentsSummary {
  final double? totalReserved;
  final int upcomingCount;
  final int overdueCount;

  const HomeCommitmentsSummary({
    this.totalReserved,
    required this.upcomingCount,
    required this.overdueCount,
  });

  factory HomeCommitmentsSummary.fromJson(Map<String, dynamic> json) {
    return HomeCommitmentsSummary(
      totalReserved: _toDouble(json['totalReserved']),
      upcomingCount:
          int.tryParse(json['upcomingCount']?.toString() ?? '0') ?? 0,
      overdueCount: int.tryParse(json['overdueCount']?.toString() ?? '0') ?? 0,
    );
  }
}

class HomeSafeDailySpending {
  final double? amount;
  final String? reliability;
  final List<String> reasons;

  const HomeSafeDailySpending({
    this.amount,
    this.reliability,
    required this.reasons,
  });

  factory HomeSafeDailySpending.fromJson(Map<String, dynamic> json) {
    return HomeSafeDailySpending(
      amount: _toDouble(json['amount']),
      reliability: json['reliability']?.toString() ?? 'unavailable',
      reasons: json['reasons'] is List
          ? (json['reasons'] as List).map((e) => e.toString()).toList()
          : [],
    );
  }
}

class HomeComparison {
  final bool previousPeriodAvailable;
  final double? incomeChange;
  final double? expenseChange;
  final double? savingsChange;

  const HomeComparison({
    required this.previousPeriodAvailable,
    this.incomeChange,
    this.expenseChange,
    this.savingsChange,
  });

  factory HomeComparison.fromJson(Map<String, dynamic> json) {
    return HomeComparison(
      previousPeriodAvailable: json['previousPeriodAvailable'] == true,
      incomeChange: _toDouble(json['incomeChange']),
      expenseChange: _toDouble(json['expenseChange']),
      savingsChange: _toDouble(json['savingsChange']),
    );
  }
}

class HomeModel {
  final HomeCycle? cycle;
  final HomeIncome? income;
  final HomeBuckets? buckets;
  final HomeGoalsSummary? goals;
  final HomeCommitmentsSummary? commitments;
  final HomeSafeDailySpending? safeDailySpending;
  final HomeComparison? comparison;

  final bool setupRequired;
  final String? reliability;
  final List<String> warnings;

  const HomeModel({
    this.cycle,
    this.income,
    this.buckets,
    this.goals,
    this.commitments,
    this.safeDailySpending,
    this.comparison,
    required this.setupRequired,
    this.reliability,
    required this.warnings,
  });

  factory HomeModel.fromJson(Map<String, dynamic> json) {
    return HomeModel(
      cycle: json['cycle'] is Map ? HomeCycle.fromJson(json['cycle']) : null,
      income:
          json['income'] is Map ? HomeIncome.fromJson(json['income']) : null,
      buckets:
          json['buckets'] is Map ? HomeBuckets.fromJson(json['buckets']) : null,
      goals: json['goals'] is Map
          ? HomeGoalsSummary.fromJson(json['goals'])
          : null,
      commitments: json['commitments'] is Map
          ? HomeCommitmentsSummary.fromJson(json['commitments'])
          : null,
      safeDailySpending: json['safeDailySpending'] is Map
          ? HomeSafeDailySpending.fromJson(json['safeDailySpending'])
          : null,
      comparison: json['comparison'] is Map
          ? HomeComparison.fromJson(json['comparison'])
          : null,
      setupRequired: json['setupRequired'] == true,
      reliability: json['reliability']?.toString(),
      warnings: json['warnings'] is List
          ? (json['warnings'] as List).map((e) => e.toString()).toList()
          : [],
    );
  }
}

double? _toDouble(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}
