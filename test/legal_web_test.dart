import 'dart:io';

import 'package:carbsai/features/settings/presentation/legal_content.dart';
import 'package:flutter_test/flutter_test.dart';

/// The policy on the web and the policy in the app must be the same policy.
///
/// Both stores check a listing's privacy policy against the app's declared data
/// practices, and Play needs it at a public URL before it will accept the
/// listing at all. `workers/src/legal.ts` is generated from
/// `legal_content.dart` by `tool/emit_legal.dart` precisely so there is one
/// source — but a generated file that nobody regenerates is just a stale copy
/// with a comment on top claiming otherwise.
///
/// So this reads the TypeScript as text, the way `dish_taxonomy_test` does. It
/// fails when the app's copy has moved on and the script has not been re-run.
void main() {
  late String generated;

  setUpAll(() {
    final file = File('workers/src/legal.ts');
    expect(
      file.existsSync(),
      isTrue,
      reason: 'workers/src/legal.ts is missing — run '
          '`dart run tool/emit_legal.dart`',
    );
    generated = file.readAsStringSync();
  });

  /// The generator writes TypeScript double-quoted literals, so a quote or a
  /// backslash in the source arrives escaped.
  String asLiteral(String value) => value
      .replaceAll(r'\', r'\\')
      .replaceAll('"', r'\"')
      .replaceAll('\n', r'\n');

  test('every privacy paragraph reached the web copy', () {
    for (final block in privacyPolicy) {
      expect(
        generated.contains(asLiteral(block.text)),
        isTrue,
        reason: 'the app says this and the hosted policy does not:\n'
            '  "${block.text}"\n'
            'Run `dart run tool/emit_legal.dart`.',
      );
    }
  });

  test('every term reached the web copy', () {
    for (final block in termsAndConditions) {
      expect(
        generated.contains(asLiteral(block.text)),
        isTrue,
        reason: 'the app says this and the hosted terms do not:\n'
            '  "${block.text}"\n'
            'Run `dart run tool/emit_legal.dart`.',
      );
    }
  });

  test('the web copy carries nothing the app does not say', () {
    // The other direction, and the one that matters for a regulator: a
    // sentence published as this app's policy that the app itself has never
    // shown anyone is a claim nobody reviewed.
    final published = RegExp(r'\{ text: "((?:[^"\\]|\\.)*)"')
        .allMatches(generated)
        .map((m) => m.group(1)!)
        .toList();
    final known = {
      for (final b in [...privacyPolicy, ...termsAndConditions])
        asLiteral(b.text),
    };

    expect(published, isNotEmpty);
    for (final text in published) {
      expect(
        known.contains(text),
        isTrue,
        reason: 'the hosted documents contain a paragraph the app does not:\n'
            '  "$text"',
      );
    }
  });

  test('the counts match, so nothing was dropped', () {
    final blocks = RegExp(r'\{ text: "').allMatches(generated).length;
    expect(blocks, privacyPolicy.length + termsAndConditions.length);
  });
}
