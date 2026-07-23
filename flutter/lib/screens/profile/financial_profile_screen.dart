import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'package:alpha_app/core/utils/app_colors.dart';
import 'package:alpha_app/core/utils/dashboard_action_result.dart';
import 'package:alpha_app/providers/financial_profile_provider.dart';
import 'package:alpha_app/providers/onboarding_provider.dart';
import 'package:alpha_app/screens/profile/allocation_review_screen.dart';

// ─────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────

class FinancialProfileScreen extends StatefulWidget {
  const FinancialProfileScreen({super.key});

  @override
  State<FinancialProfileScreen> createState() => _FinancialProfileScreenState();
}

class _FinancialProfileScreenState extends State<FinancialProfileScreen> {
  // ── Edit mode state ──────────────────────────────────────────
  bool _isEditing = false;
  Map<String, dynamic>? _originalData;

  // ── Edit controllers ─────────────────────────────────────────
  final _incomeCtrl = TextEditingController();
  final _currencyCtrl = TextEditingController();
  int? _editPaymentDay;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FinancialProfileProvider>().fetchProfile().then((ok) {
        if (ok && mounted) {
          _syncOriginalData(
              context.read<FinancialProfileProvider>().profileData);
        }
      });
    });
  }

  @override
  void dispose() {
    _incomeCtrl.dispose();
    _currencyCtrl.dispose();
    super.dispose();
  }

  // ── Sync controllers from backend data ───────────────────────
  void _syncOriginalData(Map<String, dynamic>? data) {
    if (data == null) return;
    _originalData = Map<String, dynamic>.from(data);
    _incomeCtrl.text = data['expectedMonthlyIncome']?.toString() ?? '';
    _currencyCtrl.text = data['currency']?.toString() ?? 'JOD';
    _editPaymentDay = data['paymentDay'] as int?;
  }

  // ── Enter edit mode ──────────────────────────────────────────
  void _enterEdit() {
    final data = context.read<FinancialProfileProvider>().profileData;
    _syncOriginalData(data);
    setState(() => _isEditing = true);
  }

  // ── Cancel edit ──────────────────────────────────────────────
  void _cancelEdit() {
    _syncOriginalData(_originalData);
    setState(() => _isEditing = false);
  }

  // ── Save ─────────────────────────────────────────────────────
  Future<void> _saveChanges() async {
    if (_isSaving) return;
    final provider = context.read<FinancialProfileProvider>();

    final newIncomeText = _incomeCtrl.text.trim();
    final newCurrency = _currencyCtrl.text.trim();

    double? newIncome;
    if (newIncomeText.isNotEmpty) {
      newIncome = double.tryParse(newIncomeText);
      if (newIncome == null || newIncome <= 0) {
        _showSnack('Please enter a valid monthly income.', isError: true);
        return;
      }
    }

    final oldIncome = _originalData?['expectedMonthlyIncome'];
    final incomeChanged = newIncome != null &&
        (oldIncome == null || (oldIncome as num).toDouble() != newIncome);

    setState(() => _isSaving = true);

    try {
      if (incomeChanged) {
        // ── Income changed → Preview → Approve flow ───────────
        final payload = <String, dynamic>{
          'expectedMonthlyIncome': newIncome,
          if (_editPaymentDay != null) 'paymentDay': _editPaymentDay,
          if (newCurrency.isNotEmpty) 'currency': newCurrency,
        };

        final previewOk = await provider.previewAllocation(payload);
        if (!mounted) return;

        if (previewOk) {
          final result = await Navigator.push<dynamic>(
            context,
            MaterialPageRoute(
              builder: (_) => AllocationReviewScreen(
                mode: AllocationReviewMode.financialProfileUpdate,
                requestPayload: payload,
              ),
            ),
          );

          if (result == DashboardActionResult.updated && mounted) {
            await provider.fetchProfile();
            if (!mounted) return;
            await Provider.of<OnboardingProvider>(context, listen: false)
                .checkOnboardingStatus();
            if (!mounted) return;
            _syncOriginalData(provider.profileData);
            setState(() => _isEditing = false);
            _showSnack('Financial profile updated successfully.');
          }
        } else {
          _showSnack(provider.errorMessage ?? 'Error calculating allocation.',
              isError: true);
        }
      } else {
        // ── Non-income change → PATCH ─────────────────────────
        final patch = <String, dynamic>{};
        if (_editPaymentDay != null &&
            _editPaymentDay != _originalData?['paymentDay']) {
          patch['paymentDay'] = _editPaymentDay;
        }
        if (newCurrency.isNotEmpty &&
            newCurrency != _originalData?['currency']) {
          patch['currency'] = newCurrency;
        }

        if (patch.isNotEmpty) {
          final ok = await provider.updateProfile(patch);
          if (!mounted) return;
          if (!ok) {
            _showSnack(provider.errorMessage ?? 'An error occurred.',
                isError: true);
            return;
          }
        }
        _syncOriginalData(provider.profileData);
        setState(() => _isEditing = false);
        _showSnack('Financial profile saved.');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.inter()),
      backgroundColor: isError ? AppColors.darkError : null,
      behavior: SnackBarBehavior.floating,
    ));
  }

  // ─────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FinancialProfileProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkBackground : AppColors.lightBackground;
    final primary = isDark ? AppColors.darkPrimary : AppColors.lightPrimary;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          tooltip: '',
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              size: 20,
              color: isDark ? AppColors.darkText : AppColors.lightText),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Financial Profile',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: isDark ? AppColors.darkText : AppColors.lightText,
          ),
        ),
        actions: [
          if (provider.profileData != null && !_isEditing && !_isSaving)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton.icon(
                onPressed: _enterEdit,
                icon: Icon(Icons.edit_outlined, size: 16, color: primary),
                label: Text('Edit',
                    style: GoogleFonts.inter(
                        color: primary, fontWeight: FontWeight.w600)),
              ),
            ),
        ],
      ),
      body: _buildBody(provider, isDark),
    );
  }

  Widget _buildBody(FinancialProfileProvider provider, bool isDark) {
    // ── Loading ───────────────────────────────────────────────
    if (provider.isLoading &&
        provider.profileData == null &&
        provider.errorMessage == null) {
      return const Center(child: CircularProgressIndicator());
    }

    // ── Error ─────────────────────────────────────────────────
    if (provider.errorMessage != null && provider.profileData == null) {
      return _ErrorState(
        message: provider.errorMessage!,
        onRetry: provider.fetchProfile,
        isDark: isDark,
      );
    }

    // ── No data ───────────────────────────────────────────────
    final data = provider.profileData;
    if (data == null) {
      return _ErrorState(
        message: 'No financial profile was found.',
        onRetry: provider.fetchProfile,
        isDark: isDark,
      );
    }

    // ── Content ───────────────────────────────────────────────
    return _isEditing
        ? _EditMode(
            data: data,
            originalData: _originalData ?? data,
            incomeCtrl: _incomeCtrl,
            currencyCtrl: _currencyCtrl,
            editPaymentDay: _editPaymentDay,
            isSaving: _isSaving,
            isDark: isDark,
            onPaymentDayChanged: (d) => setState(() => _editPaymentDay = d),
            onCancel: _cancelEdit,
            onSave: _saveChanges,
          )
        : _ReadOnlyMode(
            data: data,
            isDark: isDark,
            onEdit: _enterEdit,
          );
  }
}

