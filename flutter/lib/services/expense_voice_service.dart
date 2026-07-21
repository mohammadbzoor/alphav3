import 'package:speech_to_text/speech_to_text.dart';

class ExpenseVoiceService {
  final SpeechToText _speechToText = SpeechToText();

  bool _isInitialized = false;

  String _savedText = '';
  String _currentSessionText = '';

  void Function(String text)? _onResultCallback;
  void Function(String status)? _onStatusCallback;
  void Function(String error)? _onErrorCallback;

  bool get isListening => _speechToText.isListening;

  Future<bool> initialize() async {
    if (_isInitialized) {
      return true;
    }

    _isInitialized = await _speechToText.initialize(
      onStatus: (status) {
        _onStatusCallback?.call(status);
      },
      onError: (error) {
        _onErrorCallback?.call(error.errorMsg);
      },
    );

    return _isInitialized;
  }

  Future<void> startListening({
    required String localeId,
    required void Function(String text) onResult,
    void Function(String status)? onStatus,
    void Function(String error)? onError,
    String existingText = '',
  }) async {
    final available = await initialize();

    if (!available) {
      onError?.call(
        'Speech recognition is unavailable',
      );
      return;
    }

    if (_speechToText.isListening) {
      return;
    }

    _onResultCallback = onResult;
    _onStatusCallback = onStatus;
    _onErrorCallback = onError;

    _savedText = existingText.trim();
    _currentSessionText = '';

    await _speechToText.listen(
      localeId: localeId,
      partialResults: true,
      listenMode: ListenMode.dictation,
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 4),
      cancelOnError: false,
      onResult: (result) {
        _currentSessionText =
            result.recognizedWords.trim();

        final combined = [
          if (_savedText.isNotEmpty) _savedText,
          if (_currentSessionText.isNotEmpty)
            _currentSessionText,
        ].join(' ').trim();

        _onResultCallback?.call(combined);

        if (result.finalResult) {
          _savedText = combined;
          _currentSessionText = '';
        }
      },
    );
  }

  Future<String> stopListening() async {
    if (_speechToText.isListening) {
      await _speechToText.stop();
    }

    final combined = [
      if (_savedText.trim().isNotEmpty)
        _savedText.trim(),
      if (_currentSessionText.trim().isNotEmpty)
        _currentSessionText.trim(),
    ].join(' ').trim();

    _savedText = combined;
    _currentSessionText = '';

    _onResultCallback?.call(combined);

    return combined;
  }

  Future<void> cancelListening() async {
    if (_speechToText.isListening) {
      await _speechToText.cancel();
    }

    _currentSessionText = '';
  }

  void clearText() {
    _savedText = '';
    _currentSessionText = '';
  }

  Future<void> dispose() async {
    await cancelListening();

    _onResultCallback = null;
    _onStatusCallback = null;
    _onErrorCallback = null;
  }
}