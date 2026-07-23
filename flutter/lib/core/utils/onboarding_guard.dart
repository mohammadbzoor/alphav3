import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:alpha_app/providers/onboarding_provider.dart';
import 'package:alpha_app/core/utils/step_resolver.dart';

bool requireOnboarding(BuildContext context, {bool showMessage = true}) {
  final provider = context.read<OnboardingProvider>();
  if (!provider.isOnboarded) {
    if (showMessage) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('الملف المالي غير مكتمل'),
          content: const Text('أكمل ملفك المالي أولًا لاستخدام هذه الميزة.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                final success = await provider.checkOnboardingStatus();
                if (success && ctx.mounted) {
                  replaceWithOnboardingStep(
                    context,
                    provider.nextStep,
                    allocation: provider.allocation,
                  );
                }
              },
              child: const Text('أكمل الآن'),
            ),
          ],
        ),
      );
    }
    return false;
  }
  return true;
}