// ─────────────────────────────────────────────────────────────
// Read-only Mode
// ─────────────────────────────────────────────────────────────

class _ReadOnlyMode extends StatelessWidget {
  const _ReadOnlyMode({
    required this.data,
    required this.isDark,
    required this.onEdit,
  });

  final Map<String, dynamic> data;
  final bool isDark;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final primary = isDark ? AppColors.darkPrimary : AppColors.lightPrimary;
    final incomeSources =
        (data['incomeSources'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final fixedExpenses =
        (data['fixedExpenses'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final variableExpenses =
        (data['variableExpenses'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final allocation = data['allocation'] as Map<String, dynamic>?;
    final missingFields =
        (data['missingFinancialFields'] as List?)?.cast<String>() ?? [];
    final isComplete = data['financialProfileComplete'] == true;
    final canCreateCycle = data['canCreateCycle'] == true;
    final currency = data['currency']?.toString() ?? 'JOD';
    final expectedIncome = data['expectedMonthlyIncome'] != null
        ? data['expectedMonthlyIncome'] as num
        : null;

    // Allocation integrity check
    String? allocationError;
    if (allocation != null) {
      final sum = ((allocation['needsBps'] ?? 0) as int) +
          ((allocation['wantsBps'] ?? 0) as int) +
          ((allocation['savingsBps'] ?? 0) as int);
      if (sum != 10000) {
        allocationError =
            'Allocation percentages do not sum to 100%. Data may be inconsistent.';
      }
    }

    // Income-source total vs expected income
    String? incomeConsistencyWarning;
    if (incomeSources.isNotEmpty && expectedIncome != null) {
      final sourceTotal = incomeSources.fold<double>(
          0, (sum, s) => sum + ((s['amount'] as num?)?.toDouble() ?? 0));
      if ((sourceTotal - expectedIncome.toDouble()).abs() > 0.01) {
        incomeConsistencyWarning =
            'Income sources total (${_fmt(sourceTotal)} $currency) differs from expected monthly income. '
            'The backend value is authoritative.';
      }
    }

    // Expenses totals
    final fixedTotal = fixedExpenses.fold<double>(
        0, (s, e) => s + ((e['amount'] as num?)?.toDouble() ?? 0));
    final variableTotal = variableExpenses.fold<double>(
        0, (s, e) => s + ((e['amount'] as num?)?.toDouble() ?? 0));
    final totalExpenses = fixedTotal + variableTotal;
    final balance = expectedIncome != null
        ? expectedIncome.toDouble() - totalExpenses
        : null;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1 ── Status Card ─────────────────────────────────
          _StatusCard(
            isComplete: isComplete,
            canCreateCycle: canCreateCycle,
            missingFields: missingFields,
            isDark: isDark,
          ),
          const SizedBox(height: 16),

          // 2 ── Expected Income ─────────────────────────────
          _SectionCard(
            isDark: isDark,
            title: 'Expected Monthly Income',
            icon: Icons.account_balance_wallet_outlined,
            children: [
              _InfoRow(
                label: 'Expected Monthly Income',
                value: expectedIncome != null
                    ? '${_fmt(expectedIncome.toDouble())} $currency'
                    : 'Not provided',
                isHighlight: true,
                isDark: isDark,
              ),
              _InfoRow(
                label: 'Currency',
                value: data['currency']?.toString() ?? 'Not provided',
                isDark: isDark,
              ),
              if (incomeConsistencyWarning != null)
                _WarningBanner(
                    message: incomeConsistencyWarning, isDark: isDark),
            ],
          ),
          const SizedBox(height: 12),

          // 3 ── Income Sources ──────────────────────────────
          if (incomeSources.isNotEmpty)
            _SectionCard(
              isDark: isDark,
              title: 'Income Sources',
              icon: Icons.paid_outlined,
              children: [
                ...incomeSources.map((src) => _InfoRow(
                      label: _formatSourceType(src['type']?.toString()),
                      value:
                          '${_fmt((src['amount'] as num?)?.toDouble() ?? 0)} $currency',
                      isDark: isDark,
                    )),
              ],
            ),
          if (incomeSources.isNotEmpty) const SizedBox(height: 12),

          // 4 ── Payment Schedule ────────────────────────────
          _SectionCard(
            isDark: isDark,
            title: 'Payment Schedule',
            icon: Icons.calendar_today_outlined,
            children: [
              _InfoRow(
                label: 'Payment Day',
                value: data['paymentDay'] != null
                    ? 'Day ${data['paymentDay']}'
                    : 'Not provided',
                isDark: isDark,
              ),
              _InfoRow(
                label: 'Timezone',
                value: data['timezone']?.toString() ?? 'Not provided',
                isDark: isDark,
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 5 ── Estimated Expenses ──────────────────────────
          _SectionCard(
            isDark: isDark,
            title: 'Estimated Monthly Expenses',
            icon: Icons.receipt_long_outlined,
            subtitle: 'Estimated information — not actual transactions',
            children: [
              if (fixedExpenses.isEmpty && variableExpenses.isEmpty)
                _InfoRow(
                    label: 'Fixed Monthly Expenses',
                    value: 'Not provided',
                    isDark: isDark),
              if (fixedExpenses.isNotEmpty) ...[
                _SubsectionLabel('Fixed Monthly Expenses', isDark: isDark),
                ...fixedExpenses.map((e) => _InfoRow(
                      label: e['name']?.toString() ??
                          e['type']?.toString() ??
                          'Expense',
                      value:
                          '${_fmt((e['amount'] as num?)?.toDouble() ?? 0)} $currency',
                      isDark: isDark,
                    )),
              ],
              if (variableExpenses.isNotEmpty) ...[
                _SubsectionLabel('Flexible Monthly Expenses', isDark: isDark),
                ...variableExpenses.map((e) => _InfoRow(
                      label: e['name']?.toString() ??
                          e['type']?.toString() ??
                          'Expense',
                      value:
                          '${_fmt((e['amount'] as num?)?.toDouble() ?? 0)} $currency',
                      isDark: isDark,
                    )),
              ],
              if (fixedExpenses.isNotEmpty || variableExpenses.isNotEmpty) ...[
                const _Divider(),
                _InfoRow(
                  label: 'Total Estimated Expenses',
                  value: '${_fmt(totalExpenses)} $currency',
                  isDark: isDark,
                  isBold: true,
                ),
                if (balance != null)
                  _InfoRow(
                    label: 'Estimated Balance',
                    value: '${_fmt(balance)} $currency',
                    isDark: isDark,
                    valueColor: balance >= 0 ? primary : AppColors.darkError,
                    isBold: true,
                  ),
              ],
            ],
          ),
          const SizedBox(height: 12),

          // 6 ── Financial Preferences ───────────────────────
          _SectionCard(
            isDark: isDark,
            title: 'Financial Preferences',
            icon: Icons.psychology_outlined,
            children: [
              _InfoRow(
                label: 'Relationship with Money',
                value: _formatEnum(data['relationshipWithMoney']?.toString()),
                isDark: isDark,
              ),
              _InfoRow(
                label: 'Main Financial Goal',
                value: _formatEnum(data['primaryFinancialGoal']?.toString()),
                isDark: isDark,
              ),
              _InfoRow(
                label: 'Extra Monthly Savings Target',
                value: data['monthlyExtraSavingsGoal'] != null
                    ? '${_fmt((data['monthlyExtraSavingsGoal'] as num).toDouble())} $currency'
                    : 'Not provided',
                isDark: isDark,
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 7 ── Approved Allocation ─────────────────────────
          if (allocation != null) ...[
            _AllocationSection(
              allocation: allocation,
              currency: currency,
              isDark: isDark,
              consistencyError: allocationError,
            ),
            const SizedBox(height: 12),
          ],

          // 8 ── Future Cycle Notice ─────────────────────────
          _FutureCycleNotice(
            canCreateCycle: canCreateCycle,
            isDark: isDark,
          ),
          const SizedBox(height: 24),

          // 9 ── Edit Button ─────────────────────────────────
          _EditButton(isDark: isDark, onPressed: onEdit),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Edit Mode
// ─────────────────────────────────────────────────────────────

class _EditMode extends StatelessWidget {
  const _EditMode({
    required this.data,
    required this.originalData,
    required this.incomeCtrl,
    required this.currencyCtrl,
    required this.editPaymentDay,
    required this.isSaving,
    required this.isDark,
    required this.onPaymentDayChanged,
    required this.onCancel,
    required this.onSave,
  });

  final Map<String, dynamic> data;
  final Map<String, dynamic> originalData;
  final TextEditingController incomeCtrl;
  final TextEditingController currencyCtrl;
  final int? editPaymentDay;
  final bool isSaving;
  final bool isDark;
  final ValueChanged<int?> onPaymentDayChanged;
  final VoidCallback onCancel;
  final VoidCallback onSave;

  Color get _primary => isDark ? AppColors.darkPrimary : AppColors.lightPrimary;
  Color get _textColor => isDark ? AppColors.darkText : AppColors.lightText;
  Color get _subText => isDark ? AppColors.darkSubText : AppColors.lightSubText;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Notice banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: _primary.withAlpha(26),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _primary.withAlpha(77)),
            ),
            child: Row(children: [
              Icon(Icons.info_outline_rounded, size: 18, color: _primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Changes to income require an allocation review before saving.',
                  style: GoogleFonts.inter(fontSize: 13, color: _primary),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 20),

          // Expected Monthly Income
          _EditLabel('Expected Monthly Income', subText: isDark),
          const SizedBox(height: 6),
          TextField(
            controller: incomeCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
            ],
            style: GoogleFonts.inter(
                color: _textColor, fontWeight: FontWeight.w600),
            decoration: _inputDecoration(
                hint: 'e.g. 1200', isDark: isDark, suffix: currencyCtrl.text),
          ),
          const SizedBox(height: 16),

          // Currency
          _EditLabel('Currency', subText: isDark),
          const SizedBox(height: 6),
          TextField(
            controller: currencyCtrl,
            style: GoogleFonts.inter(color: _textColor),
            decoration: _inputDecoration(hint: 'e.g. JOD', isDark: isDark),
          ),
          const SizedBox(height: 16),

          // Payment Day picker
          _EditLabel('Payment Day', subText: isDark),
          const SizedBox(height: 6),
          _DayPickerButton(
            selectedDay: editPaymentDay,
            isDark: isDark,
            onDaySelected: onPaymentDayChanged,
          ),
          const SizedBox(height: 32),

          // Buttons row
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: isSaving ? null : onCancel,
                style: OutlinedButton.styleFrom(
                  foregroundColor: _textColor,
                  side: BorderSide(color: _subText.withAlpha(120)),
                  minimumSize: const Size(0, 52),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: Text('Cancel',
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600, fontSize: 15)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: FilledButton(
                onPressed: isSaving ? null : onSave,
                style: FilledButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: _primary.withAlpha(100),
                  disabledForegroundColor: Colors.white70,
                  minimumSize: const Size(0, 52),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: Colors.white),
                      )
                    : Text('Save Changes',
                        style: GoogleFonts.inter(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: Colors.white)),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(
      {required String hint, required bool isDark, String? suffix}) {
    return InputDecoration(
      hintText: hint,
      suffixText: suffix,
      hintStyle: GoogleFonts.inter(
          color: isDark ? AppColors.darkSubText : AppColors.lightSubText),
      filled: true,
      fillColor: isDark ? AppColors.darkCard : AppColors.lightCard,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
            color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
            width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Status Card
// ─────────────────────────────────────────────────────────────

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.isComplete,
    required this.canCreateCycle,
    required this.missingFields,
    required this.isDark,
  });
  final bool isComplete;
  final bool canCreateCycle;
  final List<String> missingFields;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final Color bg = isComplete
        ? (isDark ? const Color(0xFF0E2D22) : const Color(0xFFECFDF5))
        : (isDark ? const Color(0xFF2D1A0E) : const Color(0xFFFFF7ED));

    final Color borderC = isComplete
        ? (isDark ? AppColors.darkPrimary : AppColors.lightPrimary)
        : Colors.orange;

    final Color iconC = isComplete
        ? (isDark ? AppColors.darkPrimary : AppColors.lightPrimary)
        : Colors.orange;

    final String title = isComplete
        ? 'Financial Profile Complete'
        : 'Financial Profile Needs Attention';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderC.withAlpha(102)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(
              isComplete
                  ? Icons.check_circle_outline_rounded
                  : Icons.warning_amber_rounded,
              color: iconC,
              size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: iconC,
              ),
            ),
          ),
        ]),
        if (canCreateCycle && isComplete) ...[
          const SizedBox(height: 8),
          Text('Ready to start a financial cycle.',
              style: GoogleFonts.inter(
                  fontSize: 13,
                  color:
                      isDark ? AppColors.darkSubText : AppColors.lightSubText)),
        ],
        if (!isComplete && missingFields.isNotEmpty) ...[
          const SizedBox(height: 10),
          ...missingFields.map((f) => Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(children: [
                  const Icon(Icons.circle, size: 6, color: Colors.orange),
                  const SizedBox(width: 8),
                  Text(_fieldLabel(f),
                      style: GoogleFonts.inter(
                          fontSize: 13,
                          color: isDark
                              ? AppColors.darkText
                              : AppColors.lightText)),
                ]),
              )),
        ],
      ]),
    );
  }

  String _fieldLabel(String field) {
    const labels = <String, String>{
      'expectedMonthlyIncome': 'Expected Monthly Income',
      'paymentDay': 'Payment Day',
      'currency': 'Currency',
      'timezone': 'Timezone',
      'incomeSources': 'Income Sources',
      'fixedExpenses': 'Fixed Expenses',
      'variableExpenses': 'Variable Expenses',
    };
    return labels[field] ?? _formatEnum(field);
  }
}

// ─────────────────────────────────────────────────────────────
// Allocation Section
// ─────────────────────────────────────────────────────────────

class _AllocationSection extends StatelessWidget {
  const _AllocationSection({
    required this.allocation,
    required this.currency,
    required this.isDark,
    this.consistencyError,
  });

  final Map<String, dynamic> allocation;
  final String currency;
  final bool isDark;
  final String? consistencyError;

  @override
  Widget build(BuildContext context) {
    final primary = isDark ? AppColors.darkPrimary : AppColors.lightPrimary;
    final cardBg = isDark ? AppColors.darkCard : AppColors.lightCard;
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;
    final subText = isDark ? AppColors.darkSubText : AppColors.lightSubText;

    final needsBps = (allocation['needsBps'] ?? 0) as int;
    final wantsBps = (allocation['wantsBps'] ?? 0) as int;
    final savingsBps = (allocation['savingsBps'] ?? 0) as int;
    final basedOnIncome = allocation['basedOnIncome'] as num?;
    final isCustomized = allocation['isCustomized'] == true;

    final needsAmt = allocation['needsAmount'] as num?;
    final wantsAmt = allocation['wantsAmount'] as num?;
    final savingsAmt = allocation['savingsAmount'] as num?;

    String sourceLabel =
        isCustomized ? 'Customized allocation' : 'System recommendation';

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _SectionHeader(
          title: 'Approved Allocation',
          icon: Icons.pie_chart_outline_rounded,
          isDark: isDark),
      const SizedBox(height: 10),

      if (consistencyError != null)
        _WarningBanner(message: consistencyError!, isDark: isDark),

      // Three allocation bars
      _AllocationBar(
        label: 'Needs',
        bps: needsBps,
        amount: needsAmt,
        currency: currency,
        color: primary,
        isDark: isDark,
      ),
      const SizedBox(height: 8),
      _AllocationBar(
        label: 'Wants',
        bps: wantsBps,
        amount: wantsAmt,
        currency: currency,
        color: isDark ? AppColors.darkAccent : AppColors.lightAccent,
        isDark: isDark,
      ),
      const SizedBox(height: 8),
      _AllocationBar(
        label: 'Savings',
        bps: savingsBps,
        amount: savingsAmt,
        currency: currency,
        color: const Color(0xFF60A5FA),
        isDark: isDark,
      ),
      const SizedBox(height: 10),

      // Meta row
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
        ),
        child: Column(children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Allocation Source',
                  style: GoogleFonts.inter(fontSize: 13, color: subText)),
              Text(sourceLabel,
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: textColor)),
            ],
          ),
          if (basedOnIncome != null) ...[
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Based on Income',
                    style: GoogleFonts.inter(fontSize: 13, color: subText)),
                Text('${_fmt(basedOnIncome.toDouble())} $currency',
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: textColor)),
              ],
            ),
          ],
        ]),
      ),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────
