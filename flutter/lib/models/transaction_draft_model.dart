import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:alpha_app/core/utils/finance_mappings.dart';

class ReceiptAnalysisContractException implements Exception {
  final String message;
  ReceiptAnalysisContractException(this.message);

  @override
  String toString() => message;
}

dynamic normalizeJsonValue(dynamic value) {
  if (value is List) return value;
  if (value is Map) return value;
  if (value is String) {
    String trimmed = value.trim();
    // Remove UTF-8 BOM if present
    if (trimmed.startsWith('\ufeff')) {
      trimmed = trimmed.substring(1).trim();
    }
    // Remove markdown fence
    if (trimmed.startsWith('```')) {
      final firstNewline = trimmed.indexOf('\n');
      final lastBackticks = trimmed.lastIndexOf('```');
      if (firstNewline != -1 && lastBackticks > firstNewline) {
        trimmed = trimmed.substring(firstNewline + 1, lastBackticks).trim();
      }
    }

    dynamic decoded;
    try {
      decoded = jsonDecode(trimmed);
    } catch (e) {
      throw ReceiptAnalysisContractException('JSON decoding failed: $e');
    }

    // Decode one more level if it's still a JSON string
    if (decoded is String) {
      final subTrimmed = decoded.trim();
      if (subTrimmed.startsWith('[') || subTrimmed.startsWith('{')) {
        try {
          return jsonDecode(subTrimmed);
        } catch (_) {
          return decoded;
        }
      }
    }
    return decoded;
  }
  throw ReceiptAnalysisContractException('Unsupported value type for decoding');
}

class TransactionAnalysisResult {
  final String? sourceType;
  final List<TransactionDraft> transactions;
  final int transactionCount;
  final bool requiresReview;

  TransactionAnalysisResult({
    this.sourceType,
    this.transactions = const [],
    this.transactionCount = 0,
    this.requiresReview = true,
  });

  static bool isBackendEnvelope(Map<dynamic, dynamic> value) {
    if (value.containsKey('amount')) {
      final amt = value['amount'];
      if (amt != null) {
        final parsed = double.tryParse(amt.toString());
        if (parsed != null && parsed >= 0) return false;
      }
    }
    if (value.containsKey('success') ||
        value.containsKey('data') ||
        value.containsKey('meta') ||
        value.containsKey('message')) {
      return true;
    }
    return false;
  }

  static bool isTransactionCandidate(Map<dynamic, dynamic> value) {
    if (!value.containsKey('amount')) return false;
    final amt = value['amount'];
    if (amt == null) return false;
    final parsed = double.tryParse(amt.toString());
    if (parsed == null || parsed < 0) return false;

    if (value.containsKey('transactionType') ||
        value.containsKey('category') ||
        value.containsKey('description') ||
        value.containsKey('date') ||
        value.containsKey('confidence') ||
        value.containsKey('bucket') ||
        value.containsKey('paymentMethod') ||
        value.containsKey('sourceType')) {
      return true;
    }
    return false;
  }

