import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/design/design_canvas.dart';
import '../../../core/models/models.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../auth/presentation/widgets/auth_widgets.dart';
import 'widgets/premium_widgets.dart';

/// Plan details — Figma frames `18_Monthly Plan` (2002:1600) and
/// `19_Annual Plan` (2002:1505).
///
/// The two artboards are pixel-identical apart from the title, three of the
/// five feature lines, and the price in the CTA, so this is one screen driven
/// by a [SubscriptionPlan].
class PlanDetailScreen extends StatelessWidget {
  const PlanDetailScreen({
    super.key,
    required this.plan,
    this.onBack,
    this.onContinue,
  });

  final SubscriptionPlan plan;
  final VoidCallback? onBack;
  final VoidCallback? onContinue;

  @override
  Widget build(BuildContext context) {
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
            PremiumTopBar(title: plan.name, onBack: onBack),
            const DesignImage(
              asset: 'assets/images/premium/illus_upgrade.png',
              left: 67,
              top: 177,
              width: 295,
              height: 151,
            ),
            Positioned(
              left: 20,
              top: 382,
              width: 388,
              height: 42,
              child: Text(
                'Upgrade to Premium',
                style: AppTypography.authTitle(),
                textAlign: TextAlign.center,
              ),
            ),
            Positioned(
              left: 32,
              top: 456,
              width: 376,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final (i, feature) in plan.features.indexed) ...[
                    if (i > 0) const SizedBox(height: 16),
                    FeatureRow(text: feature),
                  ],
                ],
              ),
            ),
            Positioned(
              left: 20,
              top: 810,
              width: 388,
              height: 50,
              child: PrimaryButton(
                label: 'Continue with ${plan.priceLabel}',
                onPressed: onContinue,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
