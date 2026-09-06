/**
 * Where the legal documents live, for anyone who asks the API for them.
 *
 * The documents themselves are a static site rendered from
 * `lib/features/settings/presentation/legal_content.dart` by
 * `tool/emit_legal.dart`, and served from Cloudflare Pages. This only
 * redirects.
 *
 * It redirects rather than serving its own copy because a legal document must
 * have one address. Two live renderings at two URLs can disagree — one gets
 * redeployed and the other does not — and then there is no answer to "which one
 * were you shown". The Worker is also the wrong host for it in a second way:
 * its address is `carbsai-api.<account>.workers.dev`, and the account subdomain
 * names a different product, which is a poor thing to print on a store listing.
 *
 * The route stays because the address is already published inside the app and
 * in `PLAY-SUBMISSION.md`, and a legal URL that stops resolving is worse than a
 * redirect that costs nothing.
 */

/** Where the documents are actually served from. */
export const LEGAL_ORIGIN = "https://carbsai.pages.dev";

export type LegalKind = "privacy" | "terms" | "delete-account";

/** Which document a path asks for, or undefined when it asks for none. */
export function legalKind(path: string): LegalKind | undefined {
  if (path === "privacy" || path === "privacy-policy") return "privacy";
  if (path === "terms" || path === "terms-and-conditions") return "terms";
  if (path === "delete-account" || path === "delete") return "delete-account";
  return undefined;
}

export function legalResponse(kind: LegalKind): Response {
  // 302 rather than 301: a permanent redirect is cached by browsers more or
  // less forever, and the canonical home for these documents is a decision
  // that can change — a custom domain is the obvious next step.
  return Response.redirect(`${LEGAL_ORIGIN}/${kind}`, 302);
}
