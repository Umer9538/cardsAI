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

interface ServiceAccount {
  client_email: string;
  private_key: string;
  project_id: string;
}

let cached: { token: string; expiresAt: number } | null = null;
let signingKey: CryptoKey | null = null;
let account: ServiceAccount | null = null;

function parseAccount(env: Env): ServiceAccount {
  if (account) return account;
  try {
    account = JSON.parse(env.FIREBASE_SERVICE_ACCOUNT) as ServiceAccount;
  } catch {
    throw new Error("FIREBASE_SERVICE_ACCOUNT is not valid JSON.");
  }
  if (!account.client_email || !account.private_key) {
    throw new Error("FIREBASE_SERVICE_ACCOUNT is missing client_email or private_key.");
  }
  return account;
}

/**
 * Imports the PKCS8 private key.
 *
 * `wrangler secret put` preserves newlines, but a key pasted through a shell
 * often arrives with literal `\n`, so both are accepted — that single detail
 * is the most common cause of a service account that "does not work".
 */
async function importSigningKey(env: Env): Promise<CryptoKey> {
  if (signingKey) return signingKey;
  const pem = parseAccount(env)
    .private_key.replace(/\\n/g, "\n")
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/\s/g, "");

  signingKey = await crypto.subtle.importKey(
    "pkcs8",
    base64ToBytes(pem),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  return signingKey;
}

export async function accessToken(env: Env): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  // 60s of slack: a token that expires mid-flight fails the request it was
  // fetched for, which is the hardest kind of flake to reproduce.
  if (cached && cached.expiresAt > now + 60) return cached.token;

  const sa = parseAccount(env);
  const claims = {
    iss: sa.client_email,
    scope: SCOPES,
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  };

  const payload =
    `${base64UrlEncodeJson({ alg: "RS256", typ: "JWT" })}.` +
    `${base64UrlEncodeJson(claims)}`;

  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    await importSigningKey(env),
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
  cached = { token: body.access_token, expiresAt: now + body.expires_in };
  return cached.token;
}

export function projectId(env: Env): string {
  return env.FIREBASE_PROJECT_ID || parseAccount(env).project_id;
}
