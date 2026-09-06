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

import {
  LEGAL_CONTACT,
  LEGAL_UPDATED,
  PRIVACY_POLICY,
  TERMS,
  type LegalBlock,
} from "./legal.js";

export type LegalKind = "privacy" | "terms" | "delete";

/** Which document a path asks for, or undefined when it asks for none. */
export function legalKind(path: string): LegalKind | undefined {
  if (path === "privacy" || path === "privacy-policy") return "privacy";
  if (path === "terms" || path === "terms-and-conditions") return "terms";
  if (path === "delete-account" || path === "delete") return "delete";
  return undefined;
}

/**
 * The account-deletion page Play requires.
 *
 * Play will not accept a listing from an app that creates accounts without a
 * URL where deletion can be requested — and it is checked against three things:
 * that it names the app, that the steps are prominent, and that it says what is
 * deleted and what is kept.
 *
 * That last one is why this is written against `account.ts` rather than from
 * memory. Everything under `users/{uid}` goes, including the subcollections the
 * client cannot even read; the purchase index outside it does not, and saying so
 * is the difference between a disclosure and a claim.
 */
const DELETE_ACCOUNT: readonly LegalBlock[] = [
  {
    text:
      "This page explains how to delete your Carbsai account and the data held " +
      "with it.",
    heading: false,
  },
  { text: "Delete it yourself, in the app", heading: true },
  {
    text:
      "1. Open Carbsai and sign in.  2. Go to Settings.  3. Tap Delete account " +
      "and confirm.",
    heading: false,
  },
  {
    text:
      "Deletion runs on our server, not on your phone, so it completes even if " +
      "you uninstall the app straight afterwards. The app waits for it to " +
      "finish and tells you if anything could not be removed.",
    heading: false,
  },
  { text: "Ask us instead", heading: true },
  {
    text:
      "If you cannot sign in — a lost password, a phone you no longer have — " +
      "email " +
      LEGAL_CONTACT +
      " from the address on the account, with the subject \"Delete my account\". " +
      "We will confirm and delete it within 30 days.",
    heading: false,
  },
  { text: "What is deleted", heading: true },
  {
    text:
      "• Your profile: name, email, date of birth, gender, height, weight, " +
      "activity level, goal and calorie targets.",
    heading: false,
  },
  { text: "• Your food diary: every meal, with its photo path and figures.", heading: false },
  { text: "• Diet plans you built or saved, and your favourites.", heading: false },
  { text: "• Notifications and reminder preferences.", heading: false },
  {
    text:
      "• Records you were never able to see: the scan log, your scan quota and " +
      "your subscription entitlement.",
    heading: false,
  },
  { text: "• Any meal photographs held in our storage.", heading: false },
  {
    text:
      "• Your sign-in account itself, so the email address can be used again " +
      "from scratch.",
    heading: false,
  },
  { text: "All of it is removed immediately. There is no grace period and nothing is archived.", heading: false },
  { text: "What is kept, and why", heading: true },
  {
    text:
      "• If you ever subscribed, we keep a one-way hash of the store's purchase " +
      "identifier. It is what lets us recognise a refund or cancellation notice " +
      "from Google or Apple after the account is gone. It contains no name, no " +
      "email and no diary data, and it cannot be turned back into your purchase.",
    heading: false,
  },
  {
    text:
      "• Google Play and Apple keep their own record of any purchase, under " +
      "their policies, not ours. Deleting your Carbsai account does not cancel " +
      "a subscription — do that in the Play Store or App Store.",
    heading: false,
  },
  {
    text:
      "• Totals used to count what our AI provider costs us per day are counts " +
      "only. They are not linked to any account and there is nothing in them to " +
      "delete.",
    heading: false,
  },
  { text: "Deleting some data without deleting your account", heading: true },
  {
    text:
      "You can remove a single meal at any time by pressing and holding it on " +
      "the home screen. To remove everything, delete the account.",
    heading: false,
  },
];

export function legalResponse(kind: LegalKind): Response {
  const blocks =
    kind === "privacy" ? PRIVACY_POLICY : kind === "terms" ? TERMS : DELETE_ACCOUNT;
  const title =
    kind === "privacy"
      ? "Privacy Policy"
      : kind === "terms"
        ? "Terms and Conditions"
        : "Delete your Carbsai account";

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
