import { base64ToBytes, base64UrlEncodeJson, bytesToBase64Url, utf8 } from "./bytes.js";
import type { Env } from "./env.js";

/**
 * An OAuth2 access token for the Firebase service account.
 *
 * This is what replaces the Admin SDK. The Admin SDK's whole privilege comes
 * from holding a service-account key and minting exactly this token, so a
 * Worker that does the same reaches Firestore and Identity Toolkit with the
 * same authority — including bypassing security rules, which is what
 * `users/{uid}/private/**` depends on.
 *
 * The token is cached in module scope. That is per-isolate rather than global,
 * so a busy Worker mints a handful per hour rather than one per request.
 */

const SCOPES = [
  "https://www.googleapis.com/auth/datastore",
  "https://www.googleapis.com/auth/identitytoolkit",
  "https://www.googleapis.com/auth/firebase.messaging",
].join(" ");

/** Google Play Developer API — receipt validation. See `play.ts`. */
export const ANDROID_PUBLISHER_SCOPE =
  "https://www.googleapis.com/auth/androidpublisher";

interface ServiceAccount {
  client_email: string;
  private_key: string;
  project_id: string;
}

// Both caches are keyed, because there is more than one service account now:
// Firebase's, and optionally a second one linked in Play Console for receipt
// validation. A single slot would have them evicting each other on every
// request, re-importing a key and re-minting a token each time.
const tokens = new Map<string, { token: string; expiresAt: number }>();
const signingKeys = new Map<string, CryptoKey>();
const accounts = new Map<string, ServiceAccount>();

function parseAccount(json: string, name: string): ServiceAccount {
  const cachedAccount = accounts.get(json);
  if (cachedAccount) return cachedAccount;

  let parsed: ServiceAccount;
  try {
    parsed = JSON.parse(json) as ServiceAccount;
  } catch {
    throw new Error(`${name} is not valid JSON.`);
  }
  if (!parsed.client_email || !parsed.private_key) {
    throw new Error(`${name} is missing client_email or private_key.`);
  }
  accounts.set(json, parsed);
  return parsed;
}

/**
 * Imports the PKCS8 private key.
 *
 * `wrangler secret put` preserves newlines, but a key pasted through a shell
 * often arrives with literal `\n`, so both are accepted — that single detail
 * is the most common cause of a service account that "does not work".
 */
async function importSigningKey(account: ServiceAccount): Promise<CryptoKey> {
  const existing = signingKeys.get(account.client_email);
  if (existing) return existing;

  const pem = account.private_key
    .replace(/\\n/g, "\n")
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/\s/g, "");

  const key = await crypto.subtle.importKey(
    "pkcs8",
    base64ToBytes(pem),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  signingKeys.set(account.client_email, key);
  return key;
}

export function accessToken(env: Env): Promise<string> {
  return serviceAccountToken(env.FIREBASE_SERVICE_ACCOUNT, SCOPES, "FIREBASE_SERVICE_ACCOUNT");
}

/**
 * An access token for [json]'s service account, good for [scope].
 *
 * Split out from [accessToken] so Play receipt validation can use a *different*
 * account — the one granted "View financial data" in Play Console, which is
 * usually not the Firebase one.
 */
export async function serviceAccountToken(
  json: string,
  scope: string,
  name = "service account",
): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const sa = parseAccount(json, name);
  const cacheKey = `${sa.client_email}|${scope}`;

  // 60s of slack: a token that expires mid-flight fails the request it was
  // fetched for, which is the hardest kind of flake to reproduce.
  const cached = tokens.get(cacheKey);
  if (cached && cached.expiresAt > now + 60) return cached.token;

  const claims = {
    iss: sa.client_email,
    scope,
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  };

  const payload =
    `${base64UrlEncodeJson({ alg: "RS256", typ: "JWT" })}.` +
    `${base64UrlEncodeJson(claims)}`;

  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    await importSigningKey(sa),
    utf8(payload),
  );

  const response = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "content-type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: `${payload}.${bytesToBase64Url(new Uint8Array(signature))}`,
    }),
  });

  if (!response.ok) {
    throw new Error(`Service account token exchange failed: ${await response.text()}`);
  }

  const body = (await response.json()) as { access_token: string; expires_in: number };
  tokens.set(cacheKey, { token: body.access_token, expiresAt: now + body.expires_in });
  return body.access_token;
}

export function projectId(env: Env): string {
  return (
    env.FIREBASE_PROJECT_ID ||
    parseAccount(env.FIREBASE_SERVICE_ACCOUNT, "FIREBASE_SERVICE_ACCOUNT").project_id
  );
}
