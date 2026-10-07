import 'dart:io';

import 'package:carbsai/features/settings/presentation/legal_content.dart';
import 'package:flutter_test/flutter_test.dart';

/// The policy on the web and the policy in the app must be the same policy.
///
/// Both stores check a listing's privacy policy against the app's declared data
/// practices, and Play needs it — and an account-deletion page — at public URLs
/// before it will accept the listing at all. `site/` is rendered from
/// `legal_content.dart` by `tool/emit_legal.dart` precisely so there is one
/// source, but a generated file nobody regenerates is just a stale copy with a
/// comment on top claiming otherwise.
///
/// So this reads the rendered HTML, the way `dish_taxonomy_test` reads the
/// TypeScript. It fails when the app's copy has moved on and the script has not
/// been run.
void main() {
  const pages = {
    'site/privacy.html': privacyPolicy,
    'site/terms.html': termsAndConditions,
    'site/delete-account.html': accountDeletion,
  };

  /// What `_escape` in the emitter does to a paragraph on its way into HTML.
  String asHtml(String value) => value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');

  for (final entry in pages.entries) {
    final path = entry.key;
    final blocks = entry.value;

    group(path, () {
      late String html;

      setUpAll(() {
        final file = File(path);
        expect(
          file.existsSync(),
          isTrue,
          reason: '$path is missing — run `dart run tool/emit_legal.dart`',
        );
        html = file.readAsStringSync();
      });

      test('every paragraph the app shows reached the page', () {
        for (final block in blocks) {
          expect(
            html.contains(asHtml(block.text)),
            isTrue,
            reason: 'the app says this and the published page does not:\n'
                '  "${block.text}"\n'
                'Run `dart run tool/emit_legal.dart`.',
          );
        }
      });

      test('the page says nothing the app does not', () {
        // The direction that matters to a regulator: a sentence published as
        // this app's policy that the app has never shown anyone is a claim
        // nobody reviewed.
        final published = RegExp(r'^  <(?:p|h2)>(.*)</(?:p|h2)>$', multiLine: true)
            .allMatches(html)
            .map((m) => m.group(1)!)
            .where((t) => !t.contains('<a href='))
            .toList();
        final known = {for (final b in blocks) asHtml(b.text)};

        expect(published, isNotEmpty);
        for (final text in published) {
          expect(
            known.contains(text),
            isTrue,
            reason: 'the published page carries a paragraph the app does not:\n'
                '  "$text"',
          );
        }
      });
    });
  }

  test('the deletion page satisfies what Play checks for', () {
    final html = File('site/delete-account.html').readAsStringSync();

    // Play states three requirements for this page, and each one is a thing a
    // reviewer looks for rather than a box to tick.
    expect(html, contains('Carbs AI'), reason: 'must name the app');
    expect(
      accountDeletion.any((b) => b.isHeading && b.text.contains('Delete it yourself')),
      isTrue,
      reason: 'the steps must be prominent, not buried in a paragraph',
    );
    expect(
      accountDeletion.any((b) => b.isHeading && b.text.contains('What is deleted')),
      isTrue,
    );
    expect(
      accountDeletion.any((b) => b.isHeading && b.text.contains('What is kept')),
      isTrue,
      reason: 'Play asks for what is *kept* too, and the purchase index is',
    );
  });
}
