import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/design/design_canvas.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../auth/presentation/widgets/auth_widgets.dart';
import 'widgets/premium_widgets.dart';

/// Premium offer — Figma frame `16_Premium offer` (2002:1713).
///
/// The only frame in the flow with a close button rather than a back button,
/// and the only one offering a way past the paywall ("Skip").
class PremiumOfferScreen extends StatelessWidget {
  const PremiumOfferScreen({super.key, this.onClose, this.onUpgrade, this.onSkip});

  final VoidCallback? onClose;
  final VoidCallback? onUpgrade;
  final VoidCallback? onSkip;

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
            // Decorative wash behind the header, at 30% opacity in the file.
            const DesignImage(
              asset: 'assets/images/premium/bg_graphics.png',
              left: 34,
              top: 86,
              width: 364.33,
              height: 231,
              opacity: 0.3,
            ),
            PremiumTopBar(onClose: onClose),
            Positioned(
              left: 53,
              top: 173,
              width: 322,
              height: 42,
              child: Text(
                'One Time Offer',
                style: AppTypography.authTitle(),
                textAlign: TextAlign.center,
              ),
            ),
            Positioned(
              left: 53,
              top: 227,
              width: 322,
              height: 50,
              child: Text(
                'Unlock smarter nutrition with AI-powered tools.',
                style: AppTypography.body(),
                textAlign: TextAlign.center,
              ),
            ),
            const DesignImage(
              asset: 'assets/images/premium/illus_gifts.png',
              left: 55,
              top: 366,
              width: 318,
              height: 199,
            ),
            Positioned(
              left: 53,
              top: 619,
              width: 322,
              height: 42,
              child: Text(
                '50% OFF Your First Year',
                style: AppTypography.authTitle(),
                textAlign: TextAlign.center,
              ),
            ),
            Positioned(
              left: 20,
              top: 693,
              width: 388,
              height: 50,
              child: PrimaryButton(
                label: 'Go With Premium',
                onPressed: onUpgrade,
              ),
            ),
            Positioned(
              left: 20,
              top: 767,
              width: 388,
              height: 27,
              child: GestureDetector(
                onTap: onSkip,
                behavior: HitTestBehavior.opaque,
                child: Text(
                  'Skip',
                  style: AppTypography.buttonLabel(color: AppColors.muted),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
