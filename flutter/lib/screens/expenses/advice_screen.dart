import 'package:alpha_app/core/utils/app_colors.dart';
import 'package:alpha_app/core/utils/device.dart';
import 'package:alpha_app/providers/themeprovider.dart';
import 'package:alpha_app/widgets/custom_textfield.dart';
import 'package:alpha_app/widgets/option_chip.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class AdviceScreen extends StatefulWidget {
  const AdviceScreen({
    super.key,
  });

  @override
  State<AdviceScreen> createState() =>
      _AdviceScreenState();
}

class _AdviceScreenState extends State<AdviceScreen> {
  final TextEditingController _itemController =
      TextEditingController();

  final TextEditingController _amountController =
      TextEditingController();

  final TextEditingController _noteController =
      TextEditingController();

  String? _planningType;
  String? _expenseType;
  String? _canDelay;
  String? _hasAlternative;
  String? _fundingSource;

  bool _isAnalyzing = false;
  bool _showResult = false;

  String? _errorMessage;
  String _resultTitle = '';
  String _resultMessage = '';
  AdviceLevel _adviceLevel = AdviceLevel.safe;

  double get _amount {
    return double.tryParse(
          _amountController.text
              .replaceAll(',', '')
              .trim(),
        ) ??
        0;
  }

  bool get _isValid {
    return _itemController.text.trim().isNotEmpty &&
        _amount > 0 &&
        _planningType != null &&
        _expenseType != null &&
        _canDelay != null &&
        _hasAlternative != null &&
        _fundingSource != null;
  }

  @override
  void dispose() {
    _itemController.dispose();
    _amountController.dispose();
    _noteController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark =
        context.watch<Themeprovider>().isDark;

    final double screenW =
        Device.width(context);

    final double screenH =
        Device.height(context);

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.darkBackground
          : AppColors.lightBackground,
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              physics:
                  const BouncingScrollPhysics(),
              padding: EdgeInsets.symmetric(
                horizontal: screenW * 0.055,
              ),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: screenH * 0.022,
                  ),

                  _buildHeader(
                    isDark: isDark,
                    screenW: screenW,
                  ),

                  SizedBox(
                    height: screenH * 0.018,
                  ),

                  _WelcomeCard(
                    isDark: isDark,
                    screenW: screenW,
                  ),

                  SizedBox(
                    height: screenH * 0.027,
                  ),

                  _SectionTitle(
                    title:
                        'What are you planning to buy?',
                    isDark: isDark,
                    screenW: screenW,
                  ),

                  SizedBox(
                    height: screenH * 0.01,
                  ),

                  CustomTextfield(
                    controller: _itemController,
                    hint:
                        'Example: Laptop, phone or trip',
                    icon:
                        Icons.shopping_bag_outlined,
                    type: TextFieldType.name,
                    onChanged: (_) {
                      _clearResult();
                    },
                  ),

                  SizedBox(
                    height: screenH * 0.022,
                  ),

                  _SectionTitle(
                    title: 'Expected cost',
                    isDark: isDark,
                    screenW: screenW,
                  ),

                  SizedBox(
                    height: screenH * 0.01,
                  ),

                  CustomTextfield(
                    controller:
                        _amountController,
                    hint: 'Enter amount',
                    icon:
                        Icons.payments_outlined,
                    type: TextFieldType.number,
                    suffix: const Padding(
                      padding:
                          EdgeInsets.all(12),
                      child: Text('JOD'),
                    ),
                    onChanged: (_) {
                      _clearResult();
                    },
                  ),

                  SizedBox(
                    height: screenH * 0.024,
                  ),

                  _SectionTitle(
                    title:
                        'Is this expense planned or urgent?',
                    isDark: isDark,
                    screenW: screenW,
                  ),

                  SizedBox(
                    height: screenH * 0.012,
                  ),

                  OptionChip(
                    items: const [
                      'Planned',
                      'Urgent',
                    ],
                    selected: _planningType,
                    onTap: (value) {
                      setState(() {
                        _planningType = value;
                        _showResult = false;
                        _errorMessage = null;
                      });
                    },
                  ),

                  SizedBox(
                    height: screenH * 0.024,
                  ),