// Allocation Bar Row
// ─────────────────────────────────────────────────────────────

class _AllocationBar extends StatelessWidget {
  const _AllocationBar({
    required this.label,
    required this.bps,
    required this.amount,
    required this.currency,
    required this.color,
    required this.isDark,
  });

  final String label;
  final int bps;
  final num? amount;
  final String currency;
  final Color color;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final pct = (bps / 100).toStringAsFixed(0);
    final cardBg = isDark ? AppColors.darkCard : AppColors.lightCard;
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;
    final subText = isDark ? AppColors.darkSubText : AppColors.lightSubText;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(children: [
              Container(
                  width: 10,
                  height: 10,
                  decoration:
                      BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Text(label,
                  style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: textColor)),
            ]),
            Row(children: [
              Text('$pct%',
                  style: GoogleFonts.inter(
                      fontWeight: FontWeight.w700, fontSize: 16, color: color)),
              if (amount != null) ...[
                const SizedBox(width: 8),
                Text('${_fmt(amount!.toDouble())} $currency',
                    style: GoogleFonts.inter(fontSize: 13, color: subText)),
              ],
            ]),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: math.min(bps / 10000, 1.0),
            backgroundColor:
                isDark ? AppColors.darkBorder : AppColors.lightBorder,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 6,
          ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Future Cycle Notice
// ─────────────────────────────────────────────────────────────

class _FutureCycleNotice extends StatelessWidget {
  const _FutureCycleNotice({
    required this.canCreateCycle,
    required this.isDark,
  });
  final bool canCreateCycle;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final subText = isDark ? AppColors.darkSubText : AppColors.lightSubText;
    final msg = canCreateCycle
        ? 'These settings will be used when you start your next financial cycle.'
        : 'Changes to your financial profile will apply to your next financial cycle. Your current cycle will not change.';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.info_outline_rounded, size: 16, color: subText),
        const SizedBox(width: 10),
        Expanded(
          child:
              Text(msg, style: GoogleFonts.inter(fontSize: 13, color: subText)),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Section Card
// ─────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.children,
    required this.isDark,
    this.subtitle,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;
  final bool isDark;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _SectionHeader(title: title, icon: icon, isDark: isDark),
      if (subtitle != null)
        Padding(
          padding: const EdgeInsets.only(top: 2, bottom: 4),
          child: Text(subtitle!,
              style: GoogleFonts.inter(
                  fontSize: 11,
                  color:
                      isDark ? AppColors.darkSubText : AppColors.lightSubText)),
        ),
      const SizedBox(height: 6),
      Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.lightCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (int i = 0; i < children.length; i++) ...[
              children[i],
              if (i < children.length - 1 &&
                  children[i] is _InfoRow &&
                  children[i + 1] is _InfoRow)
                Divider(
                    height: 1,
                    indent: 16,
                    endIndent: 16,
                    color:
                        isDark ? AppColors.darkBorder : AppColors.lightBorder),
            ],
          ],
        ),
      ),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────
