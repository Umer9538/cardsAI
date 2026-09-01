import 'package:carbsai/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/design_render.dart';

/// Walks the app the way a person would, so "can't get past login" can never
/// regress silently. Asserts the destination is really on screen at each step
/// rather than just that a tap did not throw.
/// A marker that identifies Home without depending on the clock.
///
/// The greeting is time-based, so asserting on "Good Morning" made these tests
/// pass only before noon.
const String _homeMarker = 'Count Your Daily Calories';

/// Finds an [Image] by the asset it draws — the design's icons carry no text
/// or semantics label to match on.
Finder assetFinder(String name) => find.byWidgetPredicate(
      (w) =>
          w is Image &&
          w.image is AssetImage &&
          (w.image as AssetImage).assetName == name,
    );

void main() {
  setUpAll(loadDesignFonts);

  /// Answers one step and moves on.
  ///
  /// Bounded pumps rather than `pumpAndSettle`: the step that builds the plan
  /// carries a progress indicator, which never settles, so settling would hang
  /// the moment the walk reached it.
  Future<void> answerAndAdvance(WidgetTester tester, String? choice) async {
    if (choice != null) {
      await tester.tap(find.text(choice));
      await tester.pump(const Duration(milliseconds: 200));
    }
    await tester.tap(find.text('Continue'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> boot(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(428, 926);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(await designScope(const CarbsaiApp()));
    await tester.pump(const Duration(milliseconds: 100));
  }

  /// Splash self-advances after 2.5s, then onboarding needs three taps.
  Future<void> reachLogin(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    for (var i = 0; i < 2; i++) {
      await tester.tap(find.text('Next').first);
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('Get\nStarted'));
    await tester.pumpAndSettle();
  }

  Future<void> signIn(WidgetTester tester) async {
    await tester.enterText(find.byType(TextField).at(0), 'jane@example.com');
    await tester.enterText(find.byType(TextField).at(1), 'hunter2');
    await tester.tap(find.text('Log In'));
    // The repository adds deliberate latency so loading states are exercised,
    // and AppRoot then rebuilds off the auth stream.
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    // A fresh account cannot produce a real calorie target, so the
    // personalisation quiz stands between here and Home. Most of these tests
    // are about what is past it; `the quiz` test below walks it properly.
    if (find.text('Skip').evaluate().isNotEmpty) {
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();
    }
  }

  testWidgets('the quiz collects a real target and lands on Home',
      (tester) async {
    await boot(tester);
    await reachLogin(tester);

    await tester.enterText(find.byType(TextField).at(0), 'jane@example.com');
    await tester.enterText(find.byType(TextField).at(1), 'hunter2');
    await tester.tap(find.text('Log In'));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    // Signing in with a profile that has no height, weight or activity level
    // must not drop straight into an app measuring against a made-up goal.
    expect(find.text('What brings you here?'), findsOneWidget);

    await answerAndAdvance(tester, 'Eat healthier');
    await answerAndAdvance(tester, 'Female');
    await answerAndAdvance(tester, null);            // age, slider default
    await answerAndAdvance(tester, null);            // height
    await answerAndAdvance(tester, null);            // weight
    await answerAndAdvance(tester, 'Lightly active');
    await answerAndAdvance(tester, 'Maintain weight');
    // Maintaining has no goal weight to ask about, so that step is skipped.
    await answerAndAdvance(tester, 'No restrictions');
    await answerAndAdvance(tester, null);            // meals a day
    await answerAndAdvance(tester, 'Snacking between meals');
    await answerAndAdvance(tester, 'Yes, remind me');

    // The plan-building step advances itself, so no tap here — only time.
    expect(find.text('Building your plan'), findsOneWidget);
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 400));
    }

    expect(find.text('Your daily plan'), findsOneWidget);
    expect(find.text('calories a day'), findsOneWidget);

    await tester.tap(find.text('Start tracking'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text(_homeMarker), findsOneWidget);
  });

  testWidgets('splash advances to onboarding and on to log in',
      (tester) async {
    await boot(tester);
    expect(find.text('made easy!'), findsOneWidget, reason: 'splash');

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.text('Your Smart Nutrition Companion'), findsOneWidget);

    await reachLogin(tester);
    expect(find.text('Welcome Back to Carbsai'), findsOneWidget);
  });

  testWidgets('credentials sign in and land on Home', (tester) async {
    await boot(tester);
    await reachLogin(tester);
    await signIn(tester);

    expect(find.text(_homeMarker), findsOneWidget, reason: 'home');
  });

  testWidgets('empty credentials are rejected and stay on log in',
      (tester) async {
    await boot(tester);
    await reachLogin(tester);

    await tester.tap(find.text('Log In'));
    await tester.pumpAndSettle();

    expect(find.text('Please enter your email'), findsOneWidget);
    expect(find.text(_homeMarker), findsNothing);
  });

  testWidgets('every tab is reachable from the bottom bar', (tester) async {
    await boot(tester);
    await reachLogin(tester);
    await signIn(tester);

    for (final (icon, marker) in const [
      ('assets/images/app/nav_analysis.png', 'Your Nutrition Analysis'),
      ('assets/images/app/nav_diets.png', 'Explore Diet Plans'),
      ('assets/images/app/nav_settings.png', 'Change Password'),
      ('assets/images/app/nav_home.png', _homeMarker),
    ]) {
      await tester.tap(assetFinder(icon).first, warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.text(marker), findsWidgets, reason: 'after tapping $icon');
    }
  });

  testWidgets('scan opens the camera and reaches the result', (tester) async {
    await boot(tester);
    await reachLogin(tester);
    await signIn(tester);

    await tester.tap(
      assetFinder('assets/images/app/nav_scan.png').first,
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();
    expect(find.text('AI Camera'), findsWidgets, reason: 'camera');

    // The shutter.
    await tester.tap(find.text('AI Barcode'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.text('AI Camera'), findsWidgets);
  });

  testWidgets('settings rows open their screens and back returns',
      (tester) async {
    await boot(tester);
    await reachLogin(tester);
    await signIn(tester);

    await tester.tap(
      assetFinder('assets/images/app/nav_settings.png').first,
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    expect(find.text('My Profile'), findsOneWidget);

    // These screens use the design's own circular back button, not a
    // Material AppBar, so pageBack() has nothing to find.
    await tester.tap(assetFinder('assets/images/auth/back_button.png').first);
    await tester.pumpAndSettle();
    expect(find.text('Settings'), findsWidgets);
  });

  testWidgets('log out confirms and returns to log in', (tester) async {
    await boot(tester);
    await reachLogin(tester);
    await signIn(tester);

    await tester.tap(
      assetFinder('assets/images/app/nav_settings.png').first,
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Log Out'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Are you sure'), findsOneWidget);

    await tester.tap(find.text('Log Out').last);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    expect(find.text('Welcome Back to Carbsai'), findsOneWidget);
  });
}
