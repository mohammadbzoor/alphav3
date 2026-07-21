enum ReceiptInputType {
  image,
  voice,
}

class ReceiptItemModel {
  final String id;
  final String name;
  final String category;
  final double amount;

  const ReceiptItemModel({
    required this.id,
    required this.name,
    required this.category,
    required this.amount,
  });

  ReceiptItemModel copyWith({
    String? id,
    String? name,
    String? category,
    double? amount,
  }) {
    return ReceiptItemModel(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      amount: amount ?? this.amount,
    );
  }

  factory ReceiptItemModel.fromJson(
    Map<String, dynamic> json,
  ) {
    return ReceiptItemModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      category:
          json['category']?.toString() ?? 'Other',
      amount: double.tryParse(
            json['amount']?.toString() ?? '',
          ) ??
          0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'amount': amount,
    };
  }
}

class ParsedReceiptModel {
  final String? id;
  final String storeName;
  final DateTime date;
  final String suggestedCategory;
  final List<ReceiptItemModel> items;
  final double total;
  final double confidence;
  final ReceiptInputType inputType;
  final String extractedText;

  const ParsedReceiptModel({
    this.id,
    required this.storeName,
    required this.date,
    required this.suggestedCategory,
    required this.items,
    required this.total,
    required this.confidence,
    required this.inputType,
    required this.extractedText,
  });

  ParsedReceiptModel copyWith({
    String? id,
    String? storeName,
    DateTime? date,
    String? suggestedCategory,
    List<ReceiptItemModel>? items,
    double? total,
    double? confidence,
    ReceiptInputType? inputType,
    String? extractedText,
  }) {
    return ParsedReceiptModel(
      id: id ?? this.id,
      storeName: storeName ?? this.storeName,
      date: date ?? this.date,
      suggestedCategory:
          suggestedCategory ?? this.suggestedCategory,
      items: items ?? this.items,
      total: total ?? this.total,
      confidence: confidence ?? this.confidence,
      inputType: inputType ?? this.inputType,
      extractedText:
          extractedText ?? this.extractedText,
    );
  }

  factory ParsedReceiptModel.fromJson(
    Map<String, dynamic> json,
  ) {
    final rawItems =
        json['items'] as List<dynamic>? ?? [];

    return ParsedReceiptModel(
      id: json['id']?.toString(),
      storeName:
          json['store_name']?.toString() ?? 'Unknown Store',
      date: DateTime.tryParse(
            json['date']?.toString() ?? '',
          ) ??
          DateTime.now(),
      suggestedCategory:
          json['suggested_category']?.toString() ??
              'Shopping',
      items: rawItems
          .map(
            (item) => ReceiptItemModel.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList(),
      total: double.tryParse(
            json['total']?.toString() ?? '',
          ) ??
          0,
      confidence: double.tryParse(
            json['confidence']?.toString() ?? '',
          ) ??
          0,
      inputType:
          json['input_type'] == 'voice'
              ? ReceiptInputType.voice
              : ReceiptInputType.image,
      extractedText:
          json['extracted_text']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'store_name': storeName,
      'date': date.toIso8601String(),
      'suggested_category': suggestedCategory,
      'items': items
          .map((item) => item.toJson())
          .toList(),
      'total': total,
      'confidence': confidence,
      'input_type': inputType.name,
      'extracted_text': extractedText,
    };
  }
}