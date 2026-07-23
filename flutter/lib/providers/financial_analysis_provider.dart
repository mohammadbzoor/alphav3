import 'dart:async';

import 'package:alpha_app/models/financial_analysis_model.dart';
import 'package:alpha_app/services/api_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

class FinancialAnalysisProvider extends ChangeNotifier {
  FinancialAnalysisProvider() {
    Future.microtask(loadHistory);
    _listenToAudioPlayer();
  }

  final AudioPlayer _audioPlayer = AudioPlayer();

  StreamSubscription<PlayerState>? _playerStateSubscription;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration?>? _durationSubscription;

  FinancialAnalysisModel? _analysis;
  FinancialAnalysisModel? get analysis => _analysis;

  List<FinancialAnalysisListItem> _history = const [];
  List<FinancialAnalysisListItem> get history => _history;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _isHistoryLoading = false;
  bool get isHistoryLoading => _isHistoryLoading;

  bool _isGenerating = false;
  bool get isGenerating => _isGenerating;

  bool _isAudioLoading = false;
  bool get isAudioLoading => _isAudioLoading;

  bool _isPlaying = false;
  bool get isPlaying => _isPlaying;

  Duration _position = Duration.zero;
  Duration get position => _position;

  Duration _duration = Duration.zero;
  Duration get duration => _duration;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  String? _loadedAudioUrl;
  Future<bool>? _audioPreparationFuture;
  bool _disposed = false;

  bool get hasAnalysis => _analysis != null;
  bool get hasAudio => _analysis?.audio.hasAudio == true;

  double get audioProgress {
    if (_duration.inMilliseconds <= 0) return 0;
    return (_position.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0);
  }

  void _listenToAudioPlayer() {
    _playerStateSubscription ??= _audioPlayer.playerStateStream.listen(
      (state) async {
        _isPlaying = state.playing;
        if (state.processingState == ProcessingState.completed) {
          _isPlaying = false;
          _position = Duration.zero;
          try {
            await _audioPlayer.seek(Duration.zero);
          } catch (_) {}
        }
        _safeNotify();
      },
      onError: (_) {
        _errorMessage = 'تعذر تشغيل الصوت.';
        _safeNotify();
      },
    );

    _positionSubscription ??= _audioPlayer.positionStream.listen((value) {
      _position = value;
      _safeNotify();
    });

    _durationSubscription ??= _audioPlayer.durationStream.listen((value) {
      if (value == null) return;
      _duration = value;
      _safeNotify();
    });
  }

  Future<void> loadHistory() async {
    _isHistoryLoading = true;
    _errorMessage = null;
    _safeNotify();

    try {
      final response = await ApiService.get('/financial-analysis', queryParameters: {
        'page': '1',
        'limit': '20',
      });
      if (!ApiService.isSuccess(response)) {
        _errorMessage = 'تعذر تحميل التحليلات السابقة.';
        return;
      }

      final decoded = ApiService.decodeResponse(response);
      final data = decoded['data'];
      final items = data is Map ? data['items'] : null;
      _history = items is List
          ? items
              .whereType<Map>()
              .map((item) => FinancialAnalysisListItem.fromJson(Map<String, dynamic>.from(item)))
              .toList()
          : const [];
    } catch (error) {
      _errorMessage = 'تعذر تحميل التحليلات السابقة.';
      debugPrint('Analysis history error: ${_cleanError(error)}');
    } finally {
      _isHistoryLoading = false;
      _safeNotify();
    }
  }

  Future<bool> generateAnalysis() async {
    if (_isGenerating) return false;

    _isGenerating = true;
    _errorMessage = null;
    _safeNotify();

    try {
      final response = await ApiService.post('/financial-analysis', body: const {
        'mode': 'financial_snapshot',
        'language': 'ar',
        'includeSpeechText': true,
        'maxInsights': 3,
        'maxRecommendations': 3,
      });

      if (!ApiService.isSuccess(response)) {
        _errorMessage = 'تعذر إنشاء التحليل الآن. حاول لاحقاً.';
        debugPrint('Analysis generation failed: ${await ApiService.getErrorMessage(response)}');
        return false;
      }

      final decoded = ApiService.decodeResponse(response);
      var rawAnalysis = decoded['analysis'];
      if (rawAnalysis is List && rawAnalysis.isNotEmpty) {
        rawAnalysis = rawAnalysis.first;
      }
      if (rawAnalysis is! Map) {
        throw const FormatException('Invalid analysis response');
      }

      final ok = await setAnalysisFromJson(Map<String, dynamic>.from(rawAnalysis));
      if (ok) await loadHistory();
      return ok;
    } catch (error) {
      _errorMessage = 'تعذر إنشاء التحليل الآن. حاول لاحقاً.';
      debugPrint('Analysis generation error: ${_cleanError(error)}');
      return false;
    } finally {
      _isGenerating = false;
      _safeNotify();
    }
  }

