import 'package:flutter/material.dart';

import '../../../core/design/design_canvas.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../premium/presentation/widgets/premium_widgets.dart';
import '../../../core/nutrition/dish_photo_credits.dart';
import 'legal_content.dart';

/// Long-form text page — Figma frames `43_Terms and Conditions` (2002:804),
/// `44_Privacy Policy` (2002:781) and `45_Help` (2002:757).
///
/// One screen for all three: they differ only in title and copy. Content runs
/// well past the artboard, so the canvas is sized from the text and scrolls.
class LegalPageScreen extends StatelessWidget {
  const LegalPageScreen({
    super.key,
    required this.title,
    required this.blocks,
    this.onBack,
  });

  final String title;
  final List<LegalBlock> blocks;
  final VoidCallback? onBack;

  /// Convenience constructors for the three artboards.
  factory LegalPageScreen.terms({VoidCallback? onBack}) => LegalPageScreen(
        title: 'Terms and Conditions',
        blocks: termsAndConditions,
        onBack: onBack,
      );

  factory LegalPageScreen.privacy({VoidCallback? onBack}) => LegalPageScreen(
        title: 'Privacy Policy',
        blocks: privacyPolicy,
        onBack: onBack,
      );

  factory LegalPageScreen.help({VoidCallback? onBack}) => LegalPageScreen(
        title: 'Help',
        // Photo credits at the foot: CC BY requires the creator to be named
        // somewhere a person can read, and Help is the page people open.
        blocks: [...help, ...DishPhotoCredits.blocks],
        onBack: onBack,
      );

  /// Room the canvas has to reserve for the copy.
  ///
  /// An estimate, because `DesignCanvas` needs its height before the text is
  /// laid out. Deliberately generous: surplus is background you can scroll
  /// past, whereas an under-estimate clips the end of the document — and the
  /// end of a policy is where the contact address is.
  ///
  /// 44 characters a line, not 58. 15pt Space Grotesk across the 388pt column
  /// wraps at around 46, and the old figure only looked right because the
  /// original copy was made of short lines. Rewriting the policy into real
  /// paragraphs was exactly the case it got wrong.
  double get _contentHeight {
    var h = 147.0;
    for (final b in blocks) {
      h += b.isHeading ? 33 : 22.0 * (1 + b.text.length ~/ 44) + 12;
    }
    return h + 120;
  }

  /// Exposed so a test can check the estimate against what actually rendered.
  @visibleForTesting
  double get reservedHeight => _contentHeight;

  /// Artboard height of the pinned band: the bar sits at y=71 and is 40 tall.
  static const double _barBand = 130;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      // The scale has to be known here so the pinned bar can be given a real
      // height. A full-bleed overlay would swallow every scroll gesture on the
      // page underneath — which it did, on the first attempt at this.
      body: LayoutBuilder(
        builder: (context, constraints) {
          final scale = (constraints.maxWidth / DesignCanvas.designWidth)
              .clamp(0.0, DesignCanvas.defaultMaxScale);
          final band = _barBand * scale;

          return Stack(
            children: [
              DesignCanvas(
                background: AppColors.background,
                height: _contentHeight,
                children: [
                  Positioned(
                    left: 20,
                    // Below the pinned bar, where the artboard's own bar used
                    // to be drawn as the canvas's first child.
                    top: 147,
                    width: 388,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final (i, block) in blocks.indexed) ...[
                          if (i > 0)
                            SizedBox(height: block.isHeading ? 12 : 8),
                          Text(
                            block.text,
                            style: block.isHeading
                                ? AppTypography.body(
                                    color: AppColors.placeholder,
                                  )
                                : AppTypography.socialLabel(
                                    color: AppColors.placeholder,
                                  ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),

              // Pinned to the viewport, not carried by the canvas.
              //
              // These documents run to several screens, and the bar scrolled
              // away with everything else — so the only way back was the
              // system gesture, or scrolling all the way up again. The privacy
              // policy is exactly the screen someone opens, reads a paragraph
              // of, and wants to leave. Same debt the floating tab bar charges,
              // at the other end of the screen.
              //
              // On a fading band so the text passes behind it rather than
              // through the glyph.
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                height: band,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          AppColors.background,
                          AppColors.background,
                          AppColors.background.withValues(alpha: 0),
                        ],
                        stops: const [0, 0.66, 1],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                height: band,
                child: DesignCanvas(
                  background: Colors.transparent,
                  height: _barBand,
                  children: [PremiumTopBar(title: title, onBack: onBack)],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
