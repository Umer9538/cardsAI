import 'package:flutter/material.dart';

import '../../../../core/design/design_canvas.dart';
import '../../../../core/theme/app_colors.dart';

/// A primary action pinned to the viewport above a scrolling canvas.
///
/// Both screens that build a meal — search and scan result — put their button
/// at the artboard's y=832. On a canvas that grows with its content that number
/// is a position in the *scroll*, so the button rides up into the middle of the
/// list; pinning it to the viewport instead is the same move
/// `AppBottomNav` makes.
///
/// The band behind it is the other half. A button pinned over a list with
/// nothing behind it slices whichever row it happens to land on, which reads as
/// a control that has come loose rather than one that is deliberately floating.
/// The gradient rather than a hard edge because the list scrolls under it
/// continuously — a hard line would look like the end of the content, and there
/// is more of it.
class PinnedCta extends StatelessWidget {
  const PinnedCta({super.key, required this.child});

  /// The button itself, drawn at the artboard's 388 x 50.
  final Widget child;

  /// Artboard y of the button's top edge.
  static const double top = 832;

  /// What the band covers, measured from the bottom of the viewport.
  static const double height = DesignCanvas.designHeight - top + 44;

  /// Room a scrolling canvas owes beneath its content so the last row can rise
  /// clear of the band rather than stopping behind it.
  static const double clearance =
      DesignCanvas.designHeight - top + 16;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      height: height,
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.background.withValues(alpha: 0),
                      AppColors.background,
                      AppColors.background,
                    ],
                    stops: const [0, 0.42, 1],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: DesignCanvas.designHeight - top - 50,
            child: Center(
              child: SizedBox(width: 388, height: 50, child: child),
            ),
          ),
        ],
      ),
    );
  }
}