  static TransactionAnalysisResult parse(dynamic raw) {
    if (raw == null) {
      throw ReceiptAnalysisContractException('Response is empty');
    }

    final decoded = normalizeJsonValue(raw);

    debugPrint('VOICE decodedType=${decoded.runtimeType}');

    List<dynamic>? rawList;
    String? parentSourceType;
    int? metaCount;
    bool requiresReview = true;

    dynamic root = decoded;

    debugPrint('VOICE rootIsList=${root is List}');
    if (root is List) {
      debugPrint('VOICE rootListLength=${root.length}');
      if (root.isNotEmpty) {
        debugPrint('VOICE firstItemType=${root.first.runtimeType}');
        if (root.first is Map) {
          debugPrint(
              'VOICE firstItemKeys=${(root.first as Map).keys.toList()}');
        }
      }
    }

    if (root is List &&
        root.length == 1 &&
        root.first is Map &&
        isBackendEnvelope(root.first as Map<dynamic, dynamic>)) {
      debugPrint('VOICE envelopeDetected=true');
      root = root.first;
    } else if (root is List &&
        root.isNotEmpty &&
        root.every(
            (e) => e is Map && isBackendEnvelope(e as Map<dynamic, dynamic>))) {
      debugPrint('VOICE envelopeDetected=true (multiple)');
      rawList = [];
      for (var env in root) {
        if (env['data'] is Map && env['data']['transactions'] is List) {
          rawList.addAll(env['data']['transactions']);
          if (parentSourceType == null) {
            parentSourceType = env['data']['sourceType']?.toString();
          }
        }
      }
      root = null;
    } else if (root is List) {
      debugPrint('VOICE envelopeDetected=false');
      rawList = root;
      root = null;
    }

    if (root is Map) {
      final map = root as Map<String, dynamic>;

      dynamic data = map['data'];
      dynamic output = map['output'];
      dynamic result = map['result'];

      if (map.containsKey('meta') && map['meta'] is Map) {
        metaCount = map['meta']['transactionCount'] as int?;
        if (map['meta'].containsKey('requiresReview')) {
          requiresReview = map['meta']['requiresReview'] == true;
        }
      }

      if (data is String) {
        try {
          data = normalizeJsonValue(data);
        } catch (_) {}
      }
      if (output is String) {
        try {
          output = normalizeJsonValue(output);
        } catch (_) {}
      }
      if (result is String) {
        try {
          result = normalizeJsonValue(result);
        } catch (_) {}
      }

      if (data is Map &&
          data.containsKey('transactions') &&
          data['transactions'] is List) {
        rawList = data['transactions'];
        parentSourceType = data['sourceType']?.toString();
      } else if (map.containsKey('transactions') &&
          map['transactions'] is List) {
        rawList = map['transactions'];
        parentSourceType = map['sourceType']?.toString();
      } else if (data is List) {
        rawList = data;
      } else if (output is List) {
        rawList = output;
      } else if (result is List) {
        rawList = result;
      } else if (isTransactionCandidate(map)) {
        rawList = [map];
      }
    }

    if (rawList == null) {
      throw ReceiptAnalysisContractException(
          'Unsupported response shape or missing transactions array');
    }

    if (rawList.isEmpty) {
      throw ReceiptAnalysisContractException(
          'No transactions found in response');
    }

    List<TransactionDraft> parsedTransactions = [];
    for (var item in rawList) {
      if (item is! Map) {
        throw ReceiptAnalysisContractException(
            'Invalid transaction element format');
      }

      if (isBackendEnvelope(item as Map<dynamic, dynamic>)) {
        continue;
      }

      // Handle snake_case or aliases
      final mapItem = Map<String, dynamic>.from(item);
      if (!mapItem.containsKey('paymentMethod') &&
          mapItem.containsKey('payment_method')) {
        mapItem['paymentMethod'] = mapItem['payment_method'];
      }
      if (!mapItem.containsKey('date') &&
          mapItem.containsKey('transactionDate')) {
        mapItem['date'] = mapItem['transactionDate'];
      } else if (!mapItem.containsKey('date') &&
          mapItem.containsKey('transaction_date')) {
        mapItem['date'] = mapItem['transaction_date'];
      }
      if (!mapItem.containsKey('sourceType') &&
          mapItem.containsKey('source_type')) {
        mapItem['sourceType'] = mapItem['source_type'];
      }
      if (!mapItem.containsKey('transactionType') &&
          mapItem.containsKey('transaction_type')) {
        mapItem['transactionType'] = mapItem['transaction_type'];
      }

      final draft = TransactionDraft.fromJson(mapItem);
      if (draft.sourceType == null) {
        draft.sourceType = parentSourceType;
      }
      parsedTransactions.add(draft);
    }

    // Default sourceType for Shape A from first item
    if (parentSourceType == null && parsedTransactions.isNotEmpty) {
      parentSourceType = parsedTransactions.first.sourceType;
    }

    debugPrint('VOICE transactionCount=${parsedTransactions.length}');
    return TransactionAnalysisResult(
      sourceType: parentSourceType,
      transactions: parsedTransactions,
      transactionCount: parsedTransactions.length,
      requiresReview: requiresReview,
    );
  }
}

