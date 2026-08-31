import { base64UrlToBytes, utf8 } from "./bytes.js";
import type { Env } from "./env.js";
import { projectId } from "./google.js";
import { HttpsError } from "./callable.js";

/**
 * Verifies a Firebase ID token.
 *
 * This is the security boundary of the whole Worker: every endpoint trusts the
 * uid this returns and nothing else. It replaces `request.auth.uid`, which the
 * callable runtime used to supply for free — and which the Firebase SDKs
 * computed by doing exactly what is below.
 *
 * Checks, all of which matter:
 *   - RS256 signature against Google's published public keys, matched by `kid`
 *   - `aud` is this project (a token for another Firebase project is a valid
 *     Google-signed token, and would otherwise be accepted)
 *   - `iss` is securetoken for this project
 *   - not expired, not issued in the future
 *   - `sub` present and non-empty — it becomes the uid
 */

/**
 * Google's public keys for Firebase ID tokens.
 *
 * The path segment is `jwk`, singular — `jwks` is a 404, which surfaces as
 * "Could not fetch Google signing keys" and rejects every request as
 * unauthenticated.
 *
 * Google rotates these; the response's own max-age says for how long.
 */
const JWKS_URL =
  "https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com";

interface Jwk {
  kid: string;
  n: string;
  e: string;
  kty: string;
  alg: string;
}

let keyCache: { keys: Map<string, Jwk>; expiresAt: number } | null = null;

async function publicKeys(): Promise<Map<string, Jwk>> {
  const now = Date.now();
  if (keyCache && keyCache.expiresAt > now) return keyCache.keys;

  const response = await fetch(JWKS_URL);
  // Status included: without it this reads as a network problem when it is
  // usually a wrong URL, and every request fails as unauthenticated either way.
  if (!response.ok) {
    throw new Error(`Could not fetch Google signing keys: HTTP ${response.status}`);
  }

  const body = (await response.json()) as { keys: Jwk[] };
  const maxAge = /max-age=(\d+)/.exec(response.headers.get("cache-control") ?? "");
  keyCache = {
    keys: new Map(body.keys.map((key) => [key.kid, key])),
    // An hour if the header is missing — short enough to pick up a rotation,
    // long enough that this is not a fetch per request.
    expiresAt: now + (maxAge ? Number(maxAge[1]) : 3600) * 1000,
  };
  return keyCache.keys;
}

interface IdTokenClaims {
  sub: string;
  aud: string;
  iss: string;
  exp: number;
  iat: number;
  email?: string;
  email_verified?: boolean;
}

function decodeJson<T>(segment: string): T {
  return JSON.parse(new TextDecoder().decode(base64UrlToBytes(segment))) as T;
}

export async function verifyIdToken(token: string, env: Env): Promise<IdTokenClaims> {
  const parts = token.split(".");
  if (parts.length !== 3) {
    throw new HttpsError("unauthenticated", "Sign in first.");
  }

  const header = decodeJson<{ alg: string; kid: string }>(parts[0]);
  if (header.alg !== "RS256") {
    throw new HttpsError("unauthenticated", "Sign in first.");
  }

  const jwk = (await publicKeys()).get(header.kid);
  if (!jwk) throw new HttpsError("unauthenticated", "Sign in first.");

  const key = await crypto.subtle.importKey(
    "jwk",
    { kty: jwk.kty, n: jwk.n, e: jwk.e, alg: "RS256", ext: true },
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["verify"],
  );

  const valid = await crypto.subtle.verify(
    "RSASSA-PKCS1-v1_5",
    key,
    base64UrlToBytes(parts[2]),
    utf8(`${parts[0]}.${parts[1]}`),
  );
  if (!valid) throw new HttpsError("unauthenticated", "Sign in first.");

  const claims = decodeJson<IdTokenClaims>(parts[1]);
  const project = projectId(env);
  const now = Math.floor(Date.now() / 1000);

  // 60s of clock skew, the same tolerance the Firebase SDKs allow.
  const ok =
    claims.aud === project &&
    claims.iss === `https://securetoken.google.com/${project}` &&
    claims.exp > now - 60 &&
    claims.iat < now + 60 &&
    typeof claims.sub === "string" &&
    claims.sub.length > 0;

  if (!ok) throw new HttpsError("unauthenticated", "Sign in first.");
  return claims;
}

/** The uid behind this request, or a 401. */
export async function requireAuth(request: Request, env: Env): Promise<string> {
  const header = request.headers.get("authorization") ?? "";
  const match = /^Bearer (.+)$/i.exec(header.trim());
  if (!match) throw new HttpsError("unauthenticated", "Sign in first.");
  return (await verifyIdToken(match[1], env)).sub;
}
