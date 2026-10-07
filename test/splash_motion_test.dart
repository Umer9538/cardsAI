import 'package:carbsai/features/splash/presentation/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The splash is also the app's *loading* screen — `main.dart` shows it with no
/// `onFinished` while the stored session is read back, for an unknown length of
/// time. That is what these guard.
void main() {
  double pillWidth(WidgetTester tester) {
    final clip = tester.widget<ClipRect>(
      find.ancestor(of: find.text('healthy'), matching: find.byType(ClipRect)).first,
    );
    return clip.clipper!.getClip(const Size(114, 36)).width;
  }

  testWidgets('the entrance plays and lands on the artboard', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SplashScreen()));

    // First frame: the pill has not started wiping.
    expect(pillWidth(tester), 0);

    await tester.pump(const Duration(milliseconds: 1600));
    expect(pillWidth(tester), closeTo(114, 0.5));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the entrance does not replay while it stands in for a wait',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SplashScreen()));
    await tester.pump(const Duration(milliseconds: 1600));

    // One controller used to drive both the entrance and the idle sway, and
    // it repeated — so under a wait the cards dealt themselves out and back
    // in, forever. The sway is on its own clock now.
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 500));
      expect(pillWidth(tester), closeTo(114, 0.5), reason: 'frame $i');
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion gets the finished frame immediately',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: SplashScreen(),
        ),
      ),
    );

    // Not a frozen first frame, which is what a naive `if (still) return`
    // around the controller would give.
    expect(pillWidth(tester), closeTo(114, 0.5));
  });

  testWidgets('it still hands over after its duration', (tester) async {
    var done = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: SplashScreen(
          duration: const Duration(milliseconds: 900),
          onFinished: () => done++,
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 600));
    expect(done, 0);
    await tester.pump(const Duration(milliseconds: 500));
    expect(done, 1);

    // The screen is torn down right after; nothing may fire twice or tick on.
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await tester.pump(const Duration(seconds: 2));
    expect(done, 1);
    expect(tester.takeException(), isNull);
  });
}
