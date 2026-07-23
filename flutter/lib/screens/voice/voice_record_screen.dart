import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:alpha_app/services/transaction_ai_service.dart';
import 'package:alpha_app/screens/transactions/transaction_review_screen.dart';
import 'package:alpha_app/models/transaction_draft_model.dart';
import 'package:alpha_app/services/api_exception.dart';
import 'package:alpha_app/core/utils/dashboard_action_result.dart';

class VoiceRecordScreen extends StatefulWidget {
  const VoiceRecordScreen({super.key});

  @override
  State<VoiceRecordScreen> createState() => _VoiceRecordScreenState();
}

class _VoiceRecordScreenState extends State<VoiceRecordScreen> {
  late final AudioRecorder _audioRecorder;

  bool _isStarting = false;
  bool _isRecording = false;
  bool _isStopping = false;
  bool _isAnalyzing = false;
  bool _isNavigating = false;

  int _recordDuration = 0;
  Timer? _timer;
  String? _audioPath;

  final int _maxDurationSeconds = 60;

  @override
  void initState() {
    super.initState();
    _audioRecorder = AudioRecorder();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _audioRecorder.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _recordDuration = 0;
    _timer = Timer.periodic(const Duration(seconds: 1), (Timer t) {
      if (!mounted) return;
      setState(() {
        _recordDuration++;
      });
      if (_recordDuration >= _maxDurationSeconds) {
        _stopRecording();
      }
    });
  }

  String _formatDuration(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _startRecording() async {
    if (_isStarting ||
        _isRecording ||
        _isStopping ||
        _isAnalyzing ||
        _isNavigating) {
      return;
    }

    setState(() {
      _isStarting = true;
    });

    try {
      final status = await Permission.microphone.request();

      if (status.isDenied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text(
                    'Microphone permission is required to record a transaction.')),
          );
        }
        setState(() => _isStarting = false);
        return;
      }

      if (status.isPermanentlyDenied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                  'Microphone permission was permanently denied. Open Settings to enable it.'),
              action: SnackBarAction(
                label: 'Open Settings',
                onPressed: () {
                  openAppSettings();
                },
              ),
            ),
          );
        }
        setState(() => _isStarting = false);
        return;
      }

      if (!await _audioRecorder.hasPermission()) {
        throw Exception('Recorder permission not granted');
      }

      final dir = await getTemporaryDirectory();
      final filePath =
          '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 64000,
          sampleRate: 44100,
          numChannels: 1,
        ),
        path: filePath,
      );

      if (mounted) {
        setState(() {
          _isRecording = true;
          _audioPath = filePath;
        });
        _startTimer();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to start voice recording.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isStarting = false);
      }
    }
  }

  Future<void> _stopRecording() async {
    if (!_isRecording || _isStopping || _isAnalyzing || _isNavigating) {
      return;
    }

    setState(() {
      _isStopping = true;
    });

    _timer?.cancel();

    try {
      final path = await _audioRecorder.stop();
      if (mounted) {
        setState(() => _isRecording = false);
      }

      if (path == null || path.isEmpty) {
        throw Exception('Empty path');
      }

      final file = File(path);
      if (!await file.exists() ||
          await file.length() == 0 ||
          _recordDuration < 1) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text(
                    'The recording is empty or too short. Please record again.')),
          );
        }
        await _deleteFile(path);
        return;
      }

      await _analyzeVoice(path);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Unable to analyze the voice recording. Please try again.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isStopping = false);
      }
    }
  }

  Future<void> _deleteFile(String? path) async {
    if (path == null) return;
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }

  Future<void> _cancelRecording() async {
    _timer?.cancel();
    try {
      await _audioRecorder.stop();
    } catch (_) {}

    await _deleteFile(_audioPath);

    setState(() {
      _isStarting = false;
      _isRecording = false;
      _isStopping = false;
      _isAnalyzing = false;
      _isNavigating = false;
      _recordDuration = 0;
      _audioPath = null;
    });
  }

  Future<void> _analyzeVoice(String path) async {
    setState(() => _isAnalyzing = true);

    try {
      final result = await TransactionAiService.analyzeVoice(path);

      await _deleteFile(path);

      if (!mounted) return;

      if (result != null && result.transactions.isNotEmpty) {
        setState(() {
          _isAnalyzing = false;
          _isNavigating = true;
        });

        await Future.delayed(Duration.zero);
        if (!mounted) return;

        debugPrint('VOICE reviewNavigationStarted=true');
        final navResult = await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => TransactionReviewScreen(
              transactions: result.transactions,
              currentIndex: 0,
            ),
          ),
        );

        if (!mounted) return;
        setState(() => _isNavigating = false);

        if (navResult == DashboardActionResult.created) {
          Navigator.pop(context, DashboardActionResult.created);
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text('The voice analysis response could not be processed.')),
        );
        setState(() => _isAnalyzing = false);
      }
    } catch (e) {
      await _deleteFile(path);
      if (mounted) {
        String msg = 'Unable to analyze the voice recording. Please try again.';
        if (e is ApiException) {
          msg = e.message ?? msg;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
        setState(() => _isAnalyzing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Voice Transaction')),
      body: Center(
        child: _isAnalyzing
            ? const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Analyzing your voice...'),
                  SizedBox(height: 8),
                  Text('This may take a few moments.'),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _formatDuration(_recordDuration),
                    style: Theme.of(context).textTheme.displayMedium,
                  ),
                  const SizedBox(height: 32),
                  if (!_isRecording)
                    ElevatedButton.icon(
                      onPressed: (_isStarting || _isStopping || _isNavigating)
                          ? null
                          : _startRecording,
                      icon: const Icon(Icons.mic),
                      label: const Text('Start Recording'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 32, vertical: 16),
                      ),
                    )
                  else
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton.icon(
                          onPressed: (_isStopping || _isNavigating)
                              ? null
                              : _cancelRecording,
                          icon: const Icon(Icons.close),
                          label: const Text('Cancel Recording'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton.icon(
                          onPressed: (_isStopping || _isNavigating)
                              ? null
                              : _stopRecording,
                          icon: const Icon(Icons.stop),
                          label: const Text('Stop and Analyze'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
      ),
    );
  }
}
