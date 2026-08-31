import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/design/design_canvas.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import 'auth_widgets.dart';

/// Common chrome for the inner auth artboards (Figma frames 09–15): the dark
/// canvas, the circular back button at (20, 71), and the title/subtitle block
/// at (20, 135) and (20, 181).
///
/// Title and subtitle boxes are given the artboard's full 388pt content width
/// rather than the widths Figma reports. Those text nodes are
/// `textAutoResize: WIDTH_AND_HEIGHT`, so their boxes are sized to Figma's cut
/// of Space Grotesk; ours sets wider and would wrap inside them. Both are
/// left-aligned, so widening the box does not move the text.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.children,
    this.onBack,
    this.subtitleHeight = 25,
    this.showBack = true,
    this.overlay,
  });

  final String title;
  final String subtitle;

  /// 25 for a one-line subtitle, 50 for two — matching the artboard.
  final double subtitleHeight;

  final List<Widget> children;
  final VoidCallback? onBack;
  final bool showBack;

  /// Modal content drawn over this screen, inside the same canvas so it scales
  /// and scrolls with it. A separate full-screen overlay would be transformed
  /// independently and drift out of register on any non-artboard size.
  final Widget? overlay;

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
        // These artboards are fixed compositions with bottom-pinned CTAs;
        // letting the keyboard resize them would move those off their marks.
        // The keyboard must be allowed to shrink the viewport.
        //
        // With this false — which is what fidelity to the artboard wanted — the
        // canvas keeps its full height behind the keyboard and the submit
        // button, which the design pins near the bottom, becomes physically
        // unreachable while typing. Letting the viewport shrink makes
        // DesignCanvas taller than its space, which turns it into a scroll, so
        // the button is always reachable.
        resizeToAvoidBottomInset: true,
        body: DesignCanvas(
          background: AppColors.background,
          children: [
            if (showBack)
              Positioned(
                left: 20,
                top: 71,
                width: 40,
                height: 40,
                child: BackCircleButton(onTap: onBack),
              ),
            Positioned(
              left: 20,
              top: 135,
              width: 388,
              height: 42,
              child: Text(title, style: AppTypography.authTitle()),
            ),
            Positioned(
              left: 20,
              top: 181,
              width: 388,
              height: subtitleHeight,
              child: Text(subtitle, style: AppTypography.body()),
            ),
            ...children,
            ?overlay,
          ],
        ),
      ),
    );
  }
}
