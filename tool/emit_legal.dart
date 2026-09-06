// Renders the legal documents as a static site, from the app's own copy.
//
//   dart run tool/emit_legal.dart                                  # writes site/
//   cd site && npx wrangler pages deploy . --project-name=carbsai
//
// Deployed from inside `site/`, not from the repository root. Pages looks for a
// `functions/` directory beside the one it is given and builds it as Pages
// Functions — and this repository still has the superseded Cloud Functions
// folder at its root. From the root the deploy fails while compiling code that
// nothing ships.
//
// Play needs a privacy policy and an account-deletion page at public URLs
// before it will accept a listing, and both must describe the app the binary
// actually is. `legal_content.dart` already does — it is hand-written and
// `legal_content_test.dart` holds it to what this repository really does with
// data — so the web copy is rendered from it rather than written twice.
//
// The Dart is pure, with no Flutter import, so this can import it directly and
// there is nothing to parse and nothing to drift. The Worker redirects to these
// pages rather than rendering its own, because two live copies of a legal
// document at two URLs is exactly the problem this file exists to avoid.
//
// The host is Cloudflare Pages rather than the Worker for one reason: the
// Worker's address is `carbsai-api.<account>.workers.dev`, and the account
// subdomain names a different product. That URL is printed on the Play listing,
// where it reads as somebody else's site.

import 'dart:io';

// A tool script is not part of the package's public surface, and a `package:`
// import here would make the script depend on the app's own name resolving.
// ignore: avoid_relative_lib_imports
import '../lib/features/settings/presentation/legal_content.dart';

/// Every page, and the file it becomes. Pages serves `/privacy` from
/// `privacy.html` without the extension, which is why there is no directory
/// nesting here.
const _pages = <String, String>{
  'privacy': 'Privacy Policy',
  'terms': 'Terms and Conditions',
  'delete-account': 'Delete your account',
};

void main() {
  final blocks = <String, List<LegalBlock>>{
    'privacy': privacyPolicy,
    'terms': termsAndConditions,
    'delete-account': accountDeletion,
  };

  final dir = Directory('site');
  if (!dir.existsSync()) dir.createSync(recursive: true);

  for (final entry in _pages.entries) {
    final slug = entry.key;
    File('site/$slug.html').writeAsStringSync(
      _render(entry.value, blocks[slug]!),
    );
  }
  File('site/index.html').writeAsStringSync(_index());

  // A robots file, because these are the only pages of ours anyone will ever
  // crawl and there is no reason to hide them.
  File('site/robots.txt').writeAsStringSync('User-agent: *\nAllow: /\n');

  final total = blocks.values.fold<int>(0, (n, b) => n + b.length);
  stdout.writeln('wrote site/ — ${_pages.length + 1} pages, $total paragraphs');

  if (blocks.values.any((b) => b.any((x) => x.text.contains('REPLACE-WITH-YOUR')))) {
    stdout.writeln(
      '\n  DO NOT DEPLOY YET: LegalOperator still holds placeholders, so these\n'
      '  pages name an operator that does not exist. Fill name, email and\n'
      '  jurisdiction in lib/features/settings/presentation/legal_content.dart\n'
      '  and run this again.\n',
    );
    exitCode = 1;
  }
}

String _render(String title, List<LegalBlock> blocks) {
  final body = blocks
      .map((b) => b.isHeading
          ? '  <h2>${_escape(b.text)}</h2>'
          : '  <p>${_escape(b.text)}</p>')
      .join('\n');

  return '''${_head(title)}
<main>
  <header>
    <p class="brand">Carbsai</p>
    <h1>${_escape(title)}</h1>
    <p class="updated">Last updated ${_escape(LegalOperator.updated)}</p>
  </header>
$body
  <footer>
    <p>The same words are in the app, under Settings.</p>
    <p><a href="/privacy">Privacy</a> · <a href="/terms">Terms</a> · <a href="/delete-account">Delete your account</a></p>
  </footer>
</main>
</body>
</html>
''';
}

String _index() => '''${_head('Legal')}
<main>
  <header>
    <p class="brand">Carbsai</p>
    <h1>Legal</h1>
    <p class="updated">Last updated ${_escape(LegalOperator.updated)}</p>
  </header>
  <p>Carbsai estimates the nutrition in a photograph of your food. These are the
  documents that govern it.</p>
  <h2><a href="/privacy">Privacy Policy</a></h2>
  <p>What the app collects, where it goes, and what you can do about it.</p>
  <h2><a href="/terms">Terms and Conditions</a></h2>
  <p>The agreement between you and ${_escape(LegalOperator.name)}.</p>
  <h2><a href="/delete-account">Delete your account</a></h2>
  <p>How to remove your account and everything held with it.</p>
  <footer><p>Questions: ${_escape(LegalOperator.email)}</p></footer>
</main>
</body>
</html>
''';

/// Deliberately one file with no external anything — no fonts, no scripts, no
/// analytics. A privacy policy that has to load a third-party resource before it
/// can be read is its own small joke, and a store reviewer opens this on
/// whatever connection they happen to have.
String _head(String title) => '''<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Carbsai — ${_escape(title)}</title>
<meta name="description" content="Carbsai — ${_escape(title)}">
<style>
  :root {
    color-scheme: light dark;
    --ink: #16130f; --muted: #55504a; --bg: #fffaf3; --rule: #e4dccf; --link: #d1440d;
  }
  @media (prefers-color-scheme: dark) {
    :root { --ink: #f2ede6; --muted: #a9a29a; --bg: #14120f; --rule: #2c2822; --link: #ff8b5c; }
  }
  * { box-sizing: border-box; }
  body {
    margin: 0; background: var(--bg); color: var(--ink);
    font: 16px/1.65 ui-sans-serif, system-ui, -apple-system, "Segoe UI", Roboto, sans-serif;
    -webkit-text-size-adjust: 100%;
  }
  main { max-width: 42rem; margin: 0 auto; padding: 3rem 1.25rem 5rem; }
  header { border-bottom: 1px solid var(--rule); padding-bottom: 1.25rem; margin-bottom: 2rem; }
  .brand { font-weight: 700; letter-spacing: .08em; text-transform: uppercase; font-size: .75rem; color: var(--muted); margin: 0 0 .75rem; }
  h1 { font-size: 1.75rem; line-height: 1.2; margin: 0 0 .35rem; letter-spacing: -0.01em; }
  .updated { color: var(--muted); font-size: .875rem; margin: 0; }
  h2 { font-size: 1.0625rem; margin: 2.25rem 0 .5rem; }
  p { margin: 0 0 .9rem; overflow-wrap: break-word; }
  a { color: var(--link); }
  footer { margin-top: 3rem; padding-top: 1.25rem; border-top: 1px solid var(--rule); color: var(--muted); font-size: .875rem; }
  footer p { margin: 0 0 .4rem; }
</style>
</head>
<body>''';

String _escape(String value) => value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');