  Future<bool> loadAnalysisDetail(int id) async {
    _isLoading = true;
    _errorMessage = null;
    _safeNotify();

    try {
      final response = await ApiService.get('/financial-analysis/$id');
      if (!ApiService.isSuccess(response)) {
        _errorMessage = 'تعذر فتح التحليل المحفوظ.';
        debugPrint('Analysis detail failed: ${await ApiService.getErrorMessage(response)}');
        return false;
      }

      final decoded = ApiService.decodeResponse(response);
      final rawAnalysis = decoded['analysis'];
      if (rawAnalysis is! Map) {
        throw const FormatException('Invalid analysis detail response');
      }
      return setAnalysisFromJson(Map<String, dynamic>.from(rawAnalysis));
    } catch (error) {
      _errorMessage = 'تعذر فتح التحليل المحفوظ.';
      debugPrint('Analysis detail error: ${_cleanError(error)}');
      return false;
    } finally {
      _isLoading = false;
      _safeNotify();
    }
  }

  Future<bool> setAnalysisFromJson(Map<String, dynamic> json) async {
    final newAnalysis = FinancialAnalysisModel.fromJson(json);
    final oldUrl = _analysis?.audio.url?.trim();
    final newUrl = newAnalysis.audio.url?.trim();
    _analysis = newAnalysis;
    if (oldUrl != newUrl) {
      await _resetAudioPlayer();
    }
    _errorMessage = null;
    _safeNotify();
    return true;
  }

  Future<bool> fetchAnalysis() => generateAnalysis();

  Future<bool> _ensureAudioPrepared() {
    final currentPreparation = _audioPreparationFuture;
    if (currentPreparation != null) return currentPreparation;

    final future = _prepareAudioOnce();
    _audioPreparationFuture = future;
    future.whenComplete(() => _audioPreparationFuture = null);
    return future;
  }

  Future<bool> _prepareAudioOnce() async {
    final url = _analysis?.audio.url?.trim() ?? '';
    if (url.isEmpty) {
      _errorMessage = 'الصوت غير متاح.';
      _safeNotify();
      return false;
    }

    if (_loadedAudioUrl == url && _audioPlayer.processingState != ProcessingState.idle) {
      _errorMessage = null;
      return true;
    }

    _isAudioLoading = true;
    _errorMessage = null;
    _safeNotify();

    try {
      final loadedDuration = await _audioPlayer.setUrl(url);
      _loadedAudioUrl = url;
      _duration = loadedDuration ??
          _audioPlayer.duration ??
          Duration(milliseconds: ((_analysis?.audio.duration ?? 0) * 1000).round());
      _position = Duration.zero;
      return true;
    } catch (error) {
      _errorMessage = 'تعذر تحميل الصوت.';
      debugPrint('Analysis audio error: ${_cleanError(error)}');
      return false;
    } finally {
      _isAudioLoading = false;
      _safeNotify();
    }
  }

  Future<void> _resetAudioPlayer() async {
    try {
      await _audioPlayer.stop();
    } catch (_) {}
    _audioPreparationFuture = null;
    _loadedAudioUrl = null;
    _duration = Duration.zero;
    _position = Duration.zero;
    _isPlaying = false;
    _isAudioLoading = false;
  }

  Future<void> toggleAudio() async {
    if (!hasAudio || _isAudioLoading) return;
    try {
      if (_audioPlayer.playing) {
        await _audioPlayer.pause();
        return;
      }
      final prepared = await _ensureAudioPrepared();
      if (!prepared) return;
      if (_audioPlayer.processingState == ProcessingState.completed) {
        await _audioPlayer.seek(Duration.zero);
      }
      await _audioPlayer.play();
    } catch (error) {
      _errorMessage = 'تعذر تشغيل الصوت.';
      debugPrint('Analysis play error: ${_cleanError(error)}');
      _safeNotify();
    }
  }

  Future<void> replayAudio() async {
    if (!hasAudio || _isAudioLoading) return;
    final prepared = await _ensureAudioPrepared();
    if (!prepared) return;
    await _audioPlayer.seek(Duration.zero);
    await _audioPlayer.play();
  }

  Future<void> seekAudio(double value) async {
    if (!hasAudio || _duration.inMilliseconds <= 0) return;
    final prepared = await _ensureAudioPrepared();
    if (!prepared) return;
    final safeValue = value.clamp(0.0, 1.0);
    await _audioPlayer.seek(Duration(milliseconds: (_duration.inMilliseconds * safeValue).round()));
  }

  Future<void> stopAudio() async {
    try {
      if (_audioPlayer.playing) await _audioPlayer.pause();
      await _audioPlayer.seek(Duration.zero);
    } catch (_) {}
    _position = Duration.zero;
    _isPlaying = false;
    _safeNotify();
  }

  Future<void> clearAnalysis() async {
    await _resetAudioPlayer();
    _analysis = null;
    _errorMessage = null;
    _safeNotify();
  }

  void clearError() {
    _errorMessage = null;
    _safeNotify();
  }

  String formatDuration(Duration value) {
    final minutes = value.inMinutes;
    final seconds = value.inSeconds.remainder(60);
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String get analysisTitleDate {
    final date = _analysis?.metadata.analysisAsOfDate ?? _analysis?.metadata.generatedAt;
    if (date == null) return '';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  String _cleanError(Object error) => error.toString().replaceFirst('Exception: ', '');

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _playerStateSubscription?.cancel();
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }
}
