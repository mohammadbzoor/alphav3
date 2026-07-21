class IncomeModel {
  final String id;
  final double amount;
  final String source;
  final String description;
  final DateTime incomeDate;
  final bool isRecurring;
  final DateTime createdAt;

  const IncomeModel({
    required this.id,
    required this.amount,
    required this.source,
    required this.description,
    required this.incomeDate,
    required this.isRecurring,
    required this.createdAt,
  });

  factory IncomeModel.fromJson(Map<String, dynamic> json) {
    return IncomeModel(
      id: json['id']?.toString() ?? '',
      amount: _toDouble(json['amount']),
      source: json['source']?.toString() ?? 'other',
      description: json['description']?.toString() ?? '',
      incomeDate: DateTime.tryParse(json['incomeDate']?.toString() ?? '') ?? DateTime.now(),
      isRecurring: json['isRecurring'] == true || json['isRecurring']?.toString() == 'true',
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'amount': amount,
      'source': source,
      'description': description,
      'incomeDate': incomeDate.toIso8601String(),
      'isRecurring': isRecurring,
    };
  }

  static double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0.0;
  }
}