class TransactionDraft {
  String? transactionType;
  double? amount;
  String? currency;
  String? category;
  String? description;
  String? merchant;
  DateTime? transactionDate;
  double? confidence;
  List<String>? uncertainFields;
  String? flexibility;
  String? sourceType;
  String? bucket;
  String? paymentMethod;
  String? movementType;
  String? frequency;

  TransactionDraft({
    this.transactionType,
    this.amount,
    this.currency,
    this.category,
    this.description,
    this.merchant,
    this.transactionDate,
    this.confidence,
    this.uncertainFields,
    this.flexibility,
    this.sourceType,
    this.bucket,
    this.paymentMethod,
    this.movementType,
    this.frequency,
  });

  factory TransactionDraft.fromJson(Map<String, dynamic> json) {
    double? parsedAmount;
    if (json['amount'] != null) {
      final val = double.tryParse(json['amount'].toString());
      if (val != null && !val.isNaN && !val.isInfinite && val >= 0) {
        parsedAmount = val;
      }
    }

    double? parsedConfidence;
    if (json['confidence'] != null) {
      final val = double.tryParse(json['confidence'].toString());
      if (val != null && !val.isNaN && !val.isInfinite) {
        if (val >= 0 && val <= 1) {
          parsedConfidence = val * 100;
        } else if (val > 1 && val <= 100) {
          parsedConfidence = val;
        }
      }
    }

    List<String> uncertain = [];
    if (json['uncertainFields'] != null) {
      uncertain = List<String>.from(json['uncertainFields']);
    }

    String? pm = json['paymentMethod']?.toString();
    if (pm == 'other') {
      pm = null;
      if (!uncertain.contains('paymentMethod')) uncertain.add('paymentMethod');
    }

    String? c = json['category']?.toString();
    if (c != null) {
      if (c.toLowerCase() == 'restaurants') {
        c = 'restaurant';
      }
    }
    if (c == null && !uncertain.contains('category')) uncertain.add('category');

    String? b = json['bucket']?.toString();
    if (b == null && c != null) {
      if (FinanceMappings.isNeedsCategory(c)) {
        b = 'needs';
      } else if (FinanceMappings.isWantsCategory(c)) {
        b = 'wants';
      }
    }
    if (b == null && !uncertain.contains('bucket')) uncertain.add('bucket');

    String? tt = json['transactionType']?.toString();
    if (tt == null && !uncertain.contains('transactionType'))
      uncertain.add('transactionType');

    return TransactionDraft(
      transactionType: tt,
      amount: parsedAmount,
      currency: json['currency']?.toString(),
      category: c,
      description: json['description']?.toString(),
      merchant: json['merchant']?.toString(),
      transactionDate: json['date'] != null
          ? DateTime.tryParse(json['date'].toString())
          : null,
      confidence: parsedConfidence,
      uncertainFields: uncertain,
      flexibility: json['flexibility']?.toString(),
      sourceType: json['sourceType']?.toString(),
      bucket: b,
      paymentMethod: pm,
      movementType: json['movementType']?.toString(),
      frequency: json['frequency']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'transactionType': transactionType,
      'amount': amount,
      'currency': currency,
      'category': category,
      'description': description,
      'merchant': merchant,
      'date': transactionDate?.toIso8601String(),
      'confidence': confidence,
      'uncertainFields': uncertainFields,
      'flexibility': flexibility,
      'sourceType': sourceType,
      'bucket': bucket,
      'paymentMethod': paymentMethod,
      'movementType': movementType,
      'frequency': frequency,
    };
  }
}
