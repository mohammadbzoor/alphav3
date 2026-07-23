import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:alpha_app/core/utils/app_colors.dart';
import 'package:alpha_app/providers/cycle_provider.dart';
import 'package:alpha_app/providers/home_provider.dart';
import 'package:alpha_app/providers/themeprovider.dart';

class SavingsAllocationScreen extends StatefulWidget {
  final String cycleId;

  const SavingsAllocationScreen({Key? key, required this.cycleId}) : super(key: key);

  @override
  State<SavingsAllocationScreen> createState() => _SavingsAllocationScreenState();
}

class _SavingsAllocationScreenState extends State<SavingsAllocationScreen> {
  bool _isLoading = true;
  double _efPercentage = 10.0;
  
  double _plannedSavings = 0;
  double _efTarget = 0;
  double _efBalance = 0;
  double _plannedGoalAllocations = 0;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final cycleProvider = Provider.of<CycleProvider>(context, listen: false);
    final summary = await cycleProvider.getCyclePlanningSummary(widget.cycleId);
    
    if (!mounted) return;
    
    if (summary != null) {
      setState(() {
        _plannedSavings = (summary['plannedSavings'] ?? 0).toDouble();
        _efTarget = (summary['emergencyFundTarget'] ?? 0).toDouble();
        _efBalance = (summary['emergencyFundBalance'] ?? 0).toDouble();
        
        final goalAllocationsList = summary['goalAllocations'] as List?;
        _plannedGoalAllocations = 0;
        if (goalAllocationsList != null) {
          for (var g in goalAllocationsList) {
            _plannedGoalAllocations += (g['planned_amount'] ?? 0);
          }
        }
        
        final existingSavings = summary['savingsAllocation'];
        if (existingSavings != null) {
          _efPercentage = (existingSavings['emergency_fund_rate'] ?? 10).toDouble();
        }
        
        _isLoading = false;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر تحميل بيانات التخطيط')),
      );
      Navigator.pop(context);
    }
  }

  double get _calculatedEfAmount => (_plannedSavings * (_efPercentage / 100)).roundToDouble();
  double get _remainingCapacity => max(0, _efTarget - _efBalance);
  double get _effectiveEfAmount => min(_calculatedEfAmount, _remainingCapacity);
  double get _unallocatedSavings => _plannedSavings - _effectiveEfAmount - _plannedGoalAllocations;

  Future<void> _saveAndContinue() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      final cycleProvider = Provider.of<CycleProvider>(context, listen: false);
      final success = await cycleProvider.linkSavingsAllocation(widget.cycleId, _efPercentage);
      
      if (!mounted) return;

      if (success) {
        await cycleProvider.loadCurrentCycle();
        if (mounted && cycleProvider.hasActiveCycle) {
          await Provider.of<HomeProvider>(context, listen: false).loadHomeData();
        }
        if (mounted) {
          Navigator.pop(context, true);
        }
      } else if (cycleProvider.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(cycleProvider.error!)),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<Themeprovider>(context);
    final isDark = themeProvider.isDark;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
        body: Center(
          child: CircularProgressIndicator(color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary),
        ),
      );
    }

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: Text(
          "تخطيط المدخرات",
          style: GoogleFonts.ibmPlexSansArabic(
            color: isDark ? AppColors.darkText : AppColors.lightText,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(
          color: isDark ? AppColors.darkText : AppColors.lightText,
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "نسبة صندوق الطوارئ",
              style: GoogleFonts.ibmPlexSansArabic(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.darkText : AppColors.lightText,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "حدد النسبة من إجمالي مدخراتك التي تود تخصيصها لصندوق الطوارئ في هذه الدورة.",
              style: GoogleFonts.ibmPlexSansArabic(
                fontSize: 14,
                color: isDark ? AppColors.darkSubText : AppColors.lightSubText,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),

            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : AppColors.lightCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "النسبة المئوية",
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 16,
                          color: isDark ? AppColors.darkText : AppColors.lightText,
                        ),
                      ),
                      Text(
                        "${_efPercentage.toInt()}%",
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SliderTheme(
                    data: SliderThemeData(
                      activeTrackColor: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
                      inactiveTrackColor: (isDark ? AppColors.darkPrimary : AppColors.lightPrimary).withValues(alpha: 0.2),
                      thumbColor: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
                    ),
                    child: Slider(
                      value: _efPercentage,
                      min: 0,
                      max: 100,
                      divisions: 100,
                      onChanged: (val) {
                        setState(() {
                          _efPercentage = val;
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            _buildSummaryRow("إجمالي المدخرات המתוכננת", _plannedSavings, isDark),
            const SizedBox(height: 12),
            _buildSummaryRow("صندوق الطوارئ", _effectiveEfAmount, isDark, highlight: true),
            const SizedBox(height: 12),
            _buildSummaryRow("أهداف أخرى", _plannedGoalAllocations, isDark),
            const SizedBox(height: 12),
            _buildSummaryRow("المدخرات غير المخصصة", _unallocatedSavings, isDark),

            if (_effectiveEfAmount < _calculatedEfAmount) ...[
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: AppColors.darkAccent, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "تم تحديد الحد الأقصى لصندوق الطوارئ لأنه سيصل إلى هدفه النهائي.",
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 12,
                        color: isDark ? AppColors.darkSubText : AppColors.lightSubText,
                      ),
                    ),
                  ),
                ],
              ),
            ],

            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: _unallocatedSavings < 0 ? null : _saveAndContinue,
                child: _isSaving
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : Text(
                        "اعتماد والبدء",
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, double amount, bool isDark, {bool highlight = false}) {
    final displayAmount = amount / 100; // Assuming amounts are in base units (piasters)
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.ibmPlexSansArabic(
            fontSize: 14,
            color: isDark ? AppColors.darkSubText : AppColors.lightSubText,
          ),
        ),
        Text(
          "${displayAmount.toStringAsFixed(2)} د.أ",
          style: GoogleFonts.ibmPlexSansArabic(
            fontSize: 16,
            fontWeight: highlight ? FontWeight.bold : FontWeight.normal,
            color: highlight 
                ? (isDark ? AppColors.darkPrimary : AppColors.lightPrimary)
                : (isDark ? AppColors.darkText : AppColors.lightText),
          ),
        ),
      ],
    );
  }
}
