class Goal {
  final String? id;
  final String category;
  final String? customName;

  /// المساهمة الشهرية المخططة.
  final double plannedContribution;

  final int priority;
  final DateTime? targetDate;

  final double? savedAmount;
  /// إجمالي قيمة الهدف
  final double? targetAmount;
  final double? recommendedMonthlySaving;

  final bool isActive;
  final String planningMode;

  const Goal({
    this.id,
    required this.category,
    this.customName,
    required this.plannedContribution,
    required this.priority,
    this.targetDate,
    this.savedAmount,
    this.targetAmount,
    this.recommendedMonthlySaving,
    this.isActive = true,
    this.planningMode = 'deadline_based',
  });

  // ================= DISPLAY NAME =================

  String get title {
    final name = customName?.trim();

    if (name != null && name.isNotEmpty) {
      return name;
    }

    return category;
  }

  // ================= DAYS LEFT =================

  int get daysLeft {
    if (targetDate == null) {
      return 0;
    }

    final now = DateTime.now();

    final today = DateTime(
      now.year,
      now.month,
      now.day,
    );

    final deadline = DateTime(
      targetDate!.year,
      targetDate!.month,
      targetDate!.day,
    );

    final difference = deadline.difference(today).inDays;

    return difference < 0 ? 0 : difference;
  }

  /// حسب التصميم:
  /// 60 يومًا أو أقل = دائرة صفراء.
  /// أكثر من 60 يومًا = شريط أخضر.
  bool get showCircularProgress => daysLeft <= 60;

  // ================= PROGRESS =================

  bool get hasProgressData {
    return savedAmount != null && targetAmount != null && targetAmount! > 0;
  }

  double get progress {
    if (!hasProgressData) {
      return 0;
    }

    return (savedAmount! / targetAmount!).clamp(0.0, 1.0);
  }

  int get progressPercentage {
    return (progress * 100).round();
  }

  double get remainingAmount {
    if (!hasProgressData) {
      return 0;
    }

    final value = targetAmount! - savedAmount!;

    return value < 0 ? 0 : value;
  }

  bool get isCompleted {
    return hasProgressData && savedAmount! >= targetAmount!;
  }

  /// إذا الباك إند لم يرسل توصية بعد،
  /// يتم عرض القيمة التي أدخلها المستخدم.
  double get displayedMonthlyRecommendation {
    return recommendedMonthlySaving ?? plannedContribution;
  }
  
  // Backward compatibility alias for UI elements expecting monthlySaving
  double get monthlySaving => plannedContribution;

  // ================= JSON =================

  Map<String, dynamic> toJson() {
    return {
      if (id != null) "id": id,
      "category": category,
      "custom_name": customName,
      "planned_contribution": plannedContribution,
      "priority": priority,
      "target_date": targetDate?.toIso8601String(),
      if (savedAmount != null) "current_balance": savedAmount,
      if (targetAmount != null) "target_amount": targetAmount,
      if (recommendedMonthlySaving != null)
        "recommended_monthly_saving": recommendedMonthlySaving,
      "is_active": isActive,
      "planning_mode": planningMode,
    };
  }

  factory Goal.fromJson(Map<String, dynamic> json) {
    return Goal(
      id: json["id"]?.toString(),
      category: json["category"]?.toString() ?? json["goal_type"]?.toString() ?? "",
      customName: json["custom_name"]?.toString(),
      plannedContribution: (json["planned_contribution"] as num?)?.toDouble() ?? (json["monthly_saving"] as num?)?.toDouble() ?? 0,
      priority: (json["priority"] as num?)?.toInt() ?? 5,
      targetDate: json["target_date"] != null
          ? DateTime.tryParse(json["target_date"].toString())
          : null,
      savedAmount: (json["current_balance"] as num?)?.toDouble() ?? (json["saved_amount"] as num?)?.toDouble(),
      targetAmount: (json["target_amount"] as num?)?.toDouble(),
      recommendedMonthlySaving:
          (json["recommended_monthly_saving"] as num?)?.toDouble(),
      isActive: json["status"] == "active" || json["status"] == "draft" || json["is_active"] == true,
      planningMode: json["planning_mode"]?.toString() ?? 'deadline_based',
    );
  }

  // ================= COPY WITH =================

  Goal copyWith({
    String? id,
    String? category,
    String? customName,
    double? plannedContribution,
    int? priority,
    DateTime? targetDate,
    double? savedAmount,
    double? targetAmount,
    double? recommendedMonthlySaving,
    bool? isActive,
    String? planningMode,
  }) {
    return Goal(
      id: id ?? this.id,
      category: category ?? this.category,
      customName: customName ?? this.customName,
      plannedContribution: plannedContribution ?? this.plannedContribution,
      priority: priority ?? this.priority,
      targetDate: targetDate ?? this.targetDate,
      savedAmount: savedAmount ?? this.savedAmount,
      targetAmount: targetAmount ?? this.targetAmount,
      recommendedMonthlySaving:
          recommendedMonthlySaving ?? this.recommendedMonthlySaving,
      isActive: isActive ?? this.isActive,
      planningMode: planningMode ?? this.planningMode,
    );
  }
}