                  _SectionTitle(
                    title:
                        'Is it a need or a want?',
                    isDark: isDark,
                    screenW: screenW,
                  ),

                  SizedBox(
                    height: screenH * 0.012,
                  ),

                  OptionChip(
                    items: const [
                      'Need',
                      'Want',
                    ],
                    selected: _expenseType,
                    onTap: (value) {
                      setState(() {
                        _expenseType = value;
                        _showResult = false;
                        _errorMessage = null;
                      });
                    },
                  ),

                  SizedBox(
                    height: screenH * 0.024,
                  ),

                  _SectionTitle(
                    title:
                        'Can the purchase wait for a few days?',
                    isDark: isDark,
                    screenW: screenW,
                  ),

                  SizedBox(
                    height: screenH * 0.012,
                  ),

                  OptionChip(
                    items: const [
                      'Yes',
                      'No',
                    ],
                    selected: _canDelay,
                    onTap: (value) {
                      setState(() {
                        _canDelay = value;
                        _showResult = false;
                        _errorMessage = null;
                      });
                    },
                  ),

                  SizedBox(
                    height: screenH * 0.024,
                  ),

                  _SectionTitle(
                    title:
                        'Did you check a cheaper alternative?',
                    isDark: isDark,
                    screenW: screenW,
                  ),

                  SizedBox(
                    height: screenH * 0.012,
                  ),

                  OptionChip(
                    items: const [
                      'Yes',
                      'Not yet',
                    ],
                    selected: _hasAlternative,
                    onTap: (value) {
                      setState(() {
                        _hasAlternative = value;
                        _showResult = false;
                        _errorMessage = null;
                      });
                    },
                  ),

                  SizedBox(
                    height: screenH * 0.024,
                  ),

                  _SectionTitle(
                    title:
                        'How would you fund it?',
                    isDark: isDark,
                    screenW: screenW,
                  ),

                  SizedBox(
                    height: screenH * 0.012,
                  ),

                  OptionChip(
                    items: const [
                      'Available Balance',
                      'Savings',
                      'Emergency Fund',
                      'Installments',
                    ],
                    selected: _fundingSource,
                    onTap: (value) {
                      setState(() {
                        _fundingSource = value;
                        _showResult = false;
                        _errorMessage = null;
                      });
                    },
                  ),

                  SizedBox(
                    height: screenH * 0.024,
                  ),

                  _SectionTitle(
                    title:
                        'Additional details (optional)',
                    isDark: isDark,
                    screenW: screenW,
                  ),

                  SizedBox(
                    height: screenH * 0.01,
                  ),

                  CustomTextfield(
                    controller: _noteController,
                    hint:
                        'Tell Alpha anything relevant',
                    icon: Icons.notes_rounded,
                    type: TextFieldType.name,
                    onChanged: (_) {
                      _clearResult();
                    },
                  ),

                  if (_errorMessage != null) ...[
                    SizedBox(
                      height: screenH * 0.018,
                    ),

                    _ErrorCard(
                      message: _errorMessage!,
                      onClose: () {
                        setState(() {
                          _errorMessage = null;
                        });
                      },
                    ),
                  ],

                  SizedBox(
                    height: screenH * 0.027,
                  ),

