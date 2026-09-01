import 'package:carbsai/core/models/models.dart';
import 'package:carbsai/features/onboarding/presentation/onboarding_quiz_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/design_render.dart';

/// The quiz's title and subtitle sit in fixed-height boxes on the artboard,
/// inside a hard-clipped Stack. Copy that runs one line long is therefore
/// *silently truncated* — it does not overflow, it does not throw, and no
/// existing test notices. The activity step shipped reading "...sets a goal you
/// will not", losing its last word, and only a screenshot on a real device
/// caught it.
///
/// This walks every step and asserts nothing is cut off.
void main() {
  setUpAll(loadDesignFonts);

  /// True when this string did not fit the lines it was given.
  bool truncated(WidgetTester tester, Finder finder) {
    final paragraph = tester.renderObject<RenderParagraph>(finder);
    return paragraph.didExceedMaxLines;
  }

  Future<void> checkVisibleCopy(WidgetTester tester, String step) async {
    for (final element in find.byType(Text).evaluate()) {
      final widget = element.widget as Text;
      final text = widget.data;
      if (text == null || text.isEmpty) continue;
      expect(
        truncated(tester, find.text(text).first),
        isFalse,
        reason: 'On the "$step" step, this is cut off: "$text"',
      );
    }
  }

  testWidgets('no quiz copy is truncated at any step', (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(428, 926);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      await designScope(
        const MaterialApp(home: OnboardingQuizScreen()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));

    // Answering the choice steps as we go, since Next is inert without one.
    // The lose branch is walked because it is the longest: it adds the goal
    // weight step the maintain branch skips.
    const walk = <(String, String?)>[
      ('gender', 'Female'),
      ('age', null),
      ('height', null),
      ('weight', null),
      ('activity', 'Moderately active'),
      ('goal', 'Lose weight'),
      ('goal weight', null),
      ('plan', null),
    ];

    for (final (name, choice) in walk) {
      await checkVisibleCopy(tester, name);

      if (name == 'plan') break;
      if (choice != null) {
        await tester.tap(find.text(choice));
        await tester.pump();
      }
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
    }
  });

  testWidgets('every activity level label fits its card', (tester) async {
    // The five activity options carry the longest labels in the quiz, and each
    // has a second detail line inside a fixed-height card.
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(428, 926);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      await designScope(const MaterialApp(home: OnboardingQuizScreen())),
    );
    await tester.pump(const Duration(milliseconds: 50));

    await tester.tap(find.text('Female'));
    await tester.pump();
    for (var i = 0; i < 4; i++) {
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
    }

    for (final level in ActivityLevel.values) {
      expect(find.text(level.label), findsOneWidget);
      expect(find.text(level.detail), findsOneWidget);
      expect(truncated(tester, find.text(level.detail)), isFalse,
          reason: '"${level.detail}" is cut off in its card');
    }
  });
}
