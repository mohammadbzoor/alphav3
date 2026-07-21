import 'package:alpha_app/core/utils/app_colors.dart';
import 'package:alpha_app/models/parsed_receipt_model.dart';
import 'package:alpha_app/providers/receipt_provider.dart';
import 'package:alpha_app/providers/themeprovider.dart';
import 'package:alpha_app/screens/receipts/receipt_review_screen.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class ReceiptInputScreen extends StatefulWidget {
  const ReceiptInputScreen({
    super.key,
  });

  @override
  State<ReceiptInputScreen> createState() =>
      _ReceiptInputScreenState();
}

class _ReceiptInputScreenState extends State<ReceiptInputScreen>
    with WidgetsBindingObserver {
  CameraController? _cameraController;
  Future<void>? _cameraFuture;

  bool _isInitializingCamera = false;
  bool _isTakingPicture = false;
  bool _flashEnabled = false;

  String? _cameraError;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    _initializeCamera();
  }

  // =====================================================
  // CAMERA INITIALIZATION
  // =====================================================

  Future<void> _initializeCamera() async {
    if (_isInitializingCamera) return;

    _isInitializingCamera = true;

    if (mounted) {
      setState(() {
        _cameraError = null;
      });
    }

    try {
      final cameras = await availableCameras();

      if (cameras.isEmpty) {
        throw Exception(
          'No camera was found on this device',
        );
      }

      final backCamera = cameras.firstWhere(
        (camera) {
          return camera.lensDirection ==
              CameraLensDirection.back;
        },
        orElse: () => cameras.first,
      );

      final oldController = _cameraController;

      _cameraController = null;
      _cameraFuture = null;

      await oldController?.dispose();

      final controller = CameraController(
        backCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      final initializeFuture =
          controller.initialize();

      _cameraController = controller;
      _cameraFuture = initializeFuture;

      if (mounted) {
        setState(() {});
      }

      await initializeFuture;

      if (!mounted ||
          _cameraController != controller) {
        await controller.dispose();
        return;
      }

      await controller.setFlashMode(
        FlashMode.off,
      );

      if (!mounted) return;

      setState(() {
        _flashEnabled = false;
      });
    } on CameraException catch (error) {
      if (!mounted) return;

      setState(() {
        _cameraError =
            error.description ?? error.code;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _cameraError = error
            .toString()
            .replaceFirst('Exception: ', '');
      });
    } finally {
      _isInitializingCamera = false;
    }
  }

  @override
  void didChangeAppLifecycleState(
    AppLifecycleState state,
  ) {
    if (state == AppLifecycleState.resumed) {
      final controller = _cameraController;

      if (controller == null ||
          !controller.value.isInitialized) {
        _initializeCamera();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    _cameraController?.dispose();

    super.dispose();
  }

  // =====================================================
  // BUILD
  // =====================================================

  @override
  Widget build(BuildContext context) {
    final bool isDark =
        context.watch<Themeprovider>().isDark;

    final receiptProvider =
        context.watch<ReceiptProvider>();

    final bool hasVoiceText =
        receiptProvider.voiceText.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.darkBackground
          : AppColors.lightBackground,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        centerTitle: true,
        leading: IconButton(
          onPressed: () async {
            await context
                .read<ReceiptProvider>()
                .cancelVoiceInput();

            if (!context.mounted) return;

            context
                .read<ReceiptProvider>()
                .clear();

            Navigator.pop(context);
          },
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: isDark
                ? AppColors.darkText
                : AppColors.lightText,
          ),
        ),
        title: Text(
          'Scan Receipt',
          style: GoogleFonts.ibmPlexSansArabic(
            color: isDark
                ? AppColors.darkText
                : AppColors.lightText,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Stack(
          children: [
            SingleChildScrollView(
              physics:
                  const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                22,
                15,
                22,
                40,
              ),
              child: Column(
                children: [
                  _buildCameraScanner(isDark),

                  const SizedBox(height: 20),

                  Text(
                    receiptProvider.isListening
                        ? 'Listening...'
                        : 'Place the receipt inside the frame',
                    textAlign: TextAlign.center,
                    style:
                        GoogleFonts.ibmPlexSansArabic(
                      color: isDark
                          ? AppColors.darkText
                          : AppColors.lightText,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  const SizedBox(height: 5),

                  Text(
                    receiptProvider.isListening
                        ? 'Describe the store, items and amounts'
                        : 'Or use your voice to add the expense',
                    textAlign: TextAlign.center,
                    style:
                        GoogleFonts.ibmPlexSansArabic(
                      color: isDark
                          ? AppColors.darkSubText
                          : AppColors.lightSubText,
                      fontSize: 11,
                      height: 1.5,
                    ),
                  ),

                  const SizedBox(height: 18),

                  _VoiceLanguageSelector(
                    selectedLocale:
                        receiptProvider
                            .selectedVoiceLocale,
                    enabled:
                        !receiptProvider.isListening,
                    isDark: isDark,
                    onChanged: (locale) {
                      context
                          .read<ReceiptProvider>()
                          .changeVoiceLocale(locale);
                    },
                  ),

                  if (hasVoiceText) ...[
                    const SizedBox(height: 14),

                    _EditableVoiceTextCard(
                      text:
                          receiptProvider.voiceText,
                      isListening:
                          receiptProvider.isListening,
                      isDark: isDark,
                      onChanged: (value) {
                        context
                            .read<ReceiptProvider>()
                            .updateVoiceText(value);
                      },
                    ),
                  ],

                  if (receiptProvider.errorMessage !=
                      null) ...[
                    const SizedBox(height: 14),

                    _ErrorCard(
                      message:
                          receiptProvider.errorMessage!,
                      onClose: () {
                        context
                            .read<ReceiptProvider>()
                            .clearError();
                      },
                    ),
                  ],

                  const SizedBox(height: 24),

                  _InputControls(
                    isDark: isDark,
                    isListening:
                        receiptProvider.isListening,
                    isCameraReady:
                        _cameraController
                                ?.value
                                .isInitialized ??
                            false,
                    isCapturing:
                        _isTakingPicture,
                    onGalleryPressed:
                        _pickFromGallery,
                    onCameraPressed:
                        _captureReceipt,
                    onVoicePressed:
                        _handleVoice,
                  ),

                  const SizedBox(height: 15),

                  Text(
                    receiptProvider.isListening
                        ? 'Tap the microphone to stop'
                        : hasVoiceText
                            ? 'Tap the microphone again to add more speech'
                            : 'Gallery • Camera • Voice',
                    textAlign: TextAlign.center,
                    style:
                        GoogleFonts.ibmPlexSansArabic(
                      color:
                          receiptProvider.isListening
                              ? const Color(
                                  0xFF34D399,
                                )
                              : isDark
                                  ? AppColors
                                      .darkSubText
                                  : AppColors
                                      .lightSubText,
                      fontSize: 10,
                    ),
                  ),

                  if (hasVoiceText &&
                      !receiptProvider
                          .isListening) ...[
                    const SizedBox(height: 18),

                    _AnalyzeVoiceButton(
                      isLoading:
                          receiptProvider
                              .isProcessing,
                      onPressed:
                          _analyzeVoiceText,
                    ),
                  ],
                ],
              ),
            ),

            if (receiptProvider.isProcessing ||
                _isTakingPicture)
              _ProcessingOverlay(
                isDark: isDark,
              ),
          ],
        ),
      ),
    );
  }

  // =====================================================
  // CAMERA SCANNER
  // =====================================================

  Widget _buildCameraScanner(
    bool isDark,
  ) {
    return AspectRatio(
      aspectRatio: 0.95,
      child: ClipRRect(
        borderRadius:
            BorderRadius.circular(25),
        child: Container(
          color: isDark
              ? const Color(0xFF071512)
              : const Color(0xFFE8F2EE),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _buildCameraPreview(isDark),

              Container(
                color: Colors.black
                    .withOpacity(0.08),
              ),

              Center(
                child: Container(
                  width: 175,
                  height: 270,
                  decoration: BoxDecoration(
                    borderRadius:
                        BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.white
                          .withOpacity(0.60),
                    ),
                  ),
                ),
              ),

              const Center(
                child: _ScannerLine(),
              ),

              const Positioned(
                top: 20,
                left: 20,
                child: _ScannerCorner(
                  top: true,
                  left: true,
                ),
              ),

              const Positioned(
                top: 20,
                right: 20,
                child: _ScannerCorner(
                  top: true,
                  left: false,
                ),
              ),

              const Positioned(
                bottom: 20,
                left: 20,
                child: _ScannerCorner(
                  top: false,
                  left: true,
                ),
              ),

              const Positioned(
                bottom: 20,
                right: 20,
                child: _ScannerCorner(
                  top: false,
                  left: false,
                ),
              ),

              Positioned(
                top: 14,
                right: 14,
                child: _FlashButton(
                  isEnabled:
                      _flashEnabled,
                  onPressed:
                      _toggleFlash,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCameraPreview(
    bool isDark,
  ) {
    if (_cameraError != null) {
      return _CameraErrorView(
        error: _cameraError!,
        isDark: isDark,
        onRetry: _initializeCamera,
      );
    }

    final controller =
        _cameraController;

    final cameraFuture =
        _cameraFuture;

    if (controller == null ||
        cameraFuture == null) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF34D399),
        ),
      );
    }

    return FutureBuilder<void>(
      future: cameraFuture,
      builder: (
        context,
        snapshot,
      ) {
        if (snapshot.connectionState ==
            ConnectionState.waiting) {
          return const Center(
            child:
                CircularProgressIndicator(
              color: Color(0xFF34D399),
            ),
          );
        }

        if (snapshot.hasError) {
          return _CameraErrorView(
            error:
                snapshot.error.toString(),
            isDark: isDark,
            onRetry:
                _initializeCamera,
          );
        }

        if (!controller
            .value.isInitialized) {
          return _CameraErrorView(
            error:
                'Camera is not initialized',
            isDark: isDark,
            onRetry:
                _initializeCamera,
          );
        }

        return CameraPreview(
          controller,
        );
      },
    );
  }

  // =====================================================
  // CAMERA CAPTURE
  // =====================================================

  Future<void> _captureReceipt() async {
    final controller =
        _cameraController;

    if (controller == null ||
        !controller.value.isInitialized ||
        _isTakingPicture) {
      return;
    }

    try {
      setState(() {
        _isTakingPicture = true;
      });

      final image =
          await controller.takePicture();

      if (!mounted) return;

      final result = await context
          .read<ReceiptProvider>()
          .processCapturedImage(
            image.path,
          );

      if (!mounted ||
          result == null) {
        return;
      }

      await _openReviewScreen();
    } on CameraException catch (error) {
      if (!mounted) return;

      _showMessage(
        error.description ??
            'Could not capture receipt',
      );
    } catch (error) {
      if (!mounted) return;

      _showMessage(
        'Could not capture receipt: $error',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isTakingPicture = false;
        });
      }
    }
  }

  // =====================================================
  // GALLERY
  // =====================================================

  Future<void> _pickFromGallery() async {
    final result = await context
        .read<ReceiptProvider>()
        .pickReceiptFromGallery();

    if (!mounted ||
        result == null) {
      return;
    }

    await _openReviewScreen();
  }

  // =====================================================
  // VOICE START / STOP
  // =====================================================

  Future<void> _handleVoice() async {
    FocusScope.of(context).unfocus();

    final provider =
        context.read<ReceiptProvider>();

    if (provider.isListening) {
      await provider.stopVoiceInput();
    } else {
      await provider.startVoiceInput();
    }
  }

  // =====================================================
  // ANALYZE EDITED VOICE TEXT
  // =====================================================

  Future<void> _analyzeVoiceText() async {
    FocusScope.of(context).unfocus();

    final result = await context
        .read<ReceiptProvider>()
        .parseEditedVoiceText();

    if (!mounted ||
        result == null) {
      return;
    }

    await _openReviewScreen();
  }

  // =====================================================
  // REVIEW
  // =====================================================

  Future<void> _openReviewScreen() async {
    final controller =
        _cameraController;

    if (controller != null &&
        controller.value.isInitialized) {
      try {
        await controller.pausePreview();
      } catch (_) {}
    }

    if (!mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            const ReceiptReviewScreen(),
      ),
    );

    if (!mounted) return;

    final currentController =
        _cameraController;

    if (currentController != null &&
        currentController.value.isInitialized) {
      try {
        await currentController
            .resumePreview();
      } catch (_) {
        await _initializeCamera();
      }
    } else {
      await _initializeCamera();
    }
  }

  // =====================================================
  // FLASH
  // =====================================================

  Future<void> _toggleFlash() async {
    final controller =
        _cameraController;

    if (controller == null ||
        !controller.value.isInitialized) {
      return;
    }

    final newValue =
        !_flashEnabled;

    try {
      await controller.setFlashMode(
        newValue
            ? FlashMode.torch
            : FlashMode.off,
      );

      if (!mounted) return;

      setState(() {
        _flashEnabled = newValue;
      });
    } on CameraException catch (error) {
      if (!mounted) return;

      _showMessage(
        error.description ??
            'Flash is unavailable',
      );
    }
  }

  void _showMessage(
    String message,
  ) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
        ),
      );
  }
}

