import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';

/// Shared pieces of the premium flow (Figma frames 16–22).

/// The `TopBar` component: an optional 40pt circular button at x=20, y=71 and
/// a 24/36 title beside it at x=80. Frame 16 uses the close variant on the
/// right instead of a back button on the left.
class PremiumTopBar extends StatelessWidget {
  const PremiumTopBar({super.key, this.title, this.onBack, this.onClose});

  final String? title;
  final VoidCallback? onBack;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        if (onBack != null)
          Positioned(
            left: 20,
            top: 71,
            width: 40,
            height: 40,
            child: _CircleIconButton(
              asset: 'assets/images/auth/back_button.png',
              onTap: onBack,
            ),
          ),
        if (onClose != null)
          Positioned(
            left: 368,
            top: 71,
            width: 40,
            height: 40,
            child: _CircleIconButton(
              asset: 'assets/images/premium/close_button.png',
              onTap: onClose,
            ),
          ),
        if (title != null)
          Positioned(
            left: 80,
            top: 73,
            // The artboard sizes this box to the text; ours sets wider, so it
            // gets the remaining width to the right instead of wrapping.
            width: 328,
            height: 36,
            child: Text(title!, style: AppTypography.topBarTitle()),
          ),
      ],
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({required this.asset, this.onTap});

  final String asset;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Image.asset(
        asset,
        width: 40,
        height: 40,
        filterQuality: FilterQuality.high,
      ),
    );
  }
}

/// "$4.99" at 34/51 with the period suffix dropped to 18/27, per the
/// character-level style run on the `Plan Price` node.
class PlanPrice extends StatelessWidget {
  const PlanPrice({super.key, required this.amount, required this.period});

  /// e.g. `$4.99`
  final String amount;

  /// e.g. `/Month`
  final String period;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        text: amount,
        style: AppTypography.planPrice(),
        children: [TextSpan(text: period, style: AppTypography.planPeriod())],
      ),
    );
  }
}

/// A plan line: title, price, and a trailing chevron.
///
/// Used by the chooser on frame 17 and the summary card on frame 21. The two
/// differ only in the gap between title and price — 4pt in the chooser (an
/// 85pt row) and 1pt in the summary (82pt) — and the summary's card allows
/// exactly 82, so a hardcoded 85 overflows it by 3.
class PlanRow extends StatelessWidget {
  const PlanRow({
    super.key,
    required this.title,
    required this.amount,
    required this.period,
    this.gap = 4,
    this.onTap,
  });

  final String title;
  final String amount;
  final String period;
  final double gap;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        // The chevron sits on the row's vertical centre in both artboards
        // (offset 31 in an 85pt row, 29 in an 82pt one), so centring it here
        // covers both without a magic number.
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            // The title had a fixed 30pt box around it, which is exactly its
            // natural height at the artboard's own text size — and therefore
            // its ceiling too, so one notch of OS text scaling overflowed it.
            // Letting the text size itself costs nothing at 1.0 and simply
            // grows the row past it.
            // scaleDown, and only here.
            //
            // The review-summary card gives this row 82pt inside a 130pt box
            // that the artboard fills exactly, so there is no slack at all —
            // one notch of OS text scaling and the column is 13pt over. The
            // rest of the app absorbs scaling up to
            // [DesignCanvas.maxTextScale]; this one card cannot, and capping
            // the whole app to protect it would be the wrong trade. scaleDown
            // is a no-op at the artboard's own size and shrinks the block
            // uniformly above it, so the row stays legible and stays inside its
            // card. If this card is ever redrawn with room to breathe, delete
            // the FittedBox.
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: AppTypography.sectionTitle(color: AppColors.ink),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: gap),
                  PlanPrice(amount: amount, period: period),
                ],
              ),
            ),
          ),
          // Chevron only. The visually similar onboarding arrow is a
          // different variant of the same component — it carries a
          // 40%-opacity shaft that this one does not — so it is exported
          // separately rather than reused and tinted.
          Image.asset(
            'assets/images/premium/chevron_right.png',
            width: 24,
            height: 24,
            filterQuality: FilterQuality.high,
          ),
        ],
      ),
    );
  }
}

/// A checked feature line on frames 18 and 19: 20pt icon, 12pt gap, 17/25 copy.
class FeatureRow extends StatelessWidget {
  const FeatureRow({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 25,
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2.5),
            child: Image.asset(
              'assets/images/premium/icon_check.png',
              width: 20,
              height: 20,
              filterQuality: FilterQuality.high,
            ),
          ),
          const SizedBox(width: 12),
          Text(text, style: AppTypography.body()),
        ],
      ),
    );
  }
}