// Section Header
// ─────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(
      {required this.title, required this.icon, required this.isDark});

  final String title;
  final IconData icon;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final primary = isDark ? AppColors.darkPrimary : AppColors.lightPrimary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(children: [
        Icon(icon, size: 16, color: primary),
        const SizedBox(width: 6),
        Text(title,
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: isDark ? AppColors.darkText : AppColors.lightText,
            )),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Info Row
// ─────────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    required this.isDark,
    this.isHighlight = false,
    this.isBold = false,
    this.valueColor,
  });

  final String label;
  final String value;
  final bool isDark;
  final bool isHighlight;
  final bool isBold;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;
    final subText = isDark ? AppColors.darkSubText : AppColors.lightSubText;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 14, color: subText)),
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: GoogleFonts.inter(
                fontSize: isHighlight ? 16 : 14,
                fontWeight:
                    (isHighlight || isBold) ? FontWeight.w700 : FontWeight.w500,
                color: valueColor ??
                    (value == 'Not provided' ? subText : textColor),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Subsection Label
// ─────────────────────────────────────────────────────────────

class _SubsectionLabel extends StatelessWidget {
  const _SubsectionLabel(this.label, {required this.isDark});
  final String label;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(label,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
            color: isDark ? AppColors.darkSubText : AppColors.lightSubText,
          )),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Divider
// ─────────────────────────────────────────────────────────────

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return const Divider(height: 1, indent: 16, endIndent: 16);
  }
}

