import 'dart:async';
import 'dart:convert';

import 'package:alpha_app/models/financial_analysis_model.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FinancialAnalysisProvider extends ChangeNotifier {
  FinancialAnalysisProvider() {
    Future.microtask(_initialize);
  }

  static const String _storageKey =
      'latest_financial_analysis';

  final AudioPlayer _audioPlayer = AudioPlayer();

  StreamSubscription<PlayerState>?
      _playerStateSubscription;

  StreamSubscription<Duration>?
      _positionSubscription;

  StreamSubscription<Duration?>?
      _durationSubscription;

  FinancialAnalysisModel? _analysis;

  FinancialAnalysisModel? get analysis =>
      _analysis;

  bool _isLoading = false;

  bool get isLoading => _isLoading;

  bool _isInitialized = false;

  bool get isInitialized =>
      _isInitialized;

  bool _isAudioLoading = false;

  bool get isAudioLoading =>
      _isAudioLoading;

  bool _isPlaying = false;

  bool get isPlaying => _isPlaying;

  Duration _position = Duration.zero;

  Duration get position => _position;

  Duration _duration = Duration.zero;

  Duration get duration => _duration;

  String? _errorMessage;

  String? get errorMessage =>
      _errorMessage;

  String? _loadedAudioUrl;

  Future<bool>? _audioPreparationFuture;

  bool _disposed = false;

  bool get hasAnalysis =>
      _analysis != null;

  bool get hasAudio {
    return _analysis?.audio.url
            .trim()
            .isNotEmpty ==
        true;
  }

  double get audioProgress {
    if (_duration.inMilliseconds <= 0) {
      return 0;
    }

    return (_position.inMilliseconds /
            _duration.inMilliseconds)
        .clamp(0.0, 1.0);
  }

  // =====================================================
  // INITIALIZATION
  // =====================================================

  Future<void> _initialize() async {
    _isLoading = true;
    _errorMessage = null;

    _safeNotify();

    try {
      _listenToAudioPlayer();

      // يحمل بيانات التحليل فقط.
      // لا يحمل الصوت هنا.
      await loadSavedAnalysis();

      _isInitialized = true;
    } catch (error) {
      _errorMessage =
          'Could not load analysis: '
          '${_cleanError(error)}';
    } finally {
      _isLoading = false;
      _safeNotify();
    }
  }

  void _listenToAudioPlayer() {
    _playerStateSubscription ??=
        _audioPlayer.playerStateStream.listen(
      (state) async {
        _isPlaying = state.playing;

        if (state.processingState ==
            ProcessingState.completed) {
          _isPlaying = false;
          _position = Duration.zero;

          try {
            await _audioPlayer.seek(
              Duration.zero,
            );
          } catch (_) {
            // تجاهل الخطأ عند انتهاء الصوت.
          }
        }

        _safeNotify();
      },
      onError: (Object error) {
        final message =
            error.toString().toLowerCase();

        if (!_isInterruptedError(message)) {
          _errorMessage =
              'Audio error: '
              '${_cleanError(error)}';

          _safeNotify();
        }
      },
    );

    _positionSubscription ??=
        _audioPlayer.positionStream.listen(
      (value) {
        _position = value;
        _safeNotify();
      },
    );

    _durationSubscription ??=
        _audioPlayer.durationStream.listen(
      (value) {
        if (value == null) {
          return;
        }

        _duration = value;
        _safeNotify();
      },
    );
  }

  // =====================================================
  // ANALYSIS DATA
  // =====================================================

  Future<bool> setAnalysisFromJson(
    Map<String, dynamic> json,
  ) async {
    _isLoading = true;
    _errorMessage = null;

    _safeNotify();

    try {
      final status =
          json['status']?.toString();

      if (status != null &&
          status != 'success') {
        throw Exception(
          'Analysis request was not successful',
        );
      }

      final newAnalysis =
          FinancialAnalysisModel.fromJson(
        json,
      );

      // إذا تغيّر رابط الصوت، نصفر حالة المشغل.
      final oldUrl =
          _analysis?.audio.url.trim();

      final newUrl =
          newAnalysis.audio.url.trim();

      _analysis = newAnalysis;

      if (oldUrl != newUrl) {
        await _resetAudioPlayer();
      }

      await _saveAnalysis(
        newAnalysis,
      );

      _errorMessage = null;

      return true;
    } catch (error) {
      _errorMessage =
          'Could not load analysis: '
          '${_cleanError(error)}';

      return false;
    } finally {
      _isLoading = false;
      _safeNotify();
    }
  }

  // =====================================================
  // LOCAL STORAGE
  // =====================================================

  Future<void> loadSavedAnalysis() async {
    final preferences =
        await SharedPreferences.getInstance();

    final savedValue =
        preferences.getString(
      _storageKey,
    );

    if (savedValue == null ||
        savedValue.trim().isEmpty) {
      return;
    }

    final decoded =
        jsonDecode(savedValue);

    if (decoded is! Map) {
      throw const FormatException(
        'Invalid saved analysis data',
      );
    }

    _analysis =
        FinancialAnalysisModel.fromJson(
      Map<String, dynamic>.from(
        decoded,
      ),
    );
  }

  Future<void> _saveAnalysis(
    FinancialAnalysisModel analysis,
  ) async {
    final preferences =
        await SharedPreferences.getInstance();

    final saved =
        await preferences.setString(
      _storageKey,
      jsonEncode(
        analysis.toJson(),
      ),
    );

    if (!saved) {
      throw Exception(
        'Could not save analysis locally',
      );
    }
  }

  // =====================================================
  // AUDIO PREPARATION
  // =====================================================

  Future<bool> _ensureAudioPrepared() {
    final currentPreparation =
        _audioPreparationFuture;

    if (currentPreparation != null) {
      return currentPreparation;
    }

    final future =
        _prepareAudioOnce();

    _audioPreparationFuture =
        future;

    future.whenComplete(() {
      _audioPreparationFuture =
          null;
    });

    return future;
  }

  Future<bool> _prepareAudioOnce() async {
    final url =
        _analysis?.audio.url.trim() ??
            '';

    if (url.isEmpty) {
      _errorMessage =
          'Audio is unavailable';

      _safeNotify();

      return false;
    }

    // نفس الرابط محمل بالفعل.
    if (_loadedAudioUrl == url &&
        _audioPlayer.processingState !=
            ProcessingState.idle) {
      _errorMessage = null;

      return true;
    }

    _isAudioLoading = true;
    _errorMessage = null;

    _safeNotify();

    try {
      final loadedDuration =
          await _audioPlayer.setUrl(
        url,
      );

      _loadedAudioUrl = url;

      _duration =
          loadedDuration ??
          _audioPlayer.duration ??
          Duration(
            milliseconds:
                ((_analysis?.audio.duration ??
                            0) *
                        1000)
                    .round(),
          );

      _position = Duration.zero;
      _errorMessage = null;

      return true;
    } catch (error) {
      final message =
          error.toString().toLowerCase();

      if (_isInterruptedError(message)) {
        // لا نعرض Loading interrupted للمستخدم.
        _errorMessage = null;
      } else {
        _errorMessage =
            'Could not load audio: '
            '${_cleanError(error)}';
      }

      return false;
    } finally {
      _isAudioLoading = false;
      _safeNotify();
    }
  }

  bool _isInterruptedError(
    String message,
  ) {
    return message.contains(
          'loading interrupted',
        ) ||
        message.contains(
          'player interrupted',
        ) ||
        message.contains(
          'operation was aborted',
        ) ||
        message.contains(
          'source was interrupted',
        );
  }

  Future<void> _resetAudioPlayer() async {
    try {
      await _audioPlayer.stop();
    } catch (_) {
      // تجاهل الخطأ إذا لم يكن هناك صوت.
    }

    _audioPreparationFuture = null;
    _loadedAudioUrl = null;

    _duration = Duration.zero;
    _position = Duration.zero;

    _isPlaying = false;
    _isAudioLoading = false;
  }

  // =====================================================
  // AUDIO CONTROLS
  // =====================================================

  Future<void> toggleAudio() async {
    if (!hasAudio ||
        _isAudioLoading) {
      return;
    }

    _errorMessage = null;
    _safeNotify();

    try {
      if (_audioPlayer.playing) {
        await _audioPlayer.pause();

        return;
      }

      final prepared =
          await _ensureAudioPrepared();

      if (!prepared) {
        return;
      }

      if (_audioPlayer
              .processingState ==
          ProcessingState.completed) {
        await _audioPlayer.seek(
          Duration.zero,
        );
      }

      await _audioPlayer.play();

      _errorMessage = null;
    } catch (error) {
      final message =
          error.toString().toLowerCase();

      if (!_isInterruptedError(message)) {
        _errorMessage =
            'Could not play audio: '
            '${_cleanError(error)}';
      }

      _safeNotify();
    }
  }

  Future<void> replayAudio() async {
    if (!hasAudio ||
        _isAudioLoading) {
      return;
    }

    _errorMessage = null;
    _safeNotify();

    try {
      final prepared =
          await _ensureAudioPrepared();

      if (!prepared) {
        return;
      }

      await _audioPlayer.seek(
        Duration.zero,
      );

      await _audioPlayer.play();

      _errorMessage = null;
    } catch (error) {
      final message =
          error.toString().toLowerCase();

      if (!_isInterruptedError(message)) {
        _errorMessage =
            'Could not replay audio: '
            '${_cleanError(error)}';
      }

      _safeNotify();
    }
  }

  Future<void> seekAudio(
    double value,
  ) async {
    if (!hasAudio) {
      return;
    }

    try {
      final prepared =
          await _ensureAudioPrepared();

      if (!prepared ||
          _duration.inMilliseconds <= 0) {
        return;
      }

      final safeValue =
          value.clamp(0.0, 1.0);

      final target =
          Duration(
        milliseconds:
            (_duration.inMilliseconds *
                    safeValue)
                .round(),
      );

      await _audioPlayer.seek(
        target,
      );

      _errorMessage = null;
    } catch (error) {
      final message =
          error.toString().toLowerCase();

      if (!_isInterruptedError(message)) {
        _errorMessage =
            'Could not change audio position: '
            '${_cleanError(error)}';
      }

      _safeNotify();
    }
  }

  Future<void> stopAudio() async {
    try {
      if (_audioPlayer.playing) {
        await _audioPlayer.pause();
      }

      await _audioPlayer.seek(
        Duration.zero,
      );
    } catch (_) {
      // تجاهل أخطاء الخروج من الصفحة.
    }

    _position = Duration.zero;
    _isPlaying = false;

    _safeNotify();
  }

  // =====================================================
  // CLEAR ANALYSIS
  // =====================================================

  Future<void> clearAnalysis() async {
    await _resetAudioPlayer();

    _analysis = null;
    _errorMessage = null;

    final preferences =
        await SharedPreferences.getInstance();

    await preferences.remove(
      _storageKey,
    );

    _safeNotify();
  }

  void clearError() {
    _errorMessage = null;

    _safeNotify();
  }

  // =====================================================
  // DISPLAY HELPERS
  // =====================================================

  String formatDuration(
    Duration value,
  ) {
    final minutes =
        value.inMinutes;

    final seconds =
        value.inSeconds.remainder(
      60,
    );

    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  String get analysisTitleDate {
    final date =
        _analysis
            ?.metadata
            .analysisAsOfDate;

    if (date == null) {
      return '';
    }

    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  // =====================================================
  // MOCK ANALYSIS
  // =====================================================

  Future<bool> loadMockAnalysis() async {
    return setAnalysisFromJson(
      {
        'status': 'success',
        'User': {
          'userId':
              'user_demo_001',
          'name': 'mohammad',
          'displayName': 'محمد',
          'language': 'ar',
          'locale': 'ar-JO',
          'currency': 'JOD',
          'timezone':
              'Asia/Amman',
        },
        'data': {
          'content': {
            'summary':
                'ما زلت محافظاً على الاحتياجات الأساسية بشكل جيد، لكن الادخار الفعلي لا يواكب الهدف، لأن جزءاً كبيراً من الإنفاق اتجه إلى بنود الرغبات مثل المطاعم والمقاهي والتسوق.',
            'insights': [
              'الاحتياجات الأساسية تحت السيطرة، وملفك فيها ما زال قريباً من المسار المتوقع.',
              'الإنفاق على المطاعم ارتفع بشكل واضح ضمن بنود الرغبات.',
              'هذا الارتفاع يضغط على الادخار ويؤخر تقدمك نحو هدفك المالي.',
            ],
            'recommendations': [
              'خفف الزيارات المتكررة للمطاعم والمقاهي.',
              'راجع الالتزامات الثابتة القادمة باكراً.',
              'تابع إنفاقك يومياً حتى تلاحظ أي تسرب صغير قبل أن يكبر.',
            ],
            'speechText':
                'مرحباً محمد، أنا ألفا. عندك جانب إيجابي واضح، وهو أنك حافظت على الاحتياجات الأساسية بشكل منظم ومقبول. لكن نقطة الانتباه الأهم أن جزءاً من الإنفاق اتجه أكثر من اللازم إلى المطاعم والمقاهي.',
          },
          'uiMetrics': {
            'savings': {
              'current': 30,
              'target': 90,
              'percent': 33.33,
              'status': 'warning',
            },
            'needs': {
              'current': 190,
              'target': 360,
              'percent': 52.78,
              'status': 'on_track',
            },
            'wants': {
              'current': 110,
              'target': 150,
              'percent': 73.33,
              'status': 'warning',
            },
          },
          'audio': {
            'url':
                'https://res.cloudinary.com/f8zh5okp/video/upload/v1784385708/hdagyankyfbkftorp74j.mp3',
            'duration': 31.752,
          },
        },
        'metadata': {
          'requestId':
              'req_analyze_001',
          'analysisAsOfDate':
              '2026-07-17',
          'generatedAt':
              '2026-07-18T14:41:49.655Z',
        },
      },
    );
  }

  // =====================================================
  // HELPERS
  // =====================================================

  String _cleanError(
    Object error,
  ) {
    return error
        .toString()
        .replaceFirst(
          'Exception: ',
          '',
        );
  }

  void _safeNotify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  // =====================================================
  // DISPOSE
  // =====================================================

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