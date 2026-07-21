import 'package:alpha_app/models/parsed_receipt_model.dart';
import 'package:alpha_app/services/expense_voice_service.dart';
import 'package:alpha_app/services/receipt_ocr_service.dart';
import 'package:alpha_app/services/receipt_parser_service.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:speech_to_text/speech_to_text.dart';

class ReceiptProvider extends ChangeNotifier {
  final ImagePicker _imagePicker = ImagePicker();

  final ReceiptOcrService _ocrService =
      ReceiptOcrService();

  final ExpenseVoiceService _voiceService =
      ExpenseVoiceService();

  final ReceiptParserService _parserService =
      ReceiptParserService();

  ParsedReceiptModel? _parsedReceipt;

  ParsedReceiptModel? get parsedReceipt =>
      _parsedReceipt;

  XFile? _selectedImage;

  XFile? get selectedImage =>
      _selectedImage;

  bool _isProcessing = false;

  bool get isProcessing =>
      _isProcessing;

  bool _isListening = false;

  bool get isListening =>
      _isListening;

  String _voiceText = '';

  String get voiceText =>
      _voiceText;

  String _selectedVoiceLocale = 'ar_JO';

  String get selectedVoiceLocale =>
      _selectedVoiceLocale;

  String? _errorMessage;

  String? get errorMessage =>
      _errorMessage;

  // =====================================================
  // CAMERA IMAGE
  // =====================================================

  Future<ParsedReceiptModel?> processCapturedImage(
    String imagePath,
  ) async {
    try {
      _startProcessing();

      _parsedReceipt = await _parserService.analyzeImage(
        filePath: imagePath,
      );

      _finishProcessing();

      return _parsedReceipt;
    } catch (error) {
      _setError(
        error.toString(),
      );

      return null;
    }
  }

  // =====================================================
  // GALLERY
  // =====================================================

  Future<ParsedReceiptModel?>
      pickReceiptFromGallery() async {
    try {
      _startProcessing();

      final image =
          await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (image == null) {
        _finishProcessing();

        return null;
      }

      _selectedImage = image;

      _parsedReceipt = await _parserService.analyzeImage(
        filePath: image.path,
      );

      _finishProcessing();

      return _parsedReceipt;
    } catch (error) {
      _setError(
        error.toString(),
      );

      return null;
    }
  }

  // =====================================================
  // VOICE LANGUAGE
  // =====================================================

  void changeVoiceLocale(
    String localeId,
  ) {
    if (_isListening) return;

    _selectedVoiceLocale = localeId;

    notifyListeners();
  }

  // =====================================================
  // VOICE TEXT EDITING
  // =====================================================

  void updateVoiceText(
    String value,
  ) {
    _voiceText = value;

    notifyListeners();
  }

  // =====================================================
  // START VOICE INPUT
  // =====================================================

  Future<void> startVoiceInput() async {
  if (_isListening) return;

  _errorMessage = null;
  _isListening = true;

  notifyListeners();

  await _voiceService.startListening(
    localeId: _selectedVoiceLocale,

    // مهم: يحتفظ بالكلام السابق.
    existingText: _voiceText,

    onResult: (text) {
      _voiceText = text;
      notifyListeners();
    },

    onStatus: (status) {
      debugPrint('Voice status: $status');

      if (status == SpeechToText.doneStatus ||
          status ==
              SpeechToText.notListeningStatus) {
        _isListening = false;
        notifyListeners();
      }
    },

    onError: (error) {
      _errorMessage = error;
      _isListening = false;
      notifyListeners();
    },
  );
}

  // =====================================================
  // STOP VOICE WITHOUT PARSING
  // =====================================================

  Future<void> stopVoiceInput() async {
  final finalText =
      await _voiceService.stopListening();

  if (finalText.trim().isNotEmpty) {
    _voiceText = finalText;
  }

  _isListening = false;

  notifyListeners();
}
  // =====================================================
  // STOP AND PARSE VOICE
  // =====================================================

  Future<ParsedReceiptModel?>
      stopAndParseVoice() async {
    try {
      if (_isListening) {
        await _voiceService.stopListening();
      }

      _isListening = false;

      notifyListeners();

      final text =
          _voiceText.trim();

      if (text.isEmpty) {
        throw Exception(
          'No speech was recognized',
        );
      }

      _startProcessing();

      _parsedReceipt =
          await _parserService.parseText(
        text: text,
        inputType: ReceiptInputType.voice,
      );

      _finishProcessing();

      return _parsedReceipt;
    } catch (error) {
      _setError(
        error.toString(),
      );

      return null;
    }
  }

  // =====================================================
  // PARSE EDITED VOICE TEXT
  // =====================================================

  Future<ParsedReceiptModel?>
      parseEditedVoiceText() async {
    try {
      final text =
          _voiceText.trim();

      if (text.isEmpty) {
        throw Exception(
          'Please enter or record expense details',
        );
      }

      _startProcessing();

      _parsedReceipt =
          await _parserService.parseText(
        text: text,
        inputType: ReceiptInputType.voice,
      );

      _finishProcessing();

      return _parsedReceipt;
    } catch (error) {
      _setError(
        error.toString(),
      );

      return null;
    }
  }

