class Goal {
  final String? id;
  final String category;
  final String? customName;

  /// القيمة التي يدخلها المستخدم في صفحة إنشاء الهدف.
  final double monthlySaving;

  final int priority;
  final DateTime? targetDate;

  /// هذه القيم يمكن أن ترجع لاحقًا من الباك إند.
  final double? savedAmount;
  final double? targetAmount;
  final double? recommendedMonthlySaving;

  final bool isActive;

  const Goal({
    this.id,
    required this.category,
    this.customName,
    required this.monthlySaving,
    required this.priority,
    this.targetDate,
    this.savedAmount,
    this.targetAmount,
    this.recommendedMonthlySaving,
    this.isActive = true,
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
    return savedAmount != null &&
        targetAmount != null &&
        targetAmount! > 0;
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
    return recommendedMonthlySaving ?? monthlySaving;
  }

  // ================= JSON =================

  Map<String, dynamic> toJson() {
    return {
      if (id != null) "id": id,
      "category": category,
      "custom_name": customName,
      "monthly_saving": monthlySaving,
      "priority": priority,
      "target_date": targetDate?.toIso8601String(),
      if (savedAmount != null) "saved_amount": savedAmount,
      if (targetAmount != null) "target_amount": targetAmount,
      if (recommendedMonthlySaving != null)
        "recommended_monthly_saving": recommendedMonthlySaving,
      "is_active": isActive,
    };
  }

  factory Goal.fromJson(Map<String, dynamic> json) {
    return Goal(
      id: json["id"]?.toString(),
      category: json["category"]?.toString() ?? "",
      customName: json["custom_name"]?.toString(),
      monthlySaving:
          (json["monthly_saving"] as num?)?.toDouble() ?? 0,
      priority: (json["priority"] as num?)?.toInt() ?? 5,
      targetDate: json["target_date"] != null
          ? DateTime.tryParse(json["target_date"].toString())
          : null,
      savedAmount:
          (json["saved_amount"] as num?)?.toDouble(),
      targetAmount:
          (json["target_amount"] as num?)?.toDouble(),
      recommendedMonthlySaving:
          (json["recommended_monthly_saving"] as num?)
              ?.toDouble(),
      isActive: json["is_active"] as bool? ?? true,
    );
  }

  // ================= COPY WITH =================

  Goal copyWith({
    String? id,
    String? category,
    String? customName,
    double? monthlySaving,
    int? priority,
    DateTime? targetDate,
    double? savedAmount,
    double? targetAmount,
    double? recommendedMonthlySaving,
    bool? isActive,
  }) {
    return Goal(
      id: id ?? this.id,
      category: category ?? this.category,
      customName: customName ?? this.customName,
      monthlySaving: monthlySaving ?? this.monthlySaving,
      priority: priority ?? this.priority,
      targetDate: targetDate ?? this.targetDate,
      savedAmount: savedAmount ?? this.savedAmount,
      targetAmount: targetAmount ?? this.targetAmount,
      recommendedMonthlySaving:
          recommendedMonthlySaving ??
          this.recommendedMonthlySaving,
      isActive: isActive ?? this.isActive,
    );
  }
}