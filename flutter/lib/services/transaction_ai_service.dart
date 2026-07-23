import 'dart:io';
import 'package:alpha_app/services/api_service.dart';
import 'package:alpha_app/models/transaction_draft_model.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:alpha_app/services/api_exception.dart';
import 'package:http_parser/http_parser.dart';

class TransactionAiService {
  TransactionAiService._();

  static Future<TransactionAnalysisResult?> analyzeVoice(
      String audioFilePath) async {
    try {
      final response = await ApiService.uploadFile(
        '/voice/parse',
        fileField: 'audio',
        filePath: audioFilePath,
        contentType: MediaType('audio', 'mp4'),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('VOICE statusCode=${response.statusCode}');
        debugPrint('VOICE rawBodyType=${response.body.runtimeType}');

        final result = TransactionAnalysisResult.parse(response.body);
        return result;
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        throw ApiException(
          statusCode: response.statusCode,
          message: 'Authentication failed. Please log in again.',
          code: 'UNAUTHORIZED',
        );
      } else if (response.statusCode == 413) {
        throw ApiException(
          statusCode: response.statusCode,
          message:
              'The voice recording is too large. Please record a shorter message.',
          code: 'VOICE_FILE_TOO_LARGE',
        );
      } else if (response.statusCode == 415) {
        throw ApiException(
          statusCode: response.statusCode,
          message: 'The audio format is not supported.',
          code: 'UNSUPPORTED_AUDIO_FORMAT',
        );
      } else if (response.statusCode == 502) {
        throw ApiException(
          statusCode: response.statusCode,
          message: 'The voice analysis response could not be processed.',
          code: 'VOICE_ANALYSIS_INVALID_RESPONSE',
        );
      } else {
        throw ApiException(
          statusCode: response.statusCode,
          message: 'Unable to analyze the voice recording. Please try again.',
          code: 'SERVER_ERROR',
        );
      }
    } on ApiException {
      rethrow;
    } catch (e) {
      if (e.toString().contains('SocketException') ||
          e.toString().contains('TimeoutException')) {
        throw ApiException(
          message:
              'Unable to connect to the server. Check your connection and try again.',
          code: 'NETWORK_ERROR',
        );
      }
      throw ApiException(
        message: 'The voice analysis response could not be processed.',
        code: 'PARSE_ERROR',
      );
    }
  }

  static Future<TransactionAnalysisResult?> analyzeReceipt(
      String imagePath) async {
    try {
      final response = await ApiService.uploadFile(
        '/receipts/analyze',
        fileField: 'receipt',
        filePath: imagePath,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('RECEIPT statusCode=${response.statusCode}');
        debugPrint('RECEIPT contentType=${response.headers['content-type']}');
        debugPrint('RECEIPT bodyType=${response.body.runtimeType}');
        debugPrint('RECEIPT bodyLength=${response.body.toString().length}');

        final safeLength = response.body.toString().length;
        final previewLength = safeLength > 150 ? 150 : safeLength;
        debugPrint(
            'RECEIPT bodyPreview=${response.body.toString().substring(0, previewLength)}');

        try {
          final decoded = normalizeJsonValue(response.body);
          debugPrint('RECEIPT decodedType=${decoded.runtimeType}');

          if (decoded is Map) {
            debugPrint('RECEIPT rootKeys=${decoded.keys.toList()}');
            if (decoded.containsKey('data')) {
              debugPrint('RECEIPT dataType=${decoded['data'].runtimeType}');
            }
            if (decoded.containsKey('output')) {
              debugPrint('RECEIPT outputType=${decoded['output'].runtimeType}');
            }
          }

          final result = TransactionAnalysisResult.parse(decoded);

          debugPrint('RECEIPT selectedShape=determined_in_parse');
          debugPrint('RECEIPT transactionCount=${result.transactions.length}');
          return result;
        } catch (e, stack) {
          debugPrint('RECEIPT parseErrorType=${e.runtimeType}');
          debugPrint(
              'RECEIPT parseErrorLocation=${stack.toString().split('\n').first}');
          debugPrint('RECEIPT parseError=$e');
          throw ApiException(
            message: 'The receipt analysis response could not be processed.',
            code: 'CONTRACT_ERROR',
          );
        }
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        throw ApiException(
          statusCode: response.statusCode,
          message: 'Authentication failed. Please log in again.',
          code: 'UNAUTHORIZED',
        );
      } else {
        throw ApiException(
          statusCode: response.statusCode,
          message: 'Unable to analyze the receipt. Please try again.',
          code: 'SERVER_ERROR',
        );
      }
    } on ApiException {
      rethrow;
    } catch (e) {
      if (e.toString().contains('SocketException') ||
          e.toString().contains('TimeoutException')) {
        throw ApiException(
          message:
              'Unable to connect to the server. Check your connection and try again.',
          code: 'NETWORK_ERROR',
        );
      }
      throw ApiException(
        message: 'The receipt analysis response could not be processed.',
        code: 'PARSE_ERROR',
      );
    }
  }
}