  // =====================================================
  // CANCEL VOICE
  // =====================================================

  Future<void> cancelVoiceInput() async {
    await _voiceService.cancelListening();

    _isListening = false;
    _voiceText = '';

    notifyListeners();
  }

  // =====================================================
  // UPDATE STORE NAME
  // =====================================================

  void updateStoreName(
    String value,
  ) {
    if (_parsedReceipt == null) return;

    _parsedReceipt =
        _parsedReceipt!.copyWith(
      storeName: value,
    );

    notifyListeners();
  }

  // =====================================================
  // UPDATE DATE
  // =====================================================

  void updateDate(
    DateTime value,
  ) {
    if (_parsedReceipt == null) return;

    _parsedReceipt =
        _parsedReceipt!.copyWith(
      date: value,
    );

    notifyListeners();
  }

  // =====================================================
  // UPDATE CATEGORY
  // =====================================================

  void updateCategory(
    String value,
  ) {
    if (_parsedReceipt == null) return;

    _parsedReceipt =
        _parsedReceipt!.copyWith(
      suggestedCategory: value,
    );

    notifyListeners();
  }

  // =====================================================
  // UPDATE ITEM
  // =====================================================

  void updateItem({
    required String itemId,
    String? name,
    String? category,
    double? amount,
  }) {
    if (_parsedReceipt == null) return;

    final updatedItems =
        _parsedReceipt!.items.map(
      (item) {
        if (item.id != itemId) {
          return item;
        }

        return item.copyWith(
          name: name,
          category: category,
          amount: amount,
        );
      },
    ).toList();

    final updatedTotal =
        updatedItems.fold<double>(
      0,
      (
        sum,
        item,
      ) =>
          sum + item.amount,
    );

    _parsedReceipt =
        _parsedReceipt!.copyWith(
      items: updatedItems,
      total: updatedTotal,
    );

    notifyListeners();
  }

  // =====================================================
  // REMOVE ITEM
  // =====================================================

  void removeItem(
    String itemId,
  ) {
    if (_parsedReceipt == null) return;

    final updatedItems =
        _parsedReceipt!.items
            .where(
              (item) =>
                  item.id != itemId,
            )
            .toList();

    final updatedTotal =
        updatedItems.fold<double>(
      0,
      (
        sum,
        item,
      ) =>
          sum + item.amount,
    );

    _parsedReceipt =
        _parsedReceipt!.copyWith(
      items: updatedItems,
      total: updatedTotal,
    );

    notifyListeners();
  }

  // =====================================================
  // ADD ITEM
  // =====================================================

  void addItem(
    ReceiptItemModel item,
  ) {
    if (_parsedReceipt == null) return;

    final updatedItems = [
      ..._parsedReceipt!.items,
      item,
    ];

    final updatedTotal =
        updatedItems.fold<double>(
      0,
      (
        sum,
        currentItem,
      ) =>
          sum + currentItem.amount,
    );

    _parsedReceipt =
        _parsedReceipt!.copyWith(
      items: updatedItems,
      total: updatedTotal,
    );

    notifyListeners();
  }

  // =====================================================
  // CONFIRM RECEIPT
  // =====================================================

  Future<bool> confirmReceipt() async {
    if (_parsedReceipt == null) {
      _setError(
        'No receipt data available',
      );

      return false;
    }

    try {
      _isProcessing = true;
      _errorMessage = null;

      notifyListeners();

      // لاحقًا عند ربط الباك إند:
      //
      // await receiptService.saveReceipt(
      //   _parsedReceipt!,
      // );

      await Future.delayed(
        const Duration(
          seconds: 1,
        ),
      );

      _isProcessing = false;

      notifyListeners();

      return true;
    } catch (error) {
      _setError(
        error.toString(),
      );

      return false;
    }
  }

  // =====================================================
  // CLEAR ERROR
  // =====================================================

  void clearError() {
    _errorMessage = null;

    notifyListeners();
  }

  // =====================================================
  // CLEAR ALL DATA
  // =====================================================

  void clear() {
    _voiceService.cancelListening();

    _parsedReceipt = null;
    _selectedImage = null;

    _voiceText = '';
    _errorMessage = null;

    _isListening = false;
    _isProcessing = false;

    notifyListeners();
  }

  // =====================================================
  // PRIVATE HELPERS
  // =====================================================

  void _startProcessing() {
    _isProcessing = true;
    _errorMessage = null;

    notifyListeners();
  }

  void _finishProcessing() {
    _isProcessing = false;

    notifyListeners();
  }

  void _setError(
    String error,
  ) {
    _errorMessage = error
        .replaceFirst(
          'Exception: ',
          '',
        );

    _isProcessing = false;
    _isListening = false;

    notifyListeners();
  }

  // =====================================================
  // DISPOSE
  // =====================================================

  @override
void dispose() {
  _voiceService.dispose();
  _ocrService.dispose();

  super.dispose();
}
}