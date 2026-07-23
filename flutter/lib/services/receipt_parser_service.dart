import 'package:alpha_app/models/parsed_receipt_model.dart';
import 'package:alpha_app/services/api_service.dart';

class ReceiptParserService {
  Future<ParsedReceiptModel> analyzeImage({
    required String filePath,
  }) async {
    final response = await ApiService.uploadFile(
      '/receipts/analyze',
      fileField: 'receipt',
      filePath: filePath,
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final body = await ApiService.parseJson(response);
      final data = body['data'];

      if (data == null) {
        throw Exception('No data returned from OCR backend');
      }

      // Map backend response to local model
      final List<dynamic> rawItems = data['items'] ?? [];

      return ParsedReceiptModel(
        storeName: data['storeName']?.toString() ??
            data['merchantName']?.toString() ??
            'Unknown Store',
        date:
            DateTime.tryParse(data['date']?.toString() ?? '') ?? DateTime.now(),
        suggestedCategory: data['category']?.toString() ?? 'Shopping',
        confidence: (data['confidence'] ?? 0.9).toDouble(),
        inputType: ReceiptInputType.image,
        extractedText:
            data['rawText']?.toString() ?? 'Extracted via Backend OCR',
        items: rawItems.map((item) {
          final map = Map<String, dynamic>.from(item);
          return ReceiptItemModel(
            id: map['id']?.toString() ??
                DateTime.now().microsecondsSinceEpoch.toString(),
            name: map['description']?.toString() ??
                map['name']?.toString() ??
                'Item',
            category: map['category']?.toString() ?? 'Other',
            amount: (map['amount'] ?? map['price'] ?? 0).toDouble(),
          );
        }).toList(),
        total: (data['totalAmount'] ?? data['total'] ?? 0).toDouble(),
      );
    } else {
      final error = await ApiService.getErrorMessage(response);
      throw Exception(error);
    }
  }

  Future<ParsedReceiptModel> parseText({
    required String text,
    required ReceiptInputType inputType,
  }) async {
    await Future.delayed(
      const Duration(seconds: 1),
    );

    if (text.trim().isEmpty) {
      throw Exception(
        'No readable receipt information was found',
      );
    }

    // بيانات مؤقتة إلى أن يتم ربط AI أو Backend.
    return ParsedReceiptModel(
      storeName: inputType == ReceiptInputType.voice
          ? 'Voice Expense'
          : 'National Supermarket',
      date: DateTime.now(),
      suggestedCategory: 'Shopping',
      confidence: inputType == ReceiptInputType.image ? 0.97 : 0.92,
      inputType: inputType,
      extractedText: text,
      items: const [
        ReceiptItemModel(
          id: 'item_1',
          name: 'Fruits & vegetables',
          category: 'Groceries',
          amount: 8.200,
        ),
        ReceiptItemModel(
          id: 'item_2',
          name: 'Dairy products',
          category: 'Groceries',
          amount: 5.750,
        ),
        ReceiptItemModel(
          id: 'item_3',
          name: 'Other',
          category: 'Shopping',
          amount: 4.550,
        ),
      ],
      total: 18.500,
    );
  }
}
