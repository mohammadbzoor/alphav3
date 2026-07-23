import 'dart:io';

import 'package:alpha_app/core/utils/app_colors.dart';
import 'package:alpha_app/core/utils/dashboard_action_result.dart';
import 'package:alpha_app/providers/themeprovider.dart';
import 'package:alpha_app/screens/transactions/transaction_review_screen.dart';
import 'package:alpha_app/services/transaction_ai_service.dart';
import 'package:alpha_app/services/api_exception.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

class ReceiptInputScreen extends StatefulWidget {
  final File? initialImage;

  const ReceiptInputScreen({
    super.key,
    this.initialImage,
  });

  @override
  State<ReceiptInputScreen> createState() => _ReceiptInputScreenState();
}

class _ReceiptInputScreenState extends State<ReceiptInputScreen>
    with WidgetsBindingObserver {
  // =====================================================
  // STATE
  // =====================================================

  CameraController? _cameraController;
  bool _isInitializing = false;
  String? _cameraInitError;

  bool _isCapturing = false;
  bool _isPickingGallery = false;
  bool _isAnalyzing = false;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.initialImage != null) {
      _analyzeImage(widget.initialImage!.path);
    } else {
      _initializeCamera();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? cameraController = _cameraController;
    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      cameraController.dispose();
      _cameraController = null;
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  // =====================================================
  // CAMERA INIT
  // =====================================================

  Future<void> _initializeCamera() async {
    if (_isInitializing) return;
    setState(() {
      _isInitializing = true;
      _cameraInitError = null;
    });

    try {
      final status = await Permission.camera.request();
      if (status.isPermanentlyDenied) {
        setState(() {
          _cameraInitError =
              'Camera permission was permanently denied. Open Settings to enable it.';
          _isInitializing = false;
        });
        debugPrint('CAMERA permission=permanently_denied');
        return;
      } else if (!status.isGranted) {
        setState(() {
          _cameraInitError =
              'Camera access is denied. Please enable it in Settings.';
          _isInitializing = false;
        });
        debugPrint('CAMERA permission=denied');
        return;
      }

      debugPrint('CAMERA permission=granted');

      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() {
          _cameraInitError = 'No cameras found on this device.';
          _isInitializing = false;
        });
        return;
      }

      final backCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        backCamera,
        ResolutionPreset.high,
        enableAudio: false,
      );

      await controller.initialize();

      if (!mounted) {
        return;
      }

      setState(() {
        _cameraController = controller;
        _isInitializing = false;
      });
      debugPrint('CAMERA initialized=true');
    } catch (e) {
      debugPrint('CAMERA init failed: $e');
      if (mounted) {
        setState(() {
          _cameraInitError = 'Unable to start the camera.';
          _isInitializing = false;
        });
      }
    }
  }

  // =====================================================
  // CAPTURE & GALLERY
  // =====================================================

  Future<void> _capturePhoto() async {
    if (_isCapturing || _isAnalyzing || _isPickingGallery) return;

    final controller = _cameraController;
    if (controller == null ||
        !controller.value.isInitialized ||
        controller.value.isTakingPicture) {
      return;
    }

    setState(() => _isCapturing = true);
    debugPrint('CAMERA capturePressed');

    try {
      final XFile photo = await controller.takePicture();
      debugPrint('CAMERA captureCompleted');
      await _analyzeImage(photo.path);
    } catch (e) {
      debugPrint('CAMERA capture error: $e');
      if (mounted) _showError('Failed to capture photo.');
    } finally {
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  Future<void> _pickGalleryImage() async {
    if (_isPickingGallery || _isCapturing || _isAnalyzing) return;

    setState(() => _isPickingGallery = true);

    try {
      final XFile? picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
        maxWidth: 1280,
        maxHeight: 1280,
      );

      if (!mounted) return;
      if (picked == null) return;

      await _analyzeImage(picked.path);
    } catch (e) {
      if (!mounted) return;
      _showError('Could not select image. Please try again.');
    } finally {
      if (mounted) setState(() => _isPickingGallery = false);
    }
  }

  // =====================================================
  // ANALYZE (IMMEDIATE UPLOAD)
  // =====================================================

  Future<void> _analyzeImage(String imagePath) async {
    if (_isAnalyzing) return;

    final file = File(imagePath);
    final exists = await file.exists();
    debugPrint('CAMERA fileExists=$exists');
    if (!exists) {
      if (mounted) _showError('Could not read the image. Please try again.');
      return;
    }

    final length = await file.length();
    debugPrint('CAMERA fileSize=$length');
    if (length <= 0) {
      if (mounted)
        _showError('The selected image appears to be empty. Please try again.');
      return;
    }

    setState(() => _isAnalyzing = true);
    debugPrint('RECEIPT uploadStarted');

    try {
      final result = await TransactionAiService.analyzeReceipt(file.path);

      if (!mounted) return;

      debugPrint('RECEIPT statusCode=200');
      debugPrint(
          'RECEIPT parsedTransactions=${result?.transactions.length ?? 0}');

      if (result == null || result.transactions.isEmpty) {
        if (mounted) {
          setState(() {
            _isAnalyzing = false;
          });
        }
        await Future<void>.delayed(Duration.zero);
        if (mounted) {
          _showError('No transactions were found in the receipt.');
        }
        return;
      }

      if (mounted) {
        setState(() {
          _isAnalyzing = false;
        });
      }
      debugPrint('RECEIPT loadingStopped=true');

      await Future<void>.delayed(Duration.zero);

      if (!mounted) return;
      debugPrint('RECEIPT mountedBeforeNavigation=true');
      debugPrint('RECEIPT navigationStarted');

      final actionResult = await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => TransactionReviewScreen(
            transactions: result.transactions,
            currentIndex: 0,
          ),
        ),
      );

      if (!mounted) return;

      if (actionResult == DashboardActionResult.created) {
        Navigator.pop(context, DashboardActionResult.created);
      }
    } catch (e, stackTrace) {
      debugPrint('RECEIPT error: $e');
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
        });
      }

      await Future<void>.delayed(Duration.zero);

      if (!mounted) return;

      if (e is ApiException) {
        debugPrint('RECEIPT statusCode=${e.statusCode}');
        _showError(e.message);
      } else {
        final errorStr = e.toString();
        if (errorStr.contains('Unsupported response shape') ||
            errorStr.contains('Invalid transaction element format') ||
            errorStr.contains('ReceiptAnalysisContractException')) {
          _showError('The receipt analysis response could not be processed.');
        } else {
          _showError('Unable to analyze the receipt. Please try again.');
        }
      }
    } finally {
      if (mounted && _isAnalyzing) {
        setState(() => _isAnalyzing = false);
      }
    }
  }

  // =====================================================
  // ERROR MESSAGES
  // =====================================================

  void _showError(String message) {
    if (message.isEmpty) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: GoogleFonts.ibmPlexSansArabic(fontSize: 13),
          ),
          backgroundColor: AppColors.lightError,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  // =====================================================
  // BUILD
  // =====================================================

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<Themeprovider>().isDark;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── Background: Camera preview or Error ─────────
          Positioned.fill(
            child: _buildCameraPreview(isDark),
          ),

          // ── Close / back button ────────────────────────
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 16,
            child: _CircleIconButton(
              icon: Icons.close,
              onPressed: () => Navigator.pop(context),
            ),
          ),

          // ── Bottom controls: camera + gallery ──────────
          if (_cameraInitError == null)
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 40,
              left: 0,
              right: 0,
              child: _PickerControls(
                isBusy: _isCapturing ||
                    _isPickingGallery ||
                    _isAnalyzing ||
                    _isInitializing,
                onCamera: _capturePhoto,
                onGallery: _pickGalleryImage,
              ),
            ),

          // ── Analyzing overlay ──────────────────────────
          if (_isAnalyzing)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(
                      color: AppColors.lightPrimary,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Analyzing your receipt...\nThis may take a few moments.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.ibmPlexSansArabic(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCameraPreview(bool isDark) {
    if (_cameraInitError != null) {
      return Container(
        color: Colors.black,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                color: AppColors.lightError,
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                _cameraInitError!,
                style: GoogleFonts.ibmPlexSansArabic(
                  color: Colors.white,
                  fontSize: 15,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: 200,
                child: ElevatedButton(
                  onPressed: _initializeCamera,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.lightPrimary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Retry'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: 200,
                child: ElevatedButton(
                  onPressed: _pickGalleryImage,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[800],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Choose from Gallery'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: 200,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_isInitializing ||
        _cameraController == null ||
        !_cameraController!.value.isInitialized) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(color: AppColors.lightPrimary),
        ),
      );
    }

    // Camera view
    final size = MediaQuery.of(context).size;
    var scale = size.aspectRatio * _cameraController!.value.aspectRatio;
    if (scale < 1) scale = 1 / scale;

    return Transform.scale(
      scale: scale,
      child: Center(
        child: CameraPreview(_cameraController!),
      ),
    );
  }
}

// =====================================================
// PICKER CONTROLS (camera shutter + gallery)
// =====================================================

class _PickerControls extends StatelessWidget {
  final bool isBusy;
  final VoidCallback onCamera;
  final VoidCallback onGallery;

  const _PickerControls({
    required this.isBusy,
    required this.onCamera,
    required this.onGallery,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Gallery
        _CircleIconButton(
          icon: Icons.photo_library_outlined,
          onPressed: isBusy ? null : onGallery,
          size: 52,
        ),

        // Camera shutter
        GestureDetector(
          onTap: isBusy ? null : onCamera,
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 4),
              color: Colors.white.withValues(alpha: 0.25),
            ),
            child: isBusy
                ? const Icon(
                    Icons.camera_alt,
                    color: Colors.white38,
                    size: 32,
                  )
                : const Icon(
                    Icons.camera_alt,
                    color: Colors.white,
                    size: 32,
                  ),
          ),
        ),

        // Placeholder to balance layout
        const SizedBox(width: 52),
      ],
    );
  }
}

// =====================================================
// REUSABLE CIRCLE ICON BUTTON
// =====================================================

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final double size;

  const _CircleIconButton({
    required this.icon,
    required this.onPressed,
    this.size = 44,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black.withValues(alpha: 0.45),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.3),
          ),
        ),
        child: Icon(
          icon,
          color: onPressed == null
              ? Colors.white.withValues(alpha: 0.35)
              : Colors.white,
          size: size * 0.5,
        ),
      ),
    );
  }
}
