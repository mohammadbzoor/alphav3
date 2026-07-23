import 'package:alpha_app/core/utils/app_colors.dart';
import 'package:alpha_app/core/utils/device.dart';
import 'package:alpha_app/models/financial_analysis_model.dart';
import 'package:alpha_app/providers/financial_analysis_provider.dart';
import 'package:alpha_app/providers/themeprovider.dart';
import 'package:alpha_app/screens/analysis/financial_analysis_screen.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class FinancialAnalysisCenterScreen extends StatefulWidget {
  const FinancialAnalysisCenterScreen({super.key});

  @override
  State<FinancialAnalysisCenterScreen> createState() => _FinancialAnalysisCenterScreenState();
}

class _FinancialAnalysisCenterScreenState extends State<FinancialAnalysisCenterScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<FinancialAnalysisProvider>().loadHistory();
      }
    });
  }

  Future<void> _generate() async {
    final provider = context.read<FinancialAnalysisProvider>();
    final ok = await provider.generateAnalysis();
    if (!mounted || !ok || provider.analysis == null) return;

    // Navigate to the result screen with the newly generated analysis
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const FinancialAnalysisScreen()),
    );
  }

  Future<void> _openSaved(FinancialAnalysisListItem item) async {
    final provider = context.read<FinancialAnalysisProvider>();
    final ok = await provider.loadAnalysisDetail(item.id);
    if (!mounted || !ok || provider.analysis == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const FinancialAnalysisScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FinancialAnalysisProvider>();
    final isDark = context.watch<Themeprovider>().isDark;
    final screenW = Device.width(context);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: provider.loadHistory,
          color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            padding: EdgeInsets.fromLTRB(screenW * 0.055, 18, screenW * 0.055, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Header(isDark: isDark),
                const SizedBox(height: 22),
                _GenerateCard(
                  isDark: isDark,
                  isGenerating: provider.isGenerating,
                  onTap: provider.isGenerating ? null : _generate,
                ),
                if (provider.errorMessage != null) ...[
                  const SizedBox(height: 14),
                  _ErrorCard(
                    message: provider.errorMessage!,
                    onClose: provider.clearError,
                  ),
                ],
                const SizedBox(height: 28),
                Text(
                  'التحليلات السابقة',
                  style: GoogleFonts.ibmPlexSansArabic(
                    color: isDark ? AppColors.darkText : AppColors.lightText,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                _HistorySection(
                  isDark: isDark,
                  isLoading: provider.isHistoryLoading,
                  items: provider.history,
                  onRetry: provider.loadHistory,
                  onOpen: _openSaved,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final bool isDark;

  const _Header({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: isDark ? AppColors.darkText : AppColors.lightText),
        ),
        Expanded(
          child: Text(
            'مركز التحليل',
            style: GoogleFonts.ibmPlexSansArabic(
              color: isDark ? AppColors.darkText : AppColors.lightText,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}

class _GenerateCard extends StatelessWidget {
  final bool isDark;
  final bool isGenerating;
  final VoidCallback? onTap;

  const _GenerateCard({
    required this.isDark,
    required this.isGenerating,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isDark ? const Color(0xFF172624) : Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF34D399).withOpacity(0.18)),
          ),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: const Color(0xFF34D399).withOpacity(0.13),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: isGenerating
                    ? const Padding(
                        padding: EdgeInsets.all(15),
                        child: CircularProgressIndicator(strokeWidth: 2.4, color: Color(0xFF34D399)),
                      )
                    : const Icon(Icons.auto_graph_rounded, color: Color(0xFF34D399), size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'انقر للتحليل',
                      style: GoogleFonts.ibmPlexSansArabic(
                        color: isDark ? AppColors.darkText : AppColors.lightText,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isGenerating ? 'جاري إعداد التحليل...' : 'أنشئ ملخصاً مالياً محفوظاً من بياناتك الحالية.',
                      style: GoogleFonts.ibmPlexSansArabic(
                        color: isDark ? AppColors.darkSubText : AppColors.lightSubText,
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HistorySection extends StatelessWidget {
  final bool isDark;
  final bool isLoading;
  final List<FinancialAnalysisListItem> items;
  final Future<void> Function() onRetry;
  final ValueChanged<FinancialAnalysisListItem> onOpen;

  const _HistorySection({
    required this.isDark,
    required this.isLoading,
    required this.items,
    required this.onRetry,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading && items.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(28),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (items.isEmpty) {
      return _EmptyHistory(isDark: isDark, onRetry: onRetry);
    }

    return Column(
      children: items
          .map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _HistoryTile(isDark: isDark, item: item, onTap: () => onOpen(item)),
              ))
          .toList(),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final bool isDark;
  final FinancialAnalysisListItem item;
  final VoidCallback onTap;

  const _HistoryTile({
    required this.isDark,
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isDark ? const Color(0xFF172624) : Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: ListTile(
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        leading: const Icon(Icons.analytics_outlined, color: Color(0xFF4F9CF9)),
        title: Text(
          item.summaryPreview.isEmpty ? 'تحليل مالي محفوظ' : item.summaryPreview,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textDirection: TextDirection.rtl,
          style: GoogleFonts.ibmPlexSansArabic(
            color: isDark ? AppColors.darkText : AppColors.lightText,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          '${_formatDate(item.generatedAt)} • ${item.scope} • ${item.insightCount} insights',
          style: GoogleFonts.ibmPlexSansArabic(
            color: isDark ? AppColors.darkSubText : AppColors.lightSubText,
            fontSize: 11,
          ),
        ),
        trailing: Icon(Icons.chevron_right_rounded, color: isDark ? AppColors.darkSubText : AppColors.lightSubText),
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  final bool isDark;
  final Future<void> Function() onRetry;

  const _EmptyHistory({required this.isDark, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF172624) : Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          const Icon(Icons.history_rounded, color: Color(0xFF8A9A96), size: 34),
          const SizedBox(height: 10),
          Text(
            'لا توجد تحليلات محفوظة بعد.',
            style: GoogleFonts.ibmPlexSansArabic(
              color: isDark ? AppColors.darkSubText : AppColors.lightSubText,
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('تحديث')),
        ],
      ),
    );
  }
}

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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFF6B6B).withOpacity(0.10),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: Color(0xFFFF6B6B)),
          const SizedBox(width: 8),
          Expanded(child: Text(message, textDirection: TextDirection.rtl)),
          IconButton(onPressed: onClose, icon: const Icon(Icons.close_rounded, size: 18)),
        ],
      ),
    );
  }
}

String _formatDate(DateTime? value) {
  if (value == null) return '';
  return '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
}
