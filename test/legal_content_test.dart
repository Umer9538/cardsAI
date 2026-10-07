import 'package:carbsai/features/settings/presentation/legal_content.dart';
import 'package:carbsai/core/design/design_canvas.dart';
import 'package:carbsai/features/settings/presentation/legal_page_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/design_render.dart';

/// The old policy named the operator "us." and disclosed sharing with Google
/// Fit and Apple Health, which this app does not integrate with — while saying
/// nothing about the food photograph it sends to a third-party AI provider.
/// Both stores check a policy against the app's declared data practices.
void main() {
  setUpAll(loadDesignFonts);

  test('the policy discloses what the AI features actually send', () {
    final text = [
      for (final b in privacyPolicy) b.text,
      for (final b in termsAndConditions) b.text,
    ].join('\n');

    // Each of these was wrong or missing while the feature was live, which is
    // the failure mode a policy has: it describes the app it was written for.
    expect(text, contains('plan builder'));
    expect(text, contains('Plan records'));
    expect(text, contains('cook'));
    expect(text, contains('three at the time of writing'));
    // Photos are not uploaded; the policy claimed R2 stored them.
    expect(text, isNot(contains('Cloudflare R2 stores meal')));
    // Backups we do not run.
    expect(text, isNot(contains('Backups roll off')));
    // The quiz answers no longer stop at the calorie target.
    expect(text, isNot(contains('calorie target and nothing else')));
  });

  test('the policy discloses what the app actually does', () {
    final text = privacyPolicy.map((b) => b.text).join('\n').toLowerCase();

    // The disclosure that matters most: the photograph leaves the device.
    expect(text, contains('openrouter'));
    expect(text, contains('cloudflare'));
    expect(text, contains('firebase'));
    expect(text, contains('admob'));

    // And no longer claims integrations that do not exist.
    expect(text, isNot(contains('google fit')));
    expect(text, isNot(contains('apple health')));
  });

  test('both documents name the operator', () {
    // "us." was a placeholder that shipped. Anything that reads like one now
    // has to be an obvious one, so it cannot ship again by accident.
    for (final blocks in [privacyPolicy, termsAndConditions]) {
      final text = blocks.map((b) => b.text).join('\n');
      expect(text, contains(LegalOperator.name));
      expect(text, contains(LegalOperator.email));
      expect(text, isNot(contains('how us. collects')));
    }
  });

  test('the terms cover auto-renewal, which both stores require', () {
    final text = termsAndConditions.map((b) => b.text).join('\n').toLowerCase();
    expect(text, contains('auto-renewing'));
    expect(text, contains('24 hours'));
    expect(text, contains('cancel'));
  });

  testWidgets('every document fits the room it reserves', (tester) async {
    // The canvas needs its height before the text is laid out, so the height
    // is an estimate — and an under-estimate clips the end of the document,
    // which is where the contact address is. Rewriting the copy into real
    // paragraphs is exactly the case the old estimate got wrong.
    for (final page in [
      LegalPageScreen.privacy(),
      LegalPageScreen.terms(),
      LegalPageScreen.help(),
    ]) {
      await tester.pumpWidget(await designScope(MaterialApp(home: page)));
      await tester.pump();

      final column = tester.renderObject<RenderBox>(
        find.descendant(
          of: find.byType(DesignCanvas),
          matching: find.byType(Column),
        ).first,
      );

      // 147 is where the text starts on the artboard.
      expect(
        147 + column.size.height,
        lessThan(page.reservedHeight),
        reason: '${page.title} runs past the canvas it was given',
      );
    }
  });
}
