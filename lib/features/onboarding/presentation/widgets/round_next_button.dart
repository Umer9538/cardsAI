import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';

/// The dark circle CTA the onboarding artboards end on.
///
/// Frames 02 and 03 show "Next" above an arrow glyph; frame 04 replaces both
/// with a two-line "Get Started" and no icon. Shared with the quiz, which is
/// not in the design file and borrows this so it reads as the same flow rather
/// than something bolted on afterwards.
///
/// Sits at (165, 788) on the artboard, 100x100, over `blob.png` at (109, 738).
class RoundNextButton extends StatelessWidget {
  const RoundNextButton({
    super.key,
    required this.onTap,
    this.label = 'Next',
    this.showArrow = true,
    this.enabled = true,
  });

  final VoidCallback? onTap;

  /// A newline renders as the artboard's two-line "Get\nStarted".
  final String label;
  final bool showArrow;

  /// Dimmed and inert until the step has an answer.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.35,
      child: Material(
        color: AppColors.ink,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled ? onTap : null,
          child: Center(
            child: showArrow
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(label, style: AppTypography.buttonLabel()),
                      const SizedBox(height: 4),
                      Image.asset(
                        'assets/images/onboarding/arrow_right.png',
                        width: 24,
                        height: 24,
                        filterQuality: FilterQuality.high,
                      ),
                    ],
                  )
                : Text(
                    label,
                    style: AppTypography.buttonLabel(),
                    textAlign: TextAlign.center,
                  ),
          ),
        ),
      ),
    );
  }
}
