import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/design_canvas.dart';
import '../../../core/models/models.dart';
import '../../../core/providers/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/hero_card.dart';
import 'widgets/premium_widgets.dart';

/// Plan chooser — Figma frame `17_Premium` (2002:1695).
class PremiumPlansScreen extends ConsumerWidget {
  const PremiumPlansScreen({super.key, this.onBack, this.onSelect});

  final VoidCallback? onBack;
  final ValueChanged<SubscriptionPlan>? onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plans = ref.watch(subscriptionRepositoryProvider).plans;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: AppColors.background,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: DesignCanvas(
          background: AppColors.background,
          children: [
            PremiumTopBar(title: 'Premium', onBack: onBack),

            // Lilac header card.
            Positioned(
              left: 20,
              top: 147,
              width: 388,
              height: 128,
              child: const HeroCard(
                colour: AppColors.lilac,
                ink: AppColors.ink,
                title: 'Take Nutrition to the Next Level',
                body: 'Smarter tracking. Deeper insights. Real results.',
              ),
            ),

            // Yellow plan card holding both rows and their divider.
            Positioned(
              left: 20,
              top: 295,
              width: 388,
              child: Container(
                constraints: const BoxConstraints(minHeight: 251),
                decoration: BoxDecoration(
                  color: AppColors.planYellow,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.outline),
                ),
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final (i, plan) in plans.indexed) ...[
                      if (i > 0) ...[
                        const SizedBox(height: 16),
                        // #121212 at 10% — the file's hairline between plans.
                        const Divider(
                          height: 1,
                          thickness: 1,
                          color: Color(0x1A121212),
                        ),
                        const SizedBox(height: 16),
                      ],
                      PlanRow(
                        title: plan.name,
                        amount: plan.priceLabel,
                        period: plan.periodLabel,
                        onTap: onSelect == null ? null : () => onSelect!(plan),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