                  SizedBox(
                    width: double.infinity,
                    height: screenH * 0.065,
                    child: ElevatedButton.icon(
                      onPressed: _isAnalyzing
                          ? null
                          : _analyzePurchase,
                      icon: _isAnalyzing
                          ? const SizedBox.shrink()
                          : const Icon(
                              Icons
                                  .auto_awesome_rounded,
                            ),
                      label: _isAnalyzing
                          ? const SizedBox(
                              width: 23,
                              height: 23,
                              child:
                                  CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              'Analyze Purchase',
                              style: GoogleFonts
                                  .ibmPlexSansArabic(
                                fontSize:
                                    screenW * 0.042,
                                fontWeight:
                                    FontWeight.bold,
                              ),
                            ),
                      style:
                          ElevatedButton.styleFrom(
                        backgroundColor: isDark
                            ? AppColors.darkPrimary
                            : AppColors.lightPrimary,
                        foregroundColor:
                            AppColors.darkBorder,
                        disabledBackgroundColor:
                            (isDark
                                    ? AppColors
                                        .darkPrimary
                                    : AppColors
                                        .lightPrimary)
                                .withOpacity(0.45),
                        elevation: 0,
                        shape:
                            RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(
                            13,
                          ),
                        ),
                      ),
                    ),
                  ),

                  if (_showResult) ...[
                    SizedBox(
                      height: screenH * 0.025,
                    ),

                    _AdviceResultCard(
                      title: _resultTitle,
                      message: _resultMessage,
                      level: _adviceLevel,
                      isDark: isDark,
                      screenW: screenW,
                      amount: _amount,
                    ),

                    SizedBox(
                      height: screenH * 0.018,
                    ),

                    _ResultActions(
                      isDark: isDark,
                      screenW: screenW,
                      onReview: () {
                        setState(() {
                          _showResult = false;
                        });
                      },
                      onClose: () {
                        Navigator.pop(context);
                      },
                    ),
                  ],

                  SizedBox(
                    height: screenH * 0.035,
                  ),
                ],
              ),
            ),

            if (_isAnalyzing)
              Positioned.fill(
                child: AbsorbPointer(
                  child: Container(
                    color:
                        Colors.black.withOpacity(
                      0.10,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader({
    required bool isDark,
    required double screenW,
  }) {
    return Row(
      children: [
        InkWell(
          onTap: () {
            Navigator.pop(context);
          },
          borderRadius:
              BorderRadius.circular(12),
          child: Container(
            width: screenW * 0.11,
            height: screenW * 0.11,
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF203330)
                  : Colors.white,
              borderRadius:
                  BorderRadius.circular(12),
              border: Border.all(
                color: isDark
                    ? Colors.white
                        .withOpacity(0.04)
                    : Colors.black
                        .withOpacity(0.05),
              ),
            ),
            child: Icon(
              Icons.arrow_back_ios_new_rounded,
              color: isDark
                  ? AppColors.darkText
                  : AppColors.lightText,
              size: screenW * 0.05,
            ),
          ),
        ),

        SizedBox(
          width: screenW * 0.035,
        ),

        Expanded(
          child: Text(
            'Ask Alpha',
            style:
                GoogleFonts.ibmPlexSansArabic(
              color: isDark
                  ? AppColors.darkText
                  : AppColors.lightText,
              fontSize: screenW * 0.065,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _analyzePurchase() async {
    FocusScope.of(context).unfocus();

    if (!_isValid) {
      setState(() {
        _errorMessage =
            'Please complete all required fields before requesting advice.';
        _showResult = false;
      });

      return;
    }

    setState(() {
      _isAnalyzing = true;
      _errorMessage = null;
      _showResult = false;
    });

    await Future.delayed(
      const Duration(
        milliseconds: 900,
      ),
    );

    if (!mounted) return;

    _createAdviceResult();

    setState(() {
      _isAnalyzing = false;
      _showResult = true;
    });
  }

  void _createAdviceResult() {
    int riskScore = 0;

    if (_expenseType == 'Want') {
      riskScore += 3;
    }

    if (_planningType == 'Urgent') {
      riskScore += 1;
    }

    if (_canDelay == 'Yes') {
      riskScore += 1;
    }

    if (_hasAlternative == 'Not yet') {
      riskScore += 2;
    }

    if (_fundingSource == 'Savings') {
      riskScore += 2;
    }

    if (_fundingSource == 'Installments') {
      riskScore += 3;
    }

    if (_fundingSource ==
        'Emergency Fund') {
      if (_planningType == 'Urgent' &&
          _expenseType == 'Need') {
        riskScore -= 1;
      } else {
        riskScore += 4;
      }
    }

    if (_amount >= 500) {
      riskScore += 3;
    } else if (_amount >= 200) {
      riskScore += 2;
    } else if (_amount >= 100) {
      riskScore += 1;
    }

    final String item =
        _itemController.text.trim();

    if (riskScore >= 8) {
      _adviceLevel = AdviceLevel.highRisk;
      _resultTitle =
          'Alpha recommends waiting';

      _resultMessage =
          'Buying $item now may place noticeable pressure on your available balance. '
          'The purchase is classified as ${_expenseType!.toLowerCase()}, '
          'and the selected funding method ($_fundingSource) may affect your future plans. '
          'Compare alternatives and delay the decision for at least two days before proceeding.';

      return;
    }

    if (riskScore >= 4) {
      _adviceLevel =
          AdviceLevel.caution;

      _resultTitle =
          'Review before purchasing';

      _resultMessage =
          'The purchase may be possible, but Alpha recommends reviewing the price and its effect on your remaining monthly balance. '
          'Check a cheaper option and avoid using savings or installments unless the purchase is important.';

      return;
    }

    _adviceLevel = AdviceLevel.safe;
    _resultTitle =
        'The purchase looks manageable';

    _resultMessage =
        'Based on the information provided, purchasing $item appears reasonably manageable. '
        'It is classified as ${_expenseType!.toLowerCase()} and the funding method is $_fundingSource. '
        'Confirm that the amount fits within your actual available balance before completing the purchase.';
  }

  void _clearResult() {
    if (_showResult ||
        _errorMessage != null) {
      setState(() {
        _showResult = false;
        _errorMessage = null;
      });
    }
  }
}

enum AdviceLevel {
  safe,
  caution,
  highRisk,
}

// =====================================================
// WELCOME CARD
// =====================================================

class _WelcomeCard extends StatelessWidget {
  final bool isDark;
  final double screenW;

  const _WelcomeCard({
    required this.isDark,
    required this.screenW,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkSecondary
                .withOpacity(0.10)
            : AppColors.lightSecondary
                .withOpacity(0.10),
        borderRadius:
            BorderRadius.circular(18),
        border: Border.all(
          color: const Color(
            0xFF14B8A6,
          ).withOpacity(0.14),
        ),
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(
                0xFF14B8A6,
              ).withOpacity(0.13),
              borderRadius:
                  BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons
                  .psychology_alt_outlined,
              color:
                  Color(0xFF14B8A6),
              size: 26,
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  'Before you spend',
                  style: GoogleFonts
                      .ibmPlexSansArabic(
                    color: const Color(
                      0xFF14B8A6,
                    ),
                    fontSize:
                        screenW * 0.039,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  'Answer a few questions and Alpha will simulate the effect of the purchase. Nothing will be saved as a real expense.',
                  style: GoogleFonts
                      .ibmPlexSansArabic(
                    color: isDark
                        ? AppColors.darkText
                        : AppColors.lightText,
                    fontSize:
                        screenW * 0.031,
                    height: 1.55,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =====================================================
// SECTION TITLE
// =====================================================

class _SectionTitle extends StatelessWidget {
  final String title;
  final bool isDark;
  final double screenW;

  const _SectionTitle({
    required this.title,
    required this.isDark,
    required this.screenW,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style:
          GoogleFonts.ibmPlexSansArabic(
        color: isDark
            ? AppColors.darkSubText
            : AppColors.lightSubText,
        fontSize: screenW * 0.039,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}

// =====================================================
// ERROR CARD
// =====================================================

class _ErrorCard extends StatelessWidget {
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
          const EdgeInsets.only(
        left: 13,
        top: 8,
        bottom: 8,
      ),
      decoration: BoxDecoration(
        color: const Color(
          0xFFFF6B6B,
        ).withOpacity(0.10),
        borderRadius:
            BorderRadius.circular(14),
        border: Border.all(
          color: const Color(
            0xFFFF6B6B,
          ).withOpacity(0.18),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
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
// RESULT CARD
// =====================================================

class _AdviceResultCard
    extends StatelessWidget {
  final String title;
  final String message;
  final AdviceLevel level;
  final bool isDark;
  final double screenW;
  final double amount;

  const _AdviceResultCard({
    required this.title,
    required this.message,
    required this.level,
    required this.isDark,
    required this.screenW,
    required this.amount,
  });

  Color get _color {
    switch (level) {
      case AdviceLevel.safe:
        return const Color(0xFF34D399);

      case AdviceLevel.caution:
        return const Color(0xFFF4C95D);

      case AdviceLevel.highRisk:
        return const Color(0xFFFF6B6B);
    }
  }

  IconData get _icon {
    switch (level) {
      case AdviceLevel.safe:
        return Icons
            .check_circle_outline_rounded;

      case AdviceLevel.caution:
        return Icons
            .warning_amber_rounded;

      case AdviceLevel.highRisk:
        return Icons
            .error_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _color.withOpacity(
          isDark ? 0.10 : 0.08,
        ),
        borderRadius:
            BorderRadius.circular(20),
        border: Border.all(
          color: _color.withOpacity(0.28),
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color:
                      _color.withOpacity(0.14),
                  borderRadius:
                      BorderRadius.circular(14),
                ),
                child: Icon(
                  _icon,
                  color: _color,
                  size: 25,
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Alpha Advice',
                      style: GoogleFonts
                          .ibmPlexSansArabic(
                        color: _color,
                        fontSize:
                            screenW * 0.031,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 2),

                    Text(
                      title,
                      style: GoogleFonts
                          .ibmPlexSansArabic(
                        color: isDark
                            ? AppColors.darkText
                            : AppColors.lightText,
                        fontSize:
                            screenW * 0.043,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          Container(
            width: double.infinity,
            padding:
                const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF172624)
                  : Colors.white,
              borderRadius:
                  BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Text(
                  'Simulated amount',
                  style: GoogleFonts
                      .ibmPlexSansArabic(
                    color: isDark
                        ? AppColors.darkSubText
                        : AppColors.lightSubText,
                    fontSize:
                        screenW * 0.03,
                  ),
                ),

                const Spacer(),

                Text(
                  '${amount.toStringAsFixed(2)} JOD',
                  style: GoogleFonts
                      .ibmPlexSansArabic(
                    color: _color,
                    fontSize:
                        screenW * 0.038,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          Text(
            message,
            style:
                GoogleFonts.ibmPlexSansArabic(
              color: isDark
                  ? AppColors.darkText
                  : AppColors.lightText,
              fontSize:
                  screenW * 0.033,
              height: 1.65,
            ),
          ),

          const SizedBox(height: 13),

          Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.info_outline_rounded,
                color: _color,
                size: 17,
              ),

              const SizedBox(width: 7),

              Expanded(
                child: Text(
                  'This is a simulation only. No expense was added and your balance was not changed.',
                  style: GoogleFonts
                      .ibmPlexSansArabic(
                    color: isDark
                        ? AppColors.darkSubText
                        : AppColors.lightSubText,
                    fontSize:
                        screenW * 0.027,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// =====================================================
// RESULT ACTIONS
// =====================================================

class _ResultActions extends StatelessWidget {
  final bool isDark;
  final double screenW;
  final VoidCallback onReview;
  final VoidCallback onClose;

  const _ResultActions({
    required this.isDark,
    required this.screenW,
    required this.onReview,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: onReview,
            style:
                OutlinedButton.styleFrom(
              foregroundColor: isDark
                  ? AppColors.darkPrimary
                  : AppColors.lightPrimary,
              side: BorderSide(
                color: isDark
                    ? AppColors.darkPrimary
                    : AppColors.lightPrimary,
              ),
              padding:
                  const EdgeInsets.symmetric(
                vertical: 13,
              ),
              shape:
                  RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(13),
              ),
            ),
            child: Text(
              'Review Answers',
              style: GoogleFonts
                  .ibmPlexSansArabic(
                fontSize:
                    screenW * 0.031,
                fontWeight:
                    FontWeight.bold,
              ),
            ),
          ),
        ),

        const SizedBox(width: 12),

        Expanded(
          child: ElevatedButton(
            onPressed: onClose,
            style:
                ElevatedButton.styleFrom(
              backgroundColor: isDark
                  ? AppColors.darkPrimary
                  : AppColors.lightPrimary,
              foregroundColor:
                  AppColors.darkBorder,
              elevation: 0,
              padding:
                  const EdgeInsets.symmetric(
                vertical: 13,
              ),
              shape:
                  RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(13),
              ),
            ),
            child: Text(
              'Done',
              style: GoogleFonts
                  .ibmPlexSansArabic(
                fontSize:
                    screenW * 0.031,
                fontWeight:
                    FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }
}