// ─────────────────────────────────────────────────────────────
// Warning Banner
// ─────────────────────────────────────────────────────────────

class _WarningBanner extends StatelessWidget {
  const _WarningBanner({required this.message, required this.isDark});
  final String message;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.orange.withAlpha(30),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.orange.withAlpha(80)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.warning_amber_rounded, size: 14, color: Colors.orange),
        const SizedBox(width: 8),
        Expanded(
          child: Text(message,
              style: GoogleFonts.inter(fontSize: 12, color: Colors.orange)),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Edit Label
// ─────────────────────────────────────────────────────────────

class _EditLabel extends StatelessWidget {
  const _EditLabel(this.label, {required this.subText});
  final String label;
  final bool subText;

  @override
  Widget build(BuildContext context) {
    final color = subText ? AppColors.darkSubText : AppColors.lightSubText;
    return Text(label,
        style: GoogleFonts.inter(
            fontSize: 13, fontWeight: FontWeight.w600, color: color));
  }
}

// ─────────────────────────────────────────────────────────────
// Day Picker Button
// ─────────────────────────────────────────────────────────────

class _DayPickerButton extends StatelessWidget {
  const _DayPickerButton({
    required this.selectedDay,
    required this.isDark,
    required this.onDaySelected,
  });

  final int? selectedDay;
  final bool isDark;
  final ValueChanged<int?> onDaySelected;

  @override
  Widget build(BuildContext context) {
    final primary = isDark ? AppColors.darkPrimary : AppColors.lightPrimary;
    final cardBg = isDark ? AppColors.darkCard : AppColors.lightCard;
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;
    final subText = isDark ? AppColors.darkSubText : AppColors.lightSubText;

    return GestureDetector(
      onTap: () => _showDayPicker(context),
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
        ),
        child: Row(
          children: [
            Icon(Icons.event_outlined, size: 18, color: primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                selectedDay != null ? 'Day $selectedDay' : 'Select payment day',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: selectedDay != null ? textColor : subText,
                  fontWeight:
                      selectedDay != null ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
            Icon(Icons.keyboard_arrow_down_rounded, color: subText),
          ],
        ),
      ),
    );
  }

  void _showDayPicker(BuildContext context) {
    final primary = isDark ? AppColors.darkPrimary : AppColors.lightPrimary;
    final bg = isDark ? AppColors.darkBackground : AppColors.lightBackground;
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;
    final subText = isDark ? AppColors.darkSubText : AppColors.lightSubText;

    showModalBottomSheet(
      context: context,
      backgroundColor: bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Select Payment Day',
                    style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: textColor)),
                IconButton(
                    icon: Icon(Icons.close, color: subText),
                    onPressed: () => Navigator.pop(ctx)),
              ],
            ),
            const SizedBox(height: 4),
            Text('Choose the day you usually receive your salary.',
                style: GoogleFonts.inter(fontSize: 13, color: subText)),
            const SizedBox(height: 16),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 1,
              ),
              itemCount: 31,
              itemBuilder: (_, i) {
                final day = i + 1;
                final isSel = selectedDay == day;
                return InkWell(
                  onTap: () {
                    onDaySelected(day);
                    Navigator.pop(ctx);
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSel ? primary : primary.withAlpha(26),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text('$day',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isSel ? Colors.white : textColor,
                          )),
                    ),
                  ),
                );
              },
            ),
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Edit Button
// ─────────────────────────────────────────────────────────────

