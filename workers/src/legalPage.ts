/**
 * The privacy policy and terms, as web pages.
 *
 * Play will not accept a listing without a privacy policy at a public URL, and
 * it must describe the app the binary actually is — both stores check it
 * against the declared data practices. The app already carries that document;
 * this serves the same words over HTTP so there is one policy rather than two
 * that can disagree.
 *
 * It lives on the Worker rather than a separate host because the Worker is
 * already deployed, already on a domain, and costs nothing more. A policy on a
 * host nobody renews is a listing that breaks a year from now.
 *
 * The words are generated — see `tool/emit_legal.dart`. Only the rendering is
 * written here.
 */

import { LEGAL_UPDATED, PRIVACY_POLICY, TERMS, type LegalBlock } from "./legal.js";

/** Which document a path asks for, or undefined when it asks for neither. */
export function legalKind(path: string): "privacy" | "terms" | undefined {
  if (path === "privacy" || path === "privacy-policy") return "privacy";
  if (path === "terms" || path === "terms-and-conditions") return "terms";
  return undefined;
}

export function legalResponse(kind: "privacy" | "terms"): Response {
  const blocks = kind === "privacy" ? PRIVACY_POLICY : TERMS;
  const title = kind === "privacy" ? "Privacy Policy" : "Terms and Conditions";

  // A placeholder operator is worse than no page at all: it is a public legal
  // document naming a company that does not exist, linked from a store
  // listing. `tool/build_release.sh` refuses to build for the same reason, so
  // this refuses to serve, and says which file to edit.
  if (blocks.some((b) => b.text.includes("REPLACE-WITH-YOUR"))) {
    return new Response(
      "This policy is not ready to publish: LegalOperator still holds " +
        "placeholders. Fill name, email and jurisdiction in " +
        "lib/features/settings/presentation/legal_content.dart, run " +
        "`dart run tool/emit_legal.dart`, and redeploy.\n",
      { status: 503, headers: { "content-type": "text/plain; charset=utf-8" } },
    );
  }

  return new Response(render(title, blocks), {
    headers: {
      "content-type": "text/html; charset=utf-8",
      // A policy is read once and crawled occasionally. An hour is short
      // enough that a correction goes live the same morning.
      "cache-control": "public, max-age=3600",
    },
  });
}

function render(title: string, blocks: readonly LegalBlock[]): string {
  const body = blocks
    .map((b) =>
      b.heading
        ? `<h2>${escape(b.text)}</h2>`
        : `<p>${escape(b.text)}</p>`,
    )
    .join("\n");

  // Deliberately one file with no external anything: no fonts, no scripts, no
  // analytics. A privacy policy that loads a third-party resource in order to
  // be read is its own small joke, and a store reviewer opens this on whatever
  // connection they have.
  return `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Carbsai — ${escape(title)}</title>
<style>
  :root { color-scheme: light dark; --ink: #16130f; --muted: #55504a; --bg: #fffaf3; --rule: #e4dccf; }
  @media (prefers-color-scheme: dark) {
    :root { --ink: #f2ede6; --muted: #a9a29a; --bg: #14120f; --rule: #2c2822; }
  }
  * { box-sizing: border-box; }
  body {
    margin: 0; background: var(--bg); color: var(--ink);
    font: 16px/1.65 ui-sans-serif, system-ui, -apple-system, "Segoe UI", Roboto, sans-serif;
    -webkit-text-size-adjust: 100%;
  }
  main { max-width: 42rem; margin: 0 auto; padding: 3rem 1.25rem 5rem; }
  header { border-bottom: 1px solid var(--rule); padding-bottom: 1.25rem; margin-bottom: 2rem; }
  h1 { font-size: 1.75rem; line-height: 1.2; margin: 0 0 .35rem; letter-spacing: -0.01em; }
  .brand { font-weight: 700; letter-spacing: .04em; text-transform: uppercase; font-size: .75rem; color: var(--muted); margin: 0 0 .75rem; }
  .updated { color: var(--muted); font-size: .875rem; margin: 0; }
  h2 { font-size: 1.0625rem; margin: 2.25rem 0 .5rem; letter-spacing: -0.005em; }
  p { margin: 0 0 .9rem; overflow-wrap: break-word; }
  footer { margin-top: 3rem; padding-top: 1.25rem; border-top: 1px solid var(--rule); color: var(--muted); font-size: .875rem; }
  a { color: inherit; }
</style>
</head>
<body>
<main>
  <header>
    <p class="brand">Carbsai</p>
    <h1>${escape(title)}</h1>
    <p class="updated">Last updated ${escape(LEGAL_UPDATED)}</p>
  </header>
  ${body}
  <footer>The same text is in the app, under Settings.</footer>
</main>
</body>
</html>`;
}

/** Everything here is our own copy, but it is still text going into HTML. */
function escape(value: string): string {
  return value
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}
