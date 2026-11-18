import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/design_render.dart';
import 'support/screens.dart';

/// Every control that announces itself as a button must actually do something.
///
/// This is the generalisation of a bug found by hand: `excludeSemantics: true`
/// drops the child's tap action, so thirteen controls — every primary CTA in
/// the app among them — carried a label, carried the button flag, and carried
/// no action at all. They worked under a finger and were inert under TalkBack
/// and VoiceOver, which is the definition of a dead button for the people most
/// likely to need this app: the launch markets into diabetes communities, which
/// skew older.
///
/// Nothing else could see it. `flutter analyze` does not read a semantics tree,
/// the overflow suite only asks whether a frame is too tall, and
/// `accessibility_test` checks that controls are *labelled* — which these were.
///
/// The rule is deliberately one a disabled control still passes: a button may
/// have no tap action **only** if it says it is disabled. "Add to My Diet" over
/// an empty scan result is supposed to be inert, and it announces that.
void main() {
  // The real fonts, not Ahem. Every glyph in the test font is a square em, so
  // without this NutritionRow reports 209px over a box real Space Grotesk fits
  // comfortably — a layout exception that has nothing to do with dead controls
  // and that would fail this suite on four screens. `responsive_overflow_test`
  // loads them for the same reason.
  setUpAll(loadDesignFonts);

  /// Walks [node] and its descendants.
  void visit(SemanticsNode node, void Function(SemanticsNode) fn) {
    fn(node);
    node.visitChildren((child) {
      visit(child, fn);
      return true;
    });
  }

  for (final (name, screen) in appScreens()) {
    testWidgets('$name has no dead buttons', (tester) async {
      final handle = tester.ensureSemantics();
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(428, 926);
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        await designScope(
          MaterialApp(debugShowCheckedModeBanner: false, home: screen),
        ),
      );
      // Bounded, not pumpAndSettle: several of these screens carry a repeating
      // animation and never settle. 600ms rather than 400 because the
      // verification screen schedules a one-shot 450ms timer, and a timer still
      // pending when the tree goes away is an assertion failure in its own
      // right.
      await tester.pump(const Duration(milliseconds: 600));

      final dead = <String>[];

      // The root pipeline owner does not own the semantics tree itself — a
      // child owner does — so this walks down to whichever one holds it.
      SemanticsNode? root;
      void findRoot(PipelineOwner owner) {
        root ??= owner.semanticsOwner?.rootSemanticsNode;
        owner.visitChildren(findRoot);
      }

      findRoot(tester.binding.rootPipelineOwner);
      final found = root;

      if (found != null) {
        visit(found, (node) {
          final data = node.getSemanticsData();
          final flags = data.flagsCollection;
          if (!flags.isButton) return;

          final tappable = data.hasAction(SemanticsAction.tap);
          // `isEnabled` is a Tristate: null means the control never declared an
          // enabled state at all, which is not the same as declaring itself
          // disabled. Only an explicit false earns the exemption.
          final saysDisabled = flags.isEnabled.toBoolOrNull() == false;

          if (!tappable && !saysDisabled) {
            dead.add('"${data.label}"');
          }
        });
      }

      handle.dispose();

      // Torn down inside the test rather than left to teardown. The OTP row
      // holds an offstage TextField whose cursor blink is a periodic timer once
      // semantics are on, and a pending timer at teardown is an assertion
      // failure in its own right.
      await tester.pumpWidget(const SizedBox.shrink());

      // Nothing should be pending now that the real fonts are loaded. Anything
      // that is — an overflow or otherwise — is a genuine finding and fails.
      expect(
        tester.takeException(),
        isNull,
        reason: '$name threw while rendering',
      );

      expect(found, isNotNull, reason: '$name produced no semantics tree');
      expect(
        dead,
        isEmpty,
        reason:
            'On $name these announce as buttons but offer no tap action, and '
            'do not say they are disabled: ${dead.join(', ')}. Either give the '
            "Semantics node an onTap (excludeSemantics drops the child's) or "
            'mark it disabled.',
      );
    });
  }
}