class _EditButton extends StatelessWidget {
  const _EditButton({required this.isDark, required this.onPressed});
  final bool isDark;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final primary = isDark ? AppColors.darkPrimary : AppColors.lightPrimary;
    return SizedBox(
      height: 52,
      child: FilledButton.icon(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.white),
        label: Text('Edit Financial Profile',
            style: GoogleFonts.inter(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: Colors.white)),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Error State
// ─────────────────────────────────────────────────────────────

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.message,
    required this.onRetry,
    required this.isDark,
  });

  final String message;
  final VoidCallback onRetry;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final primary = isDark ? AppColors.darkPrimary : AppColors.lightPrimary;
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;
    final subText = isDark ? AppColors.darkSubText : AppColors.lightSubText;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.cloud_off_rounded, size: 56, color: subText),
          const SizedBox(height: 16),
          Text(message,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 15, color: textColor)),
          const SizedBox(height: 24),
          SizedBox(
            height: 48,
            child: FilledButton.icon(
              onPressed: onRetry,
              style: FilledButton.styleFrom(
                  backgroundColor: primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12))),
              icon: const Icon(Icons.refresh_rounded,
                  size: 18, color: Colors.white),
              label: Text('Retry',
                  style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600, color: Colors.white)),
            ),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────

String _fmt(double v) {
  if (v == v.truncateToDouble()) return v.toInt().toString();
  return v.toStringAsFixed(2);
}

String _formatEnum(String? raw) {
  if (raw == null || raw.isEmpty) return 'Not provided';
  return raw
      .split(RegExp(r'[_\-]'))
      .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');
}

String _formatSourceType(String? raw) {
  if (raw == null || raw.isEmpty) return 'Income Source';
  const map = <String, String>{
    'regular_salary': 'Regular Salary',
    'salary': 'Regular Salary',
    'recurring_side_income': 'Recurring Side Income',
    'freelance': 'Freelance',
    'rental_income': 'Rental Income',
    'investment': 'Investment Income',
    'business': 'Business Income',
    'other': 'Other Income',
  };
  return map[raw] ?? _formatEnum(raw);
}
