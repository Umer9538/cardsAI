import 'package:carbsai/core/design/design_canvas.dart';
import 'package:carbsai/features/onboarding/presentation/onboarding_screen.dart';
import 'package:carbsai/features/scan/presentation/scanning_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/design_render.dart';

/// `DesignFit.cover` screens must keep their controls on screen.
///
/// `responsive_overflow_test` sweeps every screen at every size, but it asserts
/// two things that both pass here: that nothing throws a render overflow, and
/// that *the login screen's* CTA stays reachable. Neither catches this, because
/// `cover` does not overflow — it **clips**, silently, and the screen it clips
/// is not the one being measured.
///
/// What cover actually shows is `428 / aspect` artboard units of height, so the
/// taller the viewport is relative to its width, the more of the bottom goes:
///
/// | viewport            | aspect | visible artboard units |
/// |---------------------|--------|------------------------|
/// | 428x926 (artboard)  | 0.462  | 926 — all of it        |
/// | 375x667 (iPhone SE) | 0.562  | 761                    |
/// | 1032x1376 (iPad 13) | 0.750  | 571                    |
///
/// Onboarding's Next button sits at y=788..888 and the scanning screen's
/// shutter at y=789..845, so both are **off the display** on an iPad — the
/// button is not merely invisible, it is not in the hit-test region, which is
/// why an iPad run of this app got stuck on the first onboarding page with no
/// tappable node anywhere in the accessibility tree.
const List<(String, Size)> _viewports = [
  ('iPhone SE / 8', Size(375, 667)),
  ('iPhone 15', Size(393, 852)),
  ('Artboard', Size(428, 926)),
  ('iPad mini', Size(744, 1133)),
  ('iPad Pro 11"', Size(834, 1194)),
  ('iPad Pro 13"', Size(1032, 1376)),
];

/// Asserts the widget [finder] renders fully inside the viewport.
///
/// `findsOneWidget` is not enough and that is the whole point of this file: a
/// clipped `Positioned` is still in the tree, still laid out, and still
/// reports a size. Only its screen coordinates reveal that nobody can reach it.
void _expectOnScreen(
  WidgetTester tester,
  Finder finder,
  Size viewport,
  String what,
) {
  expect(finder, findsWidgets, reason: '$what is missing entirely');
  final box = tester.renderObject<RenderBox>(finder.first);
  final topLeft = box.localToGlobal(Offset.zero);
  final bottom = topLeft.dy + box.size.height;
  final right = topLeft.dx + box.size.width;

  expect(
    topLeft.dy >= -0.5 &&
        bottom <= viewport.height + 0.5 &&
        topLeft.dx >= -0.5 &&
        right <= viewport.width + 0.5,
    isTrue,
    reason: '$what is off-screen: '
        'x=${topLeft.dx.toStringAsFixed(1)} '
        'y=${topLeft.dy.toStringAsFixed(1)} '
        '${box.size.width.toStringAsFixed(1)}x'
        '${box.size.height.toStringAsFixed(1)} '
        'viewport=${viewport.width.toInt()}x${viewport.height.toInt()}',
  );
}

void main() {
  testWidgets('onboarding Next stays reachable on every viewport',
      (tester) async {
    addTearDown(tester.view.reset);
    final scope = await designScopeBuilder();

    for (final (name, size) in _viewports) {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = size;

      await tester.pumpWidget(
        scope(const MaterialApp(
          debugShowCheckedModeBanner: false,
          home: OnboardingScreen(),
        )),
      );
      await tester.pump(const Duration(milliseconds: 400));

      _expectOnScreen(tester, find.text('Next'), size, '$name: Next button');
    }
  });

  testWidgets('the scanning shutter and its strip stay reachable',
      (tester) async {
    addTearDown(tester.view.reset);
    final scope = await designScopeBuilder();

    for (final (name, size) in _viewports) {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = size;

      await tester.pumpWidget(
        scope(const MaterialApp(
          debugShowCheckedModeBanner: false,
          home: ScanningScreen(),
        )),
      );
      await tester.pump(const Duration(milliseconds: 400));

      // Discard the strip's horizontal overflow, which is the test font and
      // not this screen.
      //
      // `flutter test` draws in Ahem, whose every glyph is a square em, so the
      // strip measures 11x17 + 12 + 17 + 12 + 12x17 = 432 against its 388 box
      // and reports exactly 44px. Real Space Grotesk at 17pt needs about 246.
      // Overflow is `responsive_overflow_test`'s job in any case; this file is
      // only about where things land.
      final overflow = tester.takeException();
      if (overflow != null) {
        expect(
          overflow.toString(),
          contains('overflowed'),
          reason: '$name: unexpected exception on the scanning screen',
        );
      }

      // The only route to the two non-photo paths. Clipped, the mode is a
      // camera with no way out of it.
      _expectOnScreen(
        tester,
        find.text('Describe it'),
        size,
        '$name: Describe it',
      );
    }
  });

  test('cover tells callers how much of the artboard a viewport can show', () {
    // The arithmetic the table in this file's doc comment states, so the table
    // cannot drift away from the implementation.
    expect(DesignCanvas.coverVisibleHeight(const Size(428, 926)), closeTo(926, 0.5));
    expect(DesignCanvas.coverVisibleHeight(const Size(375, 667)), closeTo(761, 0.5));
    expect(DesignCanvas.coverVisibleHeight(const Size(1032, 1376)), closeTo(571, 0.5));
  });
}
