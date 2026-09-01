import 'package:flutter/material.dart';

import '../../../../core/design/design_canvas.dart';
import '../../../../core/theme/app_colors.dart';

/// The five destinations in the floating tab bar.
enum AppTab {
  home('assets/images/app/nav_home.png'),
  analysis('assets/images/app/nav_analysis.png'),
  scan('assets/images/app/nav_scan.png'),
  diets('assets/images/app/nav_diets.png'),
  settings('assets/images/app/nav_settings.png');

  const AppTab(this.icon);
  final String icon;
}

/// Floating tab bar — Figma `Master bottom Menu`.
///
/// A 314x66 pill at (57, 806) filled #2F2F2F with a 14pt shadow, holding five
/// 54pt circles at 62pt centres. The selected circle is #FF5A16, the rest
/// #474747; the glyph is white in both states, so only the disc colour is
/// driven by selection.
///
/// The bar is drawn rather than exported as one image so it stays interactive
/// and so a single asset set covers every screen's active tab.
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({super.key, required this.current, this.onSelect});

  final AppTab current;
  final ValueChanged<AppTab>? onSelect;

  /// Artboard geometry, so callers can position the bar consistently.
  static const double left = 57;
  static const double top = 806;
  static const double width = 314;
  static const double height = 66;

  /// Room a scrolling canvas must leave beneath its last content.
  ///
  /// The bar is pinned to the *viewport*, not to the canvas, so the bottom
  /// `designHeight - top` units of every scroll sit underneath it. A canvas
  /// that ends flush with its content therefore has a final row that cannot be
  /// read however far you scroll — the bar simply sits on it. Screens were
  /// leaving 96, which is 24 short before any breathing room at all.
  ///
  /// The extra 20 is that breathing room, so the last row clears the bar rather
  /// than touching it.
  static const double clearance =
      DesignCanvas.designHeight - top + 20;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.outline,
        borderRadius: BorderRadius.circular(100),
        boxShadow: const [
          BoxShadow(color: Color(0x3D000000), blurRadius: 14),
        ],
      ),
      padding: const EdgeInsets.all(6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (final tab in AppTab.values)
            _NavButton(
              tab: tab,
              selected: tab == current,
              onTap: onSelect == null ? null : () => onSelect!(tab),
            ),
        ],
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({required this.tab, required this.selected, this.onTap});

  final AppTab tab;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 54,
        height: 54,
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.muted,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Image.asset(
          tab.icon,
          width: 24,
          height: 24,
          filterQuality: FilterQuality.high,
        ),
      ),
    );
  }
}
