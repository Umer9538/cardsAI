import 'package:flutter/material.dart';
import 'package:carbsai/core/design/design_canvas.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:carbsai/features/auth/presentation/login_screen.dart';

import 'support/design_render.dart';
import 'support/screens.dart';

/// Every screen, at every size we care about, must lay out without a render
/// overflow and must keep its bottom-most control reachable.
///
/// The artboards are a fixed 428x926. Before [DesignFit.fit] existed, the
/// canvas scaled with BoxFit.cover, which silently cropped the bottom of the
/// frame: at 375x667 the log-in CTA and footer fell 65pt below the display,
/// and at 834x1194 the artboard scaled 1.95x and buried 433pt.
const List<(String, Size)> _devices = [
  ('iPhone 5 / SE 1st gen', Size(320, 568)),
  ('Android small', Size(360, 640)),
  ('iPhone SE / 8', Size(375, 667)),
  ('iPhone 15', Size(393, 852)),
  ('Pixel 7', Size(412, 915)),
  ('Artboard', Size(428, 926)),
  ('iPhone 15 Pro Max', Size(430, 932)),
  ('iPhone 17 Pro', Size(402, 874)),
  ('iPad mini', Size(744, 1133)),
  ('iPad 10.9"', Size(820, 1180)),
  ('iPad Pro 11"', Size(834, 1194)),
  // The largest display the app actually ships to. iPad was enabled
  // (TARGETED_DEVICE_FAMILY "1,2") without this size being in the sweep, so
  // the biggest iPad Apple reviews on was the one nothing rendered.
  ('iPad Pro 13"', Size(1032, 1376)),
  ('Landscape phone', Size(852, 393)),
];

void main() {
  setUpAll(loadDesignFonts);

  // The suite tested ten viewports and zero text scales, on a canvas whose
  // children are all `Positioned` at fixed coordinates. Text that grows there
  // does not push the next element down, it overlaps it — so dynamic type was
  // structurally guaranteed to break the layout and nothing would have caught
  // it. [DesignCanvas.maxTextScale] is the ceiling the artboard can absorb;
  // this renders every screen at it, which is what makes that number a
  // guarantee rather than an assumption.
  //
  // 3.0 stands in for the largest accessibility sizes iOS and Android offer.
  // The assertion is not that the app honours 3.0 — it clamps — but that
  // asking for it cannot produce a broken screen.
  for (final requested in const [DesignCanvas.maxTextScale, 3.0]) {
    testWidgets('no overflow at ${requested}x text on the artboard', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(428, 926);
      addTearDown(tester.view.reset);

      final scope = await designScopeBuilder();

      for (final (screenName, screen) in appScreens()) {
        await tester.pumpWidget(
          scope(
            MaterialApp(
              debugShowCheckedModeBanner: false,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(requested)),
                child: child!,
              ),
              home: screen,
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 400));

        expect(
          tester.takeException(),
          isNull,
          reason: '$screenName overflowed at ${requested}x text',
        );
      }
    });
  }

  for (final (deviceName, size) in _devices) {
    testWidgets('no overflow on $deviceName (${size.width.toInt()}x'
        '${size.height.toInt()})', (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = size;
      addTearDown(tester.view.reset);

      // One scope for the whole sweep — see designScopeBuilder().
      final scope = await designScopeBuilder();

      for (final (screenName, screen) in appScreens()) {
        await tester.pumpWidget(
          scope(MaterialApp(debugShowCheckedModeBanner: false, home: screen)),
        );
        await tester.pump(const Duration(milliseconds: 400));

        expect(
          tester.takeException(),
          isNull,
          reason: '$screenName overflowed on $deviceName',
        );
      }
    });
  }

  testWidgets('bottom-anchored controls stay on screen at every size', (
    tester,
  ) async {
    // The regression that motivated DesignFit.fit: a CTA sitting at y=761 on
    // the artboard must remain within the viewport, not merely exist in the
    // widget tree.
    for (final (deviceName, size) in _devices) {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = size;

      await tester.pumpWidget(
        await designScope(
          const MaterialApp(
            debugShowCheckedModeBanner: false,
            home: LoginScreen(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));

      final cta = find.text('Log In');
      expect(cta, findsOneWidget, reason: 'CTA missing on $deviceName');

      final scrollable = find.byType(Scrollable);
      if (scrollable.evaluate().isNotEmpty) {
        // Taller than the viewport, so the CTA is reachable by scrolling
        // rather than being clipped away.
        await tester.scrollUntilVisible(cta, 200, scrollable: scrollable.first);
        await tester.pump();
      }

      final box = tester.renderObject<RenderBox>(cta);
      final topLeft = box.localToGlobal(Offset.zero);
      expect(
        topLeft.dy + box.size.height <= size.height + 0.5 && topLeft.dy >= -0.5,
        isTrue,
        reason:
            'CTA off-screen on $deviceName: '
            'y=${topLeft.dy.toStringAsFixed(1)} '
            'h=${box.size.height.toStringAsFixed(1)} '
            'viewport=${size.height}',
      );
    }
    addTearDown(tester.view.reset);
  });
}
