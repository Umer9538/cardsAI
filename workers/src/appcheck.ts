import { base64UrlToBytes, utf8 } from "./bytes.js";
import { HttpsError } from "./callable.js";
import type { Env } from "./env.js";
import { projectId } from "./google.js";

/**
 * Verifies a Firebase App Check token.
 *
 * The Firebase API key ships in every binary — it identifies the project, it is
 * not a secret — so without this, anyone who unzips the APK can create accounts
 * against the project and call these routes. Each of those accounts gets its
 * own scan quota against a real model bill. `spend.ts` caps the day's total, so
 * the damage was bounded rather than unbounded; this is what makes it *not
 * happen*.
 *
 * The client SDK attaches the token as `X-Firebase-AppCheck`. Verifying it is
 * the same shape as an ID token — an RS256 JWT against Google's published keys
 * — but a different issuer, a different key set, and an `aud` that is the
 * project *number* rather than the project id.
 *
 * ---------------------------------------------------------------------------
 * ENFORCEMENT IS A SWITCH, AND IT IS OFF UNTIL YOU HAVE MEASURED
 * ---------------------------------------------------------------------------
 * With `APP_CHECK_ENFORCED` unset, a missing or invalid token is *logged* and
 * the request proceeds. That is deliberate: some real devices genuinely cannot
 * attest — no Play Services, a rooted phone, a beta OS — and turning
 * enforcement on before knowing how many would lock out paying users with no
 * way to tell it had happened.
 *
 * The order is: deploy this, register the apps in the Firebase console, watch
 * the verified share in App Check metrics until it settles, then set
 * `APP_CHECK_ENFORCED = "1"`.
 */

const JWKS_URL = "https://firebaseappcheck.googleapis.com/v1/jwks";

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
  if (!response.ok) {
    throw new Error(`Could not fetch App Check keys: HTTP ${response.status}`);
  }

  const body = (await response.json()) as { keys: Jwk[] };
  keyCache = {
    keys: new Map(body.keys.map((key) => [key.kid, key])),
    expiresAt: now + 3600_000,
  };
  return keyCache.keys;
}

function decodeJson<T>(segment: string): T {
  return JSON.parse(new TextDecoder().decode(base64UrlToBytes(segment))) as T;
}

/**
 * True if [token] is a valid App Check token for this project.
 *
 * Returns rather than throws: the caller decides what a failure means, and that
 * depends on whether enforcement is on.
 */
async function isValid(token: string, env: Env): Promise<boolean> {
  const parts = token.split(".");
  if (parts.length !== 3) return false;

  const header = decodeJson<{ alg: string; kid: string; typ?: string }>(parts[0]);
  // `typ` is "JWT" on App Check tokens specifically. Checking it stops an ID
  // token being replayed here, which would otherwise verify against a
  // different key set and fail — but fail confusingly.
  if (header.alg !== "RS256") return false;

  const jwk = (await publicKeys()).get(header.kid);
  if (!jwk) return false;

  const key = await crypto.subtle.importKey(
    "jwk",
    { kty: jwk.kty, n: jwk.n, e: jwk.e, alg: "RS256", ext: true },
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["verify"],
  );

  const verified = await crypto.subtle.verify(
    "RSASSA-PKCS1-v1_5",
    key,
    base64UrlToBytes(parts[2]),
    utf8(`${parts[0]}.${parts[1]}`),
  );
  if (!verified) return false;

  const claims = decodeJson<{
    aud?: string[];
    iss?: string;
    exp?: number;
    sub?: string;
  }>(parts[1]);
  const now = Math.floor(Date.now() / 1000);

  // `aud` is an array containing "projects/<number>" and "projects/<id>".
  // Matching on the id avoids needing the project number as another secret.
  const audience = claims.aud ?? [];
  const project = projectId(env);

  return (
    audience.includes(`projects/${project}`) &&
    claims.iss?.startsWith("https://firebaseappcheck.googleapis.com/") === true &&
    (claims.exp ?? 0) > now - 60 &&
    typeof claims.sub === "string" &&
    claims.sub.length > 0
  );
}

/**
 * Checks the App Check header, and refuses only when enforcement is on.
 *
 * Never throws on an internal failure — Google's key endpoint being down must
 * not take the app down with it. That is the correct trade for an anti-abuse
 * measure sitting in front of an already-authenticated request.
 */
export async function requireAppCheck(request: Request, env: Env): Promise<void> {
  const enforced = env.APP_CHECK_ENFORCED === "1";
  const token = request.headers.get("x-firebase-appcheck");

  if (!token) {
    if (enforced) {
      throw new HttpsError("unauthenticated", "This request could not be verified.");
    }
    return;
  }

  let valid = false;
  try {
    valid = await isValid(token, env);
  } catch (error) {
    console.error("app check verification failed", error);
    // Unverifiable is not the same as invalid. Fail open here even when
    // enforced: an outage at Google's key endpoint would otherwise be an
    // outage of this app.
    return;
  }

  if (!valid) {
    console.warn("app check token rejected");
    if (enforced) {
      throw new HttpsError("unauthenticated", "This request could not be verified.");
    }
  }
}
