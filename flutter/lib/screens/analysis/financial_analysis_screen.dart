import 'package:alpha_app/core/utils/app_colors.dart';
import 'package:alpha_app/core/utils/device.dart';
import 'package:alpha_app/models/financial_analysis_model.dart';
import 'package:alpha_app/providers/financial_analysis_provider.dart';
import 'package:alpha_app/providers/themeprovider.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class FinancialAnalysisScreen extends StatefulWidget {
  const FinancialAnalysisScreen({
    super.key,
  });

  @override
  State<FinancialAnalysisScreen> createState() =>
      _FinancialAnalysisScreenState();
}

class _FinancialAnalysisScreenState
    extends State<FinancialAnalysisScreen> {
  bool _didRequestMockData = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || _didRequestMockData) {
        return;
      }

      _didRequestMockData = true;

      final provider =
          context.read<FinancialAnalysisProvider>();

      // مؤقتًا للعرض والتجربة فقط.
      // عند ربط الباك إند احذفي هذا الجزء.
      if (!provider.hasAnalysis &&
          !provider.isLoading) {
        await provider.loadMockAnalysis();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final analysisProvider =
        context.watch<FinancialAnalysisProvider>();

    final themeProvider =
        context.watch<Themeprovider>();

    final bool isDark =
        themeProvider.isDark;

    final double screenW =
        Device.width(context);

    final double screenH =
        Device.height(context);

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.darkBackground
          : AppColors.lightBackground,
      body: SafeArea(
        child: _buildBody(
          context: context,
          provider: analysisProvider,
          isDark: isDark,
          screenW: screenW,
          screenH: screenH,
        ),
      ),
    );
  }

  Widget _buildBody({
    required BuildContext context,
    required FinancialAnalysisProvider provider,
    required bool isDark,
    required double screenW,
    required double screenH,
  }) {
    if (provider.isLoading &&
        !provider.hasAnalysis) {
      return Center(
        child: CircularProgressIndicator(
          color: isDark
              ? AppColors.darkPrimary
              : AppColors.lightPrimary,
        ),
      );
    }

    if (!provider.hasAnalysis) {
      return _EmptyAnalysisView(
        isDark: isDark,
        screenW: screenW,
        errorMessage: provider.errorMessage,
        onRetry: provider.loadMockAnalysis,
      );
    }

    final FinancialAnalysisModel analysis =
        provider.analysis!;

    return RefreshIndicator(
      onRefresh: () async {
        // لاحقًا: استدعاء API جديد بدل البيانات التجريبية.
        await provider.loadMockAnalysis();
      },
      color: isDark
          ? AppColors.darkPrimary
          : AppColors.lightPrimary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: EdgeInsets.symmetric(
          horizontal: screenW * 0.05,
        ),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: screenH * 0.022,
            ),

            _AnalysisHeader(
              isDark: isDark,
              screenW: screenW,
              analysisDate:
                  provider.analysisTitleDate,
              onBack: () {
                provider.stopAudio();
                Navigator.pop(context);
              },
            ),

            SizedBox(
              height: screenH * 0.025,
            ),

            // ================= AUDIO =================

            _AudioAnalysisCard(
              provider: provider,
              analysis: analysis,
              isDark: isDark,
              screenW: screenW,
            ),

            SizedBox(
              height: screenH * 0.025,
            ),

            // ================= SUMMARY =================

            _SectionHeader(
              icon: Icons.summarize_outlined,
              title: "Analysis Summary",
              color: const Color(0xFF14B8A6),
              isDark: isDark,
              screenW: screenW,
            ),

            SizedBox(
              height: screenH * 0.012,
            ),

            _SummaryCard(
              summary:
                  analysis.content.summary,
              isDark: isDark,
              screenW: screenW,
            ),

            SizedBox(
              height: screenH * 0.025,
            ),

            // ================= METRICS =================

            _SectionHeader(
              icon: Icons.analytics_outlined,
              title: "Financial Indicators",
              color: const Color(0xFFF4C95D),
              isDark: isDark,
              screenW: screenW,
            ),

            SizedBox(
              height: screenH * 0.012,
            ),

            _MetricsSection(
              metrics: analysis.metrics,
              currency:
                  analysis.user.currency,
              isDark: isDark,
              screenW: screenW,
            ),

            SizedBox(
              height: screenH * 0.025,
            ),

            // ================= INSIGHTS =================

            _SectionHeader(
              icon:
                  Icons.lightbulb_outline_rounded,
              title: "Key Insights",
              color: const Color(0xFF4F9CF9),
              isDark: isDark,
              screenW: screenW,
            ),

            SizedBox(
              height: screenH * 0.012,
            ),

            _AnalysisItemsCard(
              items:
                  analysis.content.insights,
              icon: Icons.insights_outlined,
              color:
                  const Color(0xFF4F9CF9),
              isDark: isDark,
              screenW: screenW,
              emptyText:
                  "No insights are available.",
            ),

            SizedBox(
              height: screenH * 0.025,
            ),

            // ================= RECOMMENDATIONS =================

            _SectionHeader(
              icon: Icons.recommend_outlined,
              title: "Recommendations",
              color: const Color(0xFF34D399),
              isDark: isDark,
              screenW: screenW,
            ),

            SizedBox(
              height: screenH * 0.012,
            ),

            _AnalysisItemsCard(
              items: analysis
                  .content.recommendations,
              icon:
                  Icons.check_circle_outline_rounded,
              color:
                  const Color(0xFF34D399),
              isDark: isDark,
              screenW: screenW,
              emptyText:
                  "No recommendations are available.",
            ),

            if (provider.errorMessage !=
                null) ...[
              SizedBox(
                height: screenH * 0.02,
              ),

              _ErrorCard(
                message:
                    provider.errorMessage!,
                onClose:
                    provider.clearError,
              ),
            ],

            SizedBox(
              height: screenH * 0.03,
            ),

            SizedBox(
              width: double.infinity,
              height: screenH * 0.065,
              child: ElevatedButton(
                onPressed: () async {
                  await provider.stopAudio();

                  if (!context.mounted) {
                    return;
                  }

                  Navigator.pop(context);
                },
                style:
                    ElevatedButton.styleFrom(
                  backgroundColor: isDark
                      ? AppColors.darkPrimary
                      : AppColors.lightPrimary,
                  foregroundColor:
                      AppColors.darkBorder,
                  elevation: 0,
                  shape:
                      RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(
                      12,
                    ),
                  ),
                ),
                child: Text(
                  "Done",
                  style: GoogleFonts
                      .ibmPlexSansArabic(
                    fontSize:
                        screenW * 0.045,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
              ),
            ),

            SizedBox(
              height: screenH * 0.03,
            ),
          ],
        ),
      ),
    );
  }
}

