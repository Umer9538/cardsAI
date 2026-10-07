import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../data/local/json_store.dart';
import '../../../auth/presentation/widgets/auth_widgets.dart';

/// Told once, before the first thing that sends food data off the device.
///
/// Google Play's User Data policy requires prominent, in-app disclosure of a
/// sensitive transfer *before* it happens — a privacy policy two menus deep
/// does not satisfy it, and this app's most significant data flow is a
/// photograph of someone's meal going to a third party. Apple asks the same
/// question in review.
///
/// Returns true when the person agreed. Shown once per device; a refusal is
/// not recorded, so the next attempt asks again rather than silently blocking
/// the feature.
Future<bool> confirmAiDisclosure(BuildContext context, WidgetRef ref) async {
  final store = ref.read(jsonStoreProvider);
  if (store.flag(StoreKeys.aiDisclosureSeen)) return true;

  final agreed = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => const _Sheet(),
  );

  if (agreed != true) return false;
  await store.setFlag(StoreKeys.aiDisclosureSeen, value: true);
  return true;
}

class _Sheet extends StatelessWidget {
  const _Sheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
        decoration: BoxDecoration(
          color: AppColors.inkMuted,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.outline),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Before your first scan', style: AppTypography.sectionTitle()),
            const SizedBox(height: 12),
            Text(
              'To work out what is on your plate, the photo you take — or the '
              'description you type — is sent to our AI provider, OpenRouter, '
              'which routes it to OpenAI. The same happens with your targets '
              'and your answers when you build a meal plan.',
              style: AppTypography.body(color: AppColors.muted),
            ),
            const SizedBox(height: 10),
            Text(
              'Your name, your email and your account are never sent with it. '
              'Nothing is used to train AI models. Barcode, search and typing '
              'a food in by hand never leave anything with the AI provider.',
              style: AppTypography.body(color: AppColors.muted),
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: 50,
              width: double.infinity,
              child: PrimaryButton(
                label: 'Got it',
                onPressed: () => Navigator.of(context).pop(true),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Semantics(
                button: true,
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(false),
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Text(
                      'Not now',
                      style: AppTypography.socialLabel(
                        color: AppColors.placeholder,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
