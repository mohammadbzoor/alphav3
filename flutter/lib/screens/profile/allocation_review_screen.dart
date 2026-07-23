import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:alpha_app/providers/onboarding_provider.dart';
import 'package:alpha_app/providers/financial_profile_provider.dart';
import 'package:alpha_app/core/utils/step_resolver.dart';
import 'package:alpha_app/core/utils/dashboard_action_result.dart';

enum AllocationReviewMode {
  onboarding,
  financialProfileUpdate,
}

class AllocationReviewScreen extends StatefulWidget {
  final AllocationReviewMode mode;
  final Map<String, dynamic>?
      requestPayload; // The payload that generated the preview

  const AllocationReviewScreen({
    super.key,
    this.mode = AllocationReviewMode.onboarding,
    this.requestPayload,
  });

  @override
  State<AllocationReviewScreen> createState() => _AllocationReviewScreenState();
}

class _AllocationReviewScreenState extends State<AllocationReviewScreen> {
  late int _needsBps;
  late int _wantsBps;
  late int _savingsBps;

  late int _originalNeedsBps;
  late int _originalWantsBps;
  late int _originalSavingsBps;

  bool _isInitialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      _initValues();
      _isInitialized = true;
    }
  }

  void _initValues() {
    Map<String, dynamic> alloc = {};
    if (widget.mode == AllocationReviewMode.onboarding) {
      final provider = Provider.of<OnboardingProvider>(context, listen: false);
      alloc = provider.allocation ?? {};
    } else {
      final provider =
          Provider.of<FinancialProfileProvider>(context, listen: false);
      alloc = provider.previewData?['allocation'] ?? {};
    }

    _needsBps = alloc['needsBps'] ?? 5000;
    _wantsBps = alloc['wantsBps'] ?? 3000;
    _savingsBps = alloc['savingsBps'] ?? 2000;

    _originalNeedsBps = _needsBps;
    _originalWantsBps = _wantsBps;
    _originalSavingsBps = _savingsBps;
  }

  void _reset() {
    setState(() {
      _needsBps = _originalNeedsBps;
      _wantsBps = _originalWantsBps;
      _savingsBps = _originalSavingsBps;
    });
  }

  int get _totalBps => _needsBps + _wantsBps + _savingsBps;

  bool _isNavigating = false;

  Future<void> _submit() async {
    if (_totalBps != 10000) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Total allocation must exactly equal 100%')),
      );
      return;
    }

    if (_isNavigating) return;
    setState(() => _isNavigating = true);

    try {
      if (widget.mode == AllocationReviewMode.onboarding) {
        final provider =
            Provider.of<OnboardingProvider>(context, listen: false);
        final data = {
          'needsBps': _needsBps,
          'wantsBps': _wantsBps,
          'savingsBps': _savingsBps,
        };

        final success = await provider.approveAllocation(data);
        if (!mounted) return;

        if (success) {
          replaceWithOnboardingStep(context, provider.nextStep);
        } else if (provider.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(provider.errorMessage!)),
          );
        }
      } else {
        final provider =
            Provider.of<FinancialProfileProvider>(context, listen: false);
        final data = Map<String, dynamic>.from(widget.requestPayload ?? {});
        data['needsBps'] = _needsBps;
        data['wantsBps'] = _wantsBps;
        data['savingsBps'] = _savingsBps;

        final success = await provider.approveAllocation(data);
        if (!mounted) return;

        if (success) {
          // Refresh onboarding status to update hasActiveCycle if needed
          await Provider.of<OnboardingProvider>(context, listen: false)
              .checkOnboardingStatus();
          if (mounted) {
            Navigator.pop(
                context,
                DashboardActionResult
                    .updated); // Return updated indicating success
          }
        } else if (provider.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(provider.errorMessage!)),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isNavigating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    Map<String, dynamic> alloc = {};
    double income = 0;
    String tier = 'N/A';
    String source = 'N/A';
    bool isCustomized = false;
    bool isLoading = false;

    if (widget.mode == AllocationReviewMode.onboarding) {
      final provider = Provider.of<OnboardingProvider>(context);
      alloc = provider.allocation ?? {};
      income = (alloc['income'] ?? 0).toDouble();
      tier = alloc['tier'] ?? 'N/A';
      source = alloc['source'] ?? 'N/A';
      isCustomized = alloc['isCustomized'] ?? false;
      isLoading = provider.isLoading;
    } else {
      final provider = Provider.of<FinancialProfileProvider>(context);
      final previewData = provider.previewData ?? {};
      alloc = previewData['allocation'] ?? {};
      income = (previewData['income'] ?? 0).toDouble();
      tier = previewData['tier'] ?? 'N/A';
      source = alloc['source'] ?? 'N/A';
      isCustomized = alloc['isCustomized'] ?? false;
      isLoading = provider.isLoading;
    }

    // Calculate amounts dynamically based on adjusted BPS
    final double needsAmount = income * (_needsBps / 10000);
    final double wantsAmount = income * (_wantsBps / 10000);
    final double savingsAmount = income * (_savingsBps / 10000);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Allocation Review'),
        leading: widget.mode == AllocationReviewMode.financialProfileUpdate
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  Navigator.pop(context, false);
                },
              )
            : null,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Income: ${income.toStringAsFixed(2)} JOD',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text('Tier: $tier'),
            Text('Source: $source'),
            Text('Is Customized: $isCustomized'),
            const SizedBox(height: 24),
            _buildSlider('Needs', _needsBps, needsAmount,
                (val) => setState(() => _needsBps = val.toInt())),
            _buildSlider('Wants', _wantsBps, wantsAmount,
                (val) => setState(() => _wantsBps = val.toInt())),
            _buildSlider('Savings', _savingsBps, savingsAmount,
                (val) => setState(() => _savingsBps = val.toInt())),
            const SizedBox(height: 16),
            Text(
              'Total: ${(_totalBps / 100).toStringAsFixed(1)}%',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: _totalBps == 10000 ? Colors.green : Colors.red,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _reset,
                    child: const Text('Reset to Alpha Suggestion'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: isLoading ? null : _submit,
                    child: isLoading
                        ? const CircularProgressIndicator()
                        : const Text('Approve'),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildSlider(String label, int bpsValue, double amount,
      ValueChanged<double> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
            '$label: ${(bpsValue / 100).toStringAsFixed(1)}% (${amount.toStringAsFixed(2)} JOD)'),
        Slider(
          value: bpsValue.toDouble(),
          min: 0,
          max: 10000,
          divisions: 100,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