// =====================================================
// HEADER
// =====================================================

class _AnalysisHeader extends StatelessWidget {
  final bool isDark;
  final double screenW;
  final String analysisDate;
  final VoidCallback onBack;

  const _AnalysisHeader({
    required this.isDark,
    required this.screenW,
    required this.analysisDate,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        InkWell(
          onTap: onBack,
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
                    ? Colors.white.withOpacity(
                        0.04,
                      )
                    : Colors.black.withOpacity(
                        0.05,
                      ),
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
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                "Alpha Analysis",
                style: GoogleFonts
                    .ibmPlexSansArabic(
                  color: isDark
                      ? AppColors.darkText
                      : AppColors.lightText,
                  fontSize: screenW * 0.062,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),

              if (analysisDate.isNotEmpty)
                Text(
                  "Analysis as of $analysisDate",
                  style: GoogleFonts
                      .ibmPlexSansArabic(
                    color: isDark
                        ? AppColors.darkSubText
                        : AppColors.lightSubText,
                    fontSize:
                        screenW * 0.029,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// =====================================================
// AUDIO CARD
// =====================================================

class _AudioAnalysisCard extends StatelessWidget {
  final FinancialAnalysisProvider provider;
  final FinancialAnalysisModel analysis;
  final bool isDark;
  final double screenW;

  const _AudioAnalysisCard({
    required this.provider,
    required this.analysis,
    required this.isDark,
    required this.screenW,
  });

  @override
  Widget build(BuildContext context) {
    const Color accentColor =
        Color(0xFF34D399);

    final double sliderValue =
        provider.audioProgress.clamp(
      0.0,
      1.0,
    );

    return Material(
      color: isDark
          ? const Color(0xFF172624)
          : Colors.white,
      borderRadius:
          BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius:
              BorderRadius.circular(22),
          border: Border.all(
            color:
                accentColor.withOpacity(0.14),
          ),
          boxShadow: isDark
              ? null
              : [
                  BoxShadow(
                    color: Colors.black
                        .withOpacity(0.04),
                    blurRadius: 16,
                    offset:
                        const Offset(0, 7),
                  ),
                ],
        ),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color:
                        accentColor.withOpacity(
                      0.13,
                    ),
                    borderRadius:
                        BorderRadius.circular(
                      16,
                    ),
                  ),
                  child: const Icon(
                    Icons.graphic_eq_rounded,
                    color: accentColor,
                    size: 28,
                  ),
                ),

                const SizedBox(width: 13),

                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Listen to Alpha",
                        style: GoogleFonts
                            .ibmPlexSansArabic(
                          color: isDark
                              ? AppColors.darkText
                              : AppColors.lightText,
                          fontSize:
                              screenW * 0.044,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 3),

                      Text(
                        provider.hasAudio
                            ? "Voice financial analysis"
                            : "Audio is unavailable",
                        style: GoogleFonts
                            .ibmPlexSansArabic(
                          color: isDark
                              ? AppColors.darkSubText
                              : AppColors.lightSubText,
                          fontSize:
                              screenW * 0.029,
                        ),
                      ),
                    ],
                  ),
                ),

                IconButton(
                  onPressed:
                      provider.hasAudio
                          ? provider.replayAudio
                          : null,
                  icon: Icon(
                    Icons.replay_rounded,
                    color: provider.hasAudio
                        ? accentColor
                        : Colors.grey,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 17),

            Row(
              children: [
                InkWell(
                  onTap: provider.hasAudio
                      ? provider.toggleAudio
                      : null,
                  borderRadius:
                      BorderRadius.circular(40),
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration:
                        const BoxDecoration(
                      color: accentColor,
                      shape: BoxShape.circle,
                    ),
                    child: provider.isAudioLoading
                        ? const Padding(
                            padding:
                                EdgeInsets.all(
                              13,
                            ),
                            child:
                                CircularProgressIndicator(
                              strokeWidth: 2.4,
                              color:
                                  Color(0xFF09231E),
                            ),
                          )
                        : Icon(
                            provider.isPlaying
                                ? Icons.pause_rounded
                                : Icons
                                    .play_arrow_rounded,
                            color: const Color(
                              0xFF09231E,
                            ),
                            size: 31,
                          ),
                  ),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    children: [
                      SliderTheme(
                        data: SliderTheme.of(
                          context,
                        ).copyWith(
                          activeTrackColor:
                              accentColor,
                          inactiveTrackColor:
                              accentColor
                                  .withOpacity(
                            0.18,
                          ),
                          thumbColor:
                              accentColor,
                          overlayColor:
                              accentColor
                                  .withOpacity(
                            0.10,
                          ),
                          trackHeight: 4,
                          thumbShape:
                              const RoundSliderThumbShape(
                            enabledThumbRadius:
                                6,
                          ),
                        ),
                        child: Slider(
                          min: 0,
                          max: 1,
                          value: sliderValue,
                          onChanged:
                              provider.hasAudio
                                  ? provider
                                      .seekAudio
                                  : null,
                        ),
                      ),

                      Padding(
                        padding:
                            const EdgeInsets
                                .symmetric(
                          horizontal: 10,
                        ),
                        child: Row(
                          children: [
                            Text(
                              provider
                                  .formatDuration(
                                provider.position,
                              ),
                              style: GoogleFonts
                                  .ibmPlexSansArabic(
                                color: isDark
                                    ? AppColors
                                        .darkSubText
                                    : AppColors
                                        .lightSubText,
                                fontSize: 10,
                              ),
                            ),

                            const Spacer(),

                            Text(
                              provider
                                  .formatDuration(
                                provider.duration,
                              ),
                              style: GoogleFonts
                                  .ibmPlexSansArabic(
                                color: isDark
                                    ? AppColors
                                        .darkSubText
                                    : AppColors
                                        .lightSubText,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            if (analysis.content.speechText
                .trim()
                .isNotEmpty) ...[
              const SizedBox(height: 14),

              Material(
                color: Colors.transparent,
                child: Theme(
                  data: Theme.of(context).copyWith(
                    dividerColor:
                        Colors.transparent,
                    splashColor:
                        accentColor.withOpacity(
                      0.08,
                    ),
                    highlightColor:
                        accentColor.withOpacity(
                      0.04,
                    ),
                  ),
                  child: ExpansionTile(
                    tilePadding:
                        EdgeInsets.zero,
                    childrenPadding:
                        const EdgeInsets.only(
                      bottom: 4,
                    ),
                    backgroundColor:
                        Colors.transparent,
                    collapsedBackgroundColor:
                        Colors.transparent,
                    iconColor: accentColor,
                    collapsedIconColor:
                        isDark
                            ? AppColors
                                .darkSubText
                            : AppColors
                                .lightSubText,
                    title: Text(
                      "View voice transcript",
                      style: GoogleFonts
                          .ibmPlexSansArabic(
                        color: isDark
                            ? AppColors.darkText
                            : AppColors.lightText,
                        fontSize: 12,
                        fontWeight:
                            FontWeight.w600,
                      ),
                    ),
                    children: [
                      Container(
                        width: double.infinity,
                        padding:
                            const EdgeInsets.all(
                          13,
                        ),
                        decoration:
                            BoxDecoration(
                          color: isDark
                              ? const Color(
                                  0xFF203330,
                                )
                              : AppColors
                                  .lightBackground,
                          borderRadius:
                              BorderRadius.circular(
                            14,
                          ),
                        ),
                        child: Text(
                          analysis
                              .content.speechText,
                          textDirection:
                              TextDirection.rtl,
                          style: GoogleFonts
                              .ibmPlexSansArabic(
                            color: isDark
                                ? AppColors
                                    .darkText
                                : AppColors
                                    .lightText,
                            fontSize: 12,
                            height: 1.7,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// =====================================================
// SECTION HEADER
// =====================================================

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final bool isDark;
  final double screenW;

  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.color,
    required this.isDark,
    required this.screenW,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 37,
          height: 37,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius:
                BorderRadius.circular(11),
          ),
          child: Icon(
            icon,
            color: color,
            size: 20,
          ),
        ),

        const SizedBox(width: 10),

        Expanded(
          child: Text(
            title,
            style:
                GoogleFonts.ibmPlexSansArabic(
              color: isDark
                  ? AppColors.darkText
                  : AppColors.lightText,
              fontSize: screenW * 0.045,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}

// =====================================================
// SUMMARY
// =====================================================

class _SummaryCard extends StatelessWidget {
  final String summary;
  final bool isDark;
  final double screenW;

  const _SummaryCard({
    required this.summary,
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
            ? const Color(0xFF172624)
            : Colors.white,
        borderRadius:
            BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.04)
              : Colors.black.withOpacity(0.05),
        ),
      ),
      child: Text(
        summary.trim().isEmpty
            ? "No summary is available."
            : summary,
        textDirection: TextDirection.rtl,
        style:
            GoogleFonts.ibmPlexSansArabic(
          color: isDark
              ? AppColors.darkText
              : AppColors.lightText,
          fontSize: screenW * 0.035,
          height: 1.8,
        ),
      ),
    );
  }
}

// =====================================================
// METRICS
// =====================================================

class _MetricsSection extends StatelessWidget {
  final AnalysisMetrics metrics;
  final String currency;
  final bool isDark;
  final double screenW;

  const _MetricsSection({
    required this.metrics,
    required this.currency,
    required this.isDark,
    required this.screenW,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _MetricCard(
          title: "Savings",
          metric: metrics.savings,
          currency: currency,
          icon:
              Icons.savings_outlined,
          color:
              const Color(0xFF34D399),
          isDark: isDark,
          screenW: screenW,
        ),

        const SizedBox(height: 12),

        _MetricCard(
          title: "Needs",
          metric: metrics.needs,
          currency: currency,
          icon:
              Icons.home_work_outlined,
          color:
              const Color(0xFF4F9CF9),
          isDark: isDark,
          screenW: screenW,
        ),

        const SizedBox(height: 12),

        _MetricCard(
          title: "Wants",
          metric: metrics.wants,
          currency: currency,
          icon:
              Icons.shopping_bag_outlined,
          color:
              const Color(0xFFF4C95D),
          isDark: isDark,
          screenW: screenW,
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final AnalysisMetric metric;
  final String currency;
  final IconData icon;
  final Color color;
  final bool isDark;
  final double screenW;

  const _MetricCard({
    required this.title,
    required this.metric,
    required this.currency,
    required this.icon,
    required this.color,
    required this.isDark,
    required this.screenW,
  });

  @override
  Widget build(BuildContext context) {
    final double progress =
        (metric.percent / 100)
            .clamp(0.0, 1.0);

    final Color statusColor =
        _statusColor(metric.status);

    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF172624)
            : Colors.white,
        borderRadius:
            BorderRadius.circular(19),
        border: Border.all(
          color: color.withOpacity(0.12),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 45,
                height: 45,
                decoration: BoxDecoration(
                  color:
                      color.withOpacity(0.12),
                  borderRadius:
                      BorderRadius.circular(
                    13,
                  ),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 23,
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts
                          .ibmPlexSansArabic(
                        color: isDark
                            ? AppColors.darkText
                            : AppColors.lightText,
                        fontSize:
                            screenW * 0.039,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 3),

                    Text(
                      "${metric.current.toStringAsFixed(2)} / "
                      "${metric.target.toStringAsFixed(2)} $currency",
                      style: GoogleFonts
                          .ibmPlexSansArabic(
                        color: isDark
                            ? AppColors.darkSubText
                            : AppColors.lightSubText,
                        fontSize:
                            screenW * 0.028,
                      ),
                    ),
                  ],
                ),
              ),

              Column(
                crossAxisAlignment:
                    CrossAxisAlignment.end,
                children: [
                  Text(
                    "${metric.percent.toStringAsFixed(0)}%",
                    style: GoogleFonts
                        .ibmPlexSansArabic(
                      color: color,
                      fontSize:
                          screenW * 0.043,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),

                  Container(
                    margin:
                        const EdgeInsets.only(
                      top: 4,
                    ),
                    padding:
                        const EdgeInsets
                            .symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration:
                        BoxDecoration(
                      color: statusColor
                          .withOpacity(0.11),
                      borderRadius:
                          BorderRadius.circular(
                        8,
                      ),
                    ),
                    child: Text(
                      metric.status.label,
                      style: GoogleFonts
                          .ibmPlexSansArabic(
                        color: statusColor,
                        fontSize: 9,
                        fontWeight:
                            FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 15),

          ClipRRect(
            borderRadius:
                BorderRadius.circular(20),
            child:
                LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              backgroundColor:
                  color.withOpacity(0.13),
              valueColor:
                  AlwaysStoppedAnimation<Color>(
                color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =====================================================
// ITEMS CARD
// =====================================================

class _AnalysisItemsCard
    extends StatelessWidget {
  final List<String> items;
  final IconData icon;
  final Color color;
  final bool isDark;
  final double screenW;
  final String emptyText;

  const _AnalysisItemsCard({
    required this.items,
    required this.icon,
    required this.color,
    required this.isDark,
    required this.screenW,
    required this.emptyText,
  });

  @override
  Widget build(BuildContext context) {
    final List<String> displayedItems =
        items.isEmpty
            ? [emptyText]
            : items;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF172624)
            : Colors.white,
        borderRadius:
            BorderRadius.circular(20),
        border: Border.all(
          color: color.withOpacity(0.10),
        ),
      ),
      child: Column(
        children:
            List.generate(
          displayedItems.length,
          (index) {
            final String item =
                displayedItems[index];

            return Column(
              children: [
                Padding(
                  padding:
                      const EdgeInsets
                          .symmetric(
                    vertical: 13,
                  ),
                  child: Row(
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .start,
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration:
                            BoxDecoration(
                          color: color
                              .withOpacity(
                            0.12,
                          ),
                          borderRadius:
                              BorderRadius
                                  .circular(
                            10,
                          ),
                        ),
                        child: Icon(
                          icon,
                          color: color,
                          size: 18,
                        ),
                      ),

                      const SizedBox(
                        width: 11,
                      ),

                      Expanded(
                        child: Text(
                          item,
                          textDirection:
                              TextDirection.rtl,
                          style: GoogleFonts
                              .ibmPlexSansArabic(
                            color: isDark
                                ? AppColors
                                    .darkText
                                : AppColors
                                    .lightText,
                            fontSize:
                                screenW *
                                    0.033,
                            height: 1.65,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                if (index <
                    displayedItems.length -
                        1)
                  Divider(
                    height: 1,
                    color: isDark
                        ? Colors.white
                            .withOpacity(
                            0.05,
                          )
                        : Colors.black
                            .withOpacity(
                            0.05,
                          ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// =====================================================
// ERROR
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
// EMPTY VIEW
// =====================================================

class _EmptyAnalysisView extends StatelessWidget {
  final bool isDark;
  final double screenW;
  final String? errorMessage;
  final Future<void> Function() onRetry;

  const _EmptyAnalysisView({
    required this.isDark,
    required this.screenW,
    required this.errorMessage,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding:
            const EdgeInsets.all(24),
        child: Column(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            Container(
              width: screenW * 0.27,
              height: screenW * 0.27,
              decoration: BoxDecoration(
                color: const Color(
                  0xFF34D399,
                ).withOpacity(0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.analytics_outlined,
                color:
                    const Color(0xFF34D399),
                size: screenW * 0.13,
              ),
            ),

            const SizedBox(height: 20),

            Text(
              "No analysis available",
              style: GoogleFonts
                  .ibmPlexSansArabic(
                color: isDark
                    ? AppColors.darkText
                    : AppColors.lightText,
                fontSize:
                    screenW * 0.052,
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              errorMessage ??
                  "Generate a financial analysis to view your summary, insights and recommendations.",
              textAlign:
                  TextAlign.center,
              style: GoogleFonts
                  .ibmPlexSansArabic(
                color: isDark
                    ? AppColors.darkSubText
                    : AppColors.lightSubText,
                fontSize:
                    screenW * 0.033,
                height: 1.6,
              ),
            ),

            const SizedBox(height: 20),

            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(
                Icons.refresh_rounded,
              ),
              label: const Text(
                "Load Analysis",
              ),
              style:
                  ElevatedButton.styleFrom(
                backgroundColor:
                    const Color(
                  0xFF34D399,
                ),
                foregroundColor:
                    const Color(
                  0xFF09231E,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =====================================================
// STATUS COLOR
// =====================================================

Color _statusColor(
  AnalysisStatus status,
) {
  switch (status) {
    case AnalysisStatus.onTrack:
      return const Color(0xFF34D399);

    case AnalysisStatus.warning:
      return const Color(0xFFF4C95D);

    case AnalysisStatus.critical:
      return const Color(0xFFFF6B6B);

    case AnalysisStatus.unknown:
      return const Color(0xFF8A9A96);
  }
}