// =====================================================
// VOICE LANGUAGE
// =====================================================

class _VoiceLanguageSelector
    extends StatelessWidget {
  final String selectedLocale;
  final bool enabled;
  final bool isDark;
  final ValueChanged<String> onChanged;

  const _VoiceLanguageSelector({
    required this.selectedLocale,
    required this.enabled,
    required this.isDark,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final value =
        selectedLocale == 'en_US'
            ? 'en_US'
            : 'ar_JO';

    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF142723)
            : Colors.white,
        borderRadius:
            BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.translate_rounded,
            color: Color(0xFF34D399),
            size: 21,
          ),

          const SizedBox(width: 10),

          Expanded(
            child:
                DropdownButtonHideUnderline(
              child:
                  DropdownButton<String>(
                value: value,
                isExpanded: true,
                dropdownColor: isDark
                    ? const Color(
                        0xFF142723,
                      )
                    : Colors.white,
                items: [
                  DropdownMenuItem(
                    value: 'ar_JO',
                    child: Text(
                      'العربية',
                      style: GoogleFonts
                          .ibmPlexSansArabic(
                        color: isDark
                            ? AppColors.darkText
                            : AppColors.lightText,
                      ),
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'en_US',
                    child: Text(
                      'English',
                      style: GoogleFonts
                          .ibmPlexSansArabic(
                        color: isDark
                            ? AppColors.darkText
                            : AppColors.lightText,
                      ),
                    ),
                  ),
                ],
                onChanged: enabled
                    ? (value) {
                        if (value != null) {
                          onChanged(value);
                        }
                      }
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =====================================================
// EDITABLE VOICE TEXT
// =====================================================

class _EditableVoiceTextCard
    extends StatefulWidget {
  final String text;
  final bool isListening;
  final bool isDark;
  final ValueChanged<String> onChanged;

  const _EditableVoiceTextCard({
    required this.text,
    required this.isListening,
    required this.isDark,
    required this.onChanged,
  });

  @override
  State<_EditableVoiceTextCard>
      createState() =>
          _EditableVoiceTextCardState();
}

class _EditableVoiceTextCardState
    extends State<_EditableVoiceTextCard> {
  late final TextEditingController
      _controller;

  final FocusNode _focusNode =
      FocusNode();

  @override
  void initState() {
    super.initState();

    _controller =
        TextEditingController(
      text: widget.text,
    );
  }

  @override
  void didUpdateWidget(
    covariant _EditableVoiceTextCard
        oldWidget,
  ) {
    super.didUpdateWidget(oldWidget);

    if (!_focusNode.hasFocus &&
        widget.text !=
            oldWidget.text &&
        _controller.text !=
            widget.text) {
      _controller.value =
          TextEditingValue(
        text: widget.text,
        selection:
            TextSelection.collapsed(
          offset:
              widget.text.length,
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.fromLTRB(
        14,
        9,
        8,
        9,
      ),
      decoration: BoxDecoration(
        color: widget.isDark
            ? const Color(0xFF142723)
            : Colors.white,
        borderRadius:
            BorderRadius.circular(17),
        border: Border.all(
          color: widget.isListening
              ? const Color(0xFF34D399)
                  .withOpacity(0.40)
              : const Color(0xFF34D399)
                  .withOpacity(0.15),
        ),
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Padding(
            padding:
                const EdgeInsets.only(
              top: 12,
            ),
            child: Icon(
              widget.isListening
                  ? Icons
                      .graphic_eq_rounded
                  : Icons.mic_rounded,
              color:
                  const Color(0xFF34D399),
              size: 21,
            ),
          ),

          const SizedBox(width: 10),

          Expanded(
            child: TextField(
              controller:
                  _controller,
              focusNode:
                  _focusNode,
              minLines: 2,
              maxLines: 6,
              onChanged:
                  widget.onChanged,
              style: GoogleFonts
                  .ibmPlexSansArabic(
                color: widget.isDark
                    ? AppColors.darkText
                    : AppColors.lightText,
                fontSize: 12,
                height: 1.5,
              ),
              decoration:
                  InputDecoration(
                hintText:
                    'Review and edit the recognized text',
                hintStyle: GoogleFonts
                    .ibmPlexSansArabic(
                  color: widget.isDark
                      ? AppColors.darkSubText
                      : AppColors.lightSubText,
                  fontSize: 11,
                ),
                border:
                    InputBorder.none,
                contentPadding:
                    const EdgeInsets
                        .symmetric(
                  vertical: 7,
                ),
              ),
            ),
          ),

          IconButton(
            onPressed: () {
              _focusNode
                  .requestFocus();

              _controller.selection =
                  TextSelection
                      .collapsed(
                offset: _controller
                    .text.length,
              );
            },
            icon: const Icon(
              Icons.edit_outlined,
              color:
                  Color(0xFFF4C95D),
              size: 19,
            ),
          ),
        ],
      ),
    );
  }
}

// =====================================================
// ANALYZE BUTTON
// =====================================================

class _AnalyzeVoiceButton
    extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onPressed;

  const _AnalyzeVoiceButton({
    required this.isLoading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 51,
      child: ElevatedButton.icon(
        onPressed:
            isLoading ? null : onPressed,
        icon: const Icon(
          Icons.auto_awesome_rounded,
        ),
        label: Text(
          'Analyze Expense',
          style:
              GoogleFonts.ibmPlexSansArabic(
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
        style:
            ElevatedButton.styleFrom(
          backgroundColor:
              const Color(0xFF34D399),
          foregroundColor:
              const Color(0xFF09231E),
          elevation: 0,
          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(15),
          ),
        ),
      ),
    );
  }
}

// =====================================================
// CONTROLS
// =====================================================

class _InputControls
    extends StatelessWidget {
  final bool isDark;
  final bool isListening;
  final bool isCameraReady;
  final bool isCapturing;

  final VoidCallback
      onGalleryPressed;

  final VoidCallback
      onCameraPressed;

  final VoidCallback
      onVoicePressed;

  const _InputControls({
    required this.isDark,
    required this.isListening,
    required this.isCameraReady,
    required this.isCapturing,
    required this.onGalleryPressed,
    required this.onCameraPressed,
    required this.onVoicePressed,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment:
          MainAxisAlignment.center,
      children: [
        _SmallButton(
          icon: Icons
              .photo_library_outlined,
          isDark: isDark,
          onPressed:
              onGalleryPressed,
        ),

        const SizedBox(width: 18),

        _CaptureButton(
          enabled: isCameraReady &&
              !isCapturing,
          onPressed:
              onCameraPressed,
        ),

        const SizedBox(width: 18),

        _SmallButton(
          icon: isListening
              ? Icons.stop_rounded
              : Icons.mic_none_rounded,
          isDark: isDark,
          isActive: isListening,
          onPressed:
              onVoicePressed,
        ),
      ],
    );
  }
}

class _SmallButton
    extends StatelessWidget {
  final IconData icon;
  final bool isDark;
  final bool isActive;
  final VoidCallback onPressed;

  const _SmallButton({
    required this.icon,
    required this.isDark,
    required this.onPressed,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onPressed,
        customBorder:
            const CircleBorder(),
        child: AnimatedContainer(
          duration:
              const Duration(
            milliseconds: 180,
          ),
          width: 51,
          height: 51,
          decoration: BoxDecoration(
            color: isActive
                ? const Color(
                    0xFFFF6B6B,
                  )
                : isDark
                    ? const Color(
                        0xFF17302A,
                      )
                    : Colors.white,
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: isActive
                ? Colors.white
                : const Color(
                    0xFFF4C95D,
                  ),
          ),
        ),
      ),
    );
  }
}

class _CaptureButton
    extends StatelessWidget {
  final bool enabled;
  final VoidCallback onPressed;

  const _CaptureButton({
    required this.enabled,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap:
          enabled ? onPressed : null,
      child: Opacity(
        opacity:
            enabled ? 1 : 0.5,
        child: Container(
          width: 72,
          height: 72,
          padding:
              const EdgeInsets.all(5),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white,
              width: 4,
            ),
          ),
          child: Container(
            decoration:
                const BoxDecoration(
              color:
                  Color(0xFF2CC9A1),
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}

// =====================================================
// FLASH
// =====================================================

class _FlashButton
    extends StatelessWidget {
  final bool isEnabled;
  final VoidCallback onPressed;

  const _FlashButton({
    required this.isEnabled,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color:
          Colors.black.withOpacity(0.35),
      borderRadius:
          BorderRadius.circular(13),
      child: InkWell(
        onTap: onPressed,
        borderRadius:
            BorderRadius.circular(13),
        child: SizedBox(
          width: 42,
          height: 42,
          child: Icon(
            isEnabled
                ? Icons.flash_on_rounded
                : Icons.flash_off_rounded,
            color: isEnabled
                ? const Color(
                    0xFFF4C95D,
                  )
                : Colors.white,
          ),
        ),
      ),
    );
  }
}

// =====================================================
// SCANNER LINE
// =====================================================

class _ScannerLine
    extends StatefulWidget {
  const _ScannerLine();

  @override
  State<_ScannerLine>
      createState() =>
          _ScannerLineState();
}

class _ScannerLineState
    extends State<_ScannerLine>
    with
        SingleTickerProviderStateMixin {
  late final AnimationController
      _controller;

  late final Animation<double>
      _animation;

  @override
  void initState() {
    super.initState();

    _controller =
        AnimationController(
      vsync: this,
      duration:
          const Duration(seconds: 2),
    );

    _animation =
        Tween<double>(
      begin: -105,
      end: 105,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );

    _controller.repeat(
      reverse: true,
    );
  }

  @override
  void dispose() {
    _controller.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation:
          _animation,
      builder: (
        context,
        child,
      ) {
        return Transform.translate(
          offset: Offset(
            0,
            _animation.value,
          ),
          child: child,
        );
      },
      child: Container(
        height: 2,
        margin:
            const EdgeInsets.symmetric(
          horizontal: 18,
        ),
        decoration: BoxDecoration(
          color:
              const Color(0xFF34D399),
          boxShadow: [
            BoxShadow(
              color: const Color(
                0xFF34D399,
              ).withOpacity(0.8),
              blurRadius: 13,
              spreadRadius: 2,
            ),
          ],
        ),
      ),
    );
  }
}

// =====================================================
// CORNERS
// =====================================================

class _ScannerCorner
    extends StatelessWidget {
  final bool top;
  final bool left;

  const _ScannerCorner({
    required this.top,
    required this.left,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 30,
      height: 30,
      child: CustomPaint(
        painter:
            _ScannerCornerPainter(
          top: top,
          left: left,
        ),
      ),
    );
  }
}

class _ScannerCornerPainter
    extends CustomPainter {
  final bool top;
  final bool left;

  const _ScannerCornerPainter({
    required this.top,
    required this.left,
  });

  @override
  void paint(
    Canvas canvas,
    Size size,
  ) {
    final paint = Paint()
      ..color =
          const Color(0xFF2BE4B0)
      ..strokeWidth = 3
      ..style =
          PaintingStyle.stroke
      ..strokeCap =
          StrokeCap.round;

    final path = Path();

    if (top && left) {
      path
        ..moveTo(
          0,
          size.height,
        )
        ..lineTo(0, 0)
        ..lineTo(
          size.width,
          0,
        );
    } else if (top && !left) {
      path
        ..moveTo(0, 0)
        ..lineTo(
          size.width,
          0,
        )
        ..lineTo(
          size.width,
          size.height,
        );
    } else if (!top && left) {
      path
        ..moveTo(0, 0)
        ..lineTo(
          0,
          size.height,
        )
        ..lineTo(
          size.width,
          size.height,
        );
    } else {
      path
        ..moveTo(
          0,
          size.height,
        )
        ..lineTo(
          size.width,
          size.height,
        )
        ..lineTo(
          size.width,
          0,
        );
    }

    canvas.drawPath(
      path,
      paint,
    );
  }

  @override
  bool shouldRepaint(
    covariant CustomPainter
        oldDelegate,
  ) {
    return false;
  }
}

// =====================================================
// CAMERA ERROR
// =====================================================

class _CameraErrorView
    extends StatelessWidget {
  final String error;
  final bool isDark;
  final VoidCallback onRetry;

  const _CameraErrorView({
    required this.error,
    required this.isDark,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.all(24),
      child: Center(
        child: Column(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            const Icon(
              Icons.camera_alt_outlined,
              color:
                  Color(0xFFFF6B6B),
              size: 42,
            ),

            const SizedBox(height: 12),

            Text(
              'Could not open the camera',
              textAlign:
                  TextAlign.center,
              style: GoogleFonts
                  .ibmPlexSansArabic(
                color: isDark
                    ? AppColors.darkText
                    : AppColors.lightText,
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            const SizedBox(height: 7),

            Text(
              error,
              textAlign:
                  TextAlign.center,
              style: GoogleFonts
                  .ibmPlexSansArabic(
                color: isDark
                    ? AppColors.darkSubText
                    : AppColors.lightSubText,
                fontSize: 10,
              ),
            ),

            const SizedBox(height: 15),

            ElevatedButton(
              onPressed:
                  onRetry,
              child: const Text(
                'Try Again',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =====================================================
// ERROR
// =====================================================

class _ErrorCard
    extends StatelessWidget {
  final String message;
  final VoidCallback onClose;

  const _ErrorCard({
    required this.message,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(
          0xFFFF6B6B,
        ).withOpacity(0.11),
        borderRadius:
            BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline,
            color:
                Color(0xFFFF6B6B),
          ),

          const SizedBox(width: 9),

          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color:
                    Color(0xFFFF6B6B),
              ),
            ),
          ),

          IconButton(
            onPressed: onClose,
            icon: const Icon(
              Icons.close_rounded,
              color:
                  Color(0xFFFF6B6B),
              size: 18,
            ),
          ),
        ],
      ),
    );
  }
}

// =====================================================
// PROCESSING
// =====================================================

class _ProcessingOverlay
    extends StatelessWidget {
  final bool isDark;

  const _ProcessingOverlay({
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color:
            Colors.black.withOpacity(0.55),
        alignment: Alignment.center,
        child: Container(
          margin:
              const EdgeInsets.symmetric(
            horizontal: 50,
          ),
          padding:
              const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(
                    0xFF142723,
                  )
                : Colors.white,
            borderRadius:
                BorderRadius.circular(21),
          ),
          child: Column(
            mainAxisSize:
                MainAxisSize.min,
            children: [
              const CircularProgressIndicator(
                color:
                    Color(0xFF34D399),
              ),

              const SizedBox(height: 15),

              Text(
                'Analyzing expense...',
                style: GoogleFonts
                    .ibmPlexSansArabic(
                  color: isDark
                      ? AppColors.darkText
                      : AppColors.lightText,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}