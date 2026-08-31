import 'package:flutter/material.dart';

import '../../../core/design/design_canvas.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../premium/presentation/widgets/premium_widgets.dart';
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
        blocks: help,
        onBack: onBack,
      );

  /// Rough height estimate so the canvas can grow with the copy. Generous by
  /// design — surplus is background, whereas a short canvas would clip.
  double get _contentHeight {
    var h = 147.0;
    for (final b in blocks) {
      h += b.isHeading ? 33 : 22.0 * (1 + b.text.length ~/ 58) + 12;
    }
    return h + 80;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: DesignCanvas(
        background: AppColors.background,
        height: _contentHeight,
        children: [
          PremiumTopBar(title: title, onBack: onBack),
          Positioned(
            left: 20,
            top: 147,
            width: 388,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final (i, block) in blocks.indexed) ...[
                  if (i > 0) SizedBox(height: block.isHeading ? 12 : 8),
                  Text(
                    block.text,
                    style: block.isHeading
                        ? AppTypography.body(color: AppColors.placeholder)
                        : AppTypography.socialLabel(
                            color: AppColors.placeholder),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
