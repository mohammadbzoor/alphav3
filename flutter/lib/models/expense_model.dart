enum ExpenseType {
  need,
  want,
}

enum ExpenseSource {
  manual,
  receipt,
  voice,
  bank,
}

enum ExpenseMovementType {
  occasional,
  recurring,
}

enum ExpenseCoveragePeriod {
  oneDay,
  threeDays,
  oneWeek,
  twoWeeks,
  monthly,
}

class ExpenseModel {
  final String id;

  final String title;

  final String category;

  final double amount;

  final DateTime date;

  final String paymentMethod;

  final String? note;

  final ExpenseType expenseType;

  final ExpenseSource source;

  final ExpenseMovementType movementType;

  final ExpenseCoveragePeriod coveragePeriod;

  final String? aiInsight;

  final double? confidence;

  final DateTime createdAt;

  const ExpenseModel({
    required this.id,
    required this.title,
    required this.category,
    required this.amount,
    required this.date,
    required this.paymentMethod,
    this.note,
    required this.expenseType,
    required this.source,
    required this.movementType,
    required this.coveragePeriod,
    this.aiInsight,
    this.confidence,
    required this.createdAt,
  });

  bool get isRecurring {
    return movementType ==
        ExpenseMovementType.recurring;
  }

  int get coverageDays {
    switch (coveragePeriod) {
      case ExpenseCoveragePeriod.oneDay:
        return 1;

      case ExpenseCoveragePeriod.threeDays:
        return 3;

      case ExpenseCoveragePeriod.oneWeek:
        return 7;

      case ExpenseCoveragePeriod.twoWeeks:
        return 14;

      case ExpenseCoveragePeriod.monthly:
        return 30;
    }
  }

  ExpenseModel copyWith({
    String? id,
    String? title,
    String? category,
    double? amount,
    DateTime? date,
    String? paymentMethod,
    String? note,
    bool clearNote = false,
    ExpenseType? expenseType,
    ExpenseSource? source,
    ExpenseMovementType? movementType,
    ExpenseCoveragePeriod? coveragePeriod,
    String? aiInsight,
    bool clearAiInsight = false,
    double? confidence,
    bool clearConfidence = false,
    DateTime? createdAt,
  }) {
    return ExpenseModel(
      id: id ?? this.id,
      title: title ?? this.title,
      category: category ?? this.category,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      paymentMethod:
          paymentMethod ?? this.paymentMethod,
      note: clearNote
          ? null
          : note ?? this.note,
      expenseType:
          expenseType ?? this.expenseType,
      source: source ?? this.source,
      movementType:
          movementType ?? this.movementType,
      coveragePeriod:
          coveragePeriod ?? this.coveragePeriod,
      aiInsight: clearAiInsight
          ? null
          : aiInsight ?? this.aiInsight,
      confidence: clearConfidence
          ? null
          : confidence ?? this.confidence,
      createdAt:
          createdAt ?? this.createdAt,
    );
  }

  factory ExpenseModel.fromJson(
    Map<String, dynamic> json,
  ) {
    return ExpenseModel(
      id: json['id']?.toString() ?? '',
      title:
          json['description']?.toString() ?? json['title']?.toString() ?? '',
      category:
          json['category']?.toString() ??
              'other',
      amount: _toDouble(
        json['amount'],
      ),
      date: DateTime.tryParse(
            json['date']?.toString() ?? '',
          ) ??
          DateTime.now(),
      paymentMethod:
          json['paymentMethod']
                  ?.toString() ?? json['payment_method']?.toString() ??
              'cash',
      note: json['note']?.toString(),
      expenseType:
          _expenseTypeFromString(
        json['bucket']?.toString() ?? json['expense_type']?.toString(),
      ),
      source:
          _expenseSourceFromString(
        json['sourceType']?.toString() ?? json['source']?.toString(),
      ),
      movementType:
          _movementTypeFromString(
        json['movement_type']?.toString(),
      ),
      coveragePeriod:
          _coveragePeriodFromString(
        json['coverage_period']
            ?.toString(),
      ),
      aiInsight:
          json['ai_insight']?.toString(),
      confidence:
          json['confidence'] == null
              ? null
              : _toDouble(
                  json['confidence'],
                ),
      createdAt: DateTime.tryParse(
            json['created_at']
                    ?.toString() ??
                '',
          ) ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      'description': title,
      'category': category,
      'amount': amount,
      'date': date.toIso8601String(),
      'paymentMethod': paymentMethod,
      'bucket': expenseType == ExpenseType.want ? 'wants' : 'needs',
      'sourceType': source.name,
      'movement_type':
          movementType.name,
      'coverage_period':
          coveragePeriod.name,
      if (note != null) 'note': note,
      if (aiInsight != null) 'ai_insight': aiInsight,
      if (confidence != null) 'confidence': confidence,
      'created_at':
          createdAt.toIso8601String(),
    };
  }

  static double _toDouble(
    dynamic value,
  ) {
    if (value == null) return 0.0;
    if (value is num) {
      return value.toDouble();
    }
    final parsed = double.tryParse(value.toString());
    if (parsed != null) return parsed;
    // Handle cases where string might have commas or invalid chars
    final cleanString = value.toString().replaceAll(RegExp(r'[^0-9.-]'), '');
    return double.tryParse(cleanString) ?? 0.0;
  }

  static ExpenseType
      _expenseTypeFromString(
    String? value,
  ) {
    final lower = value?.toLowerCase();
    switch (lower) {
      case 'wants':
      case 'want':
        return ExpenseType.want;

      case 'needs':
      case 'need':
      default:
        return ExpenseType.need;
    }
  }

  static ExpenseSource
      _expenseSourceFromString(
    String? value,
  ) {
    switch (value) {
      case 'receipt':
        return ExpenseSource.receipt;

      case 'voice':
        return ExpenseSource.voice;

      case 'bank':
        return ExpenseSource.bank;

      case 'manual':
      default:
        return ExpenseSource.manual;
    }
  }

  static ExpenseMovementType
      _movementTypeFromString(
    String? value,
  ) {
    switch (value) {
      case 'recurring':
        return ExpenseMovementType.recurring;

      case 'occasional':
      default:
        return ExpenseMovementType.occasional;
    }
  }

  static ExpenseCoveragePeriod
      _coveragePeriodFromString(
    String? value,
  ) {
    switch (value) {
      case 'threeDays':
        return ExpenseCoveragePeriod.threeDays;

      case 'oneWeek':
        return ExpenseCoveragePeriod.oneWeek;

      case 'twoWeeks':
        return ExpenseCoveragePeriod.twoWeeks;

      case 'monthly':
        return ExpenseCoveragePeriod.monthly;

      case 'oneDay':
      default:
        return ExpenseCoveragePeriod.oneDay;
    }
  }
}