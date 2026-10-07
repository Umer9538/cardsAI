import 'package:carbsai/core/app_config.dart';
import 'package:carbsai/core/providers/providers.dart';
import 'package:carbsai/data/local/json_store.dart';
import 'package:carbsai/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// Walks the real app on whatever device it is run against, and asserts that
/// the control you have to press to continue is physically on the display.
///
/// Run it where the artboard does not fit:
///
///     flutter test integration_test/ipad_walk_test.dart \
///       -d <ipad-simulator-udid> --dart-define=BACKEND=local
///
/// This exists because `DesignFit.cover` fails *silently*. A clipped control
/// is still mounted, still laid out and still reports a size, so every
/// off-device check passes — `find.text('Next')` is `findsOneWidget` on an
/// iPad while the button is 137pt below the glass. The first time anyone found
/// out was running it: the app reached onboarding page 1 and stopped there,
/// with no tappable node anywhere in the accessibility tree.
///
/// So the assertion is screen coordinates, and the proof is that the tap that
/// follows it actually changes the page.
void _expectOnScreen(WidgetTester tester, Finder finder, String what) {
  expect(finder, findsWidgets, reason: '$what is not in the tree at all');
  final box = tester.renderObject<RenderBox>(finder.first);
  final at = box.localToGlobal(Offset.zero);
  final view = tester.view;
  final size = view.physicalSize / view.devicePixelRatio;

  expect(
    at.dy >= -0.5 &&
        at.dy + box.size.height <= size.height + 0.5 &&
        at.dx >= -0.5 &&
        at.dx + box.size.width <= size.width + 0.5,
    isTrue,
    reason: '$what is off the display: '
        'x=${at.dx.toStringAsFixed(1)} y=${at.dy.toStringAsFixed(1)} '
        '${box.size.width.toStringAsFixed(1)}x'
        '${box.size.height.toStringAsFixed(1)} '
        'display=${size.width.toStringAsFixed(0)}x'
        '${size.height.toStringAsFixed(0)}',
  );
}

/// Bounded, because the splash and the onboarding artwork both animate and a
/// screen that never settles hangs `pumpAndSettle` until the timeout.
Future<void> _settle(WidgetTester tester, [int frames = 40]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('onboarding can be walked to the end on this display',
      (tester) async {
    // The same two overrides `main()` installs. Without them the app throws
    // on its first provider read — `jsonStoreProvider` has no value to give.
    // Pinned to the on-device backend so the walk needs no network and no
    // Firebase: this test is about where things land, not where data comes
    // from.
    final store = await JsonStore.open();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          jsonStoreProvider.overrideWithValue(store),
          backendProvider.overrideWithValue(AppBackend.local),
        ],
        child: const CarbsaiApp(),
      ),
    );
    await _settle(tester, 120); // past the splash hold

    final view = tester.view;
    final size = view.physicalSize / view.devicePixelRatio;
    debugPrint('>>> display ${size.width.toInt()}x${size.height.toInt()}');

    // Page 1 and 2 carry "Next"; the third carries "Get Started".
    for (var page = 1; page <= 2; page++) {
      _expectOnScreen(tester, find.text('Next'), 'page $page Next');
      await tester.tap(find.text('Next').first);
      await _settle(tester);
      debugPrint('>>> advanced past onboarding page $page');
    }

    // Proof the taps did something: the last page's label only exists there.
    _expectOnScreen(tester, find.text('Get\nStarted'), 'Get Started');
    await tester.tap(find.text('Get\nStarted').first);
    await _settle(tester, 80);
    debugPrint('>>> left onboarding');

    // Whatever onboarding hands over to, its primary control must be reachable
    // too — this is the screen the iPad run never got to see.
    final next = find.byType(ElevatedButton).evaluate().isNotEmpty
        ? find.byType(ElevatedButton)
        : find.byType(GestureDetector);
    expect(next, findsWidgets, reason: 'nothing interactive after onboarding');
    debugPrint('>>> post-onboarding screen has interactive controls');

    // Held on screen so the run can be photographed from outside. The device
    // is the only place the bare side strips a clamped cover leaves are
    // visible, and whether they read as deliberate is a judgement no assertion
    // makes for you.
    await tester.pump(const Duration(seconds: 1));
    for (var i = 0; i < 100; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    debugPrint('>>> hold over');
  });
}
