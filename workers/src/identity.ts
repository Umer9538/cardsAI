import { HttpsError } from "./callable.js";
import type { Env } from "./env.js";
import { accessToken, projectId } from "./google.js";

/**
 * The admin half of Firebase Auth, over the Identity Toolkit REST API.
 *
 * Only two operations are needed, both for email verification: read the
 * account's address, and mark it verified. Verification stays recorded on the
 * Firebase user rather than in our own data, so `user.emailVerified` remains
 * the single source of truth and the ID token carries it.
 */

const BASE = "https://identitytoolkit.googleapis.com/v1";

async function call(
  env: Env,
  method: string,
  body: Record<string, unknown>,
): Promise<Record<string, unknown>> {
  const response = await fetch(`${BASE}/projects/${projectId(env)}/accounts:${method}`, {
    method: "POST",
    headers: {
      authorization: `Bearer ${await accessToken(env)}`,
      "content-type": "application/json",
    },
    body: JSON.stringify(body),
  });
  if (!response.ok) {
    throw new Error(`identitytoolkit ${method} -> ${response.status}: ${await response.text()}`);
  }
  return (await response.json()) as Record<string, unknown>;
}

export interface AuthUser {
  uid: string;
  email: string | null;
  emailVerified: boolean;
}

export async function getUser(env: Env, uid: string): Promise<AuthUser> {
  const body = await call(env, "lookup", { localId: [uid] });
  const user = (body.users as Array<Record<string, unknown>> | undefined)?.[0];
  if (!user) throw new HttpsError("not-found", "That account no longer exists.");
  return {
    uid,
    email: (user.email as string | undefined) ?? null,
    emailVerified: Boolean(user.emailVerified),
  };
}

export async function setEmailVerified(env: Env, uid: string): Promise<void> {
  await call(env, "update", { localId: uid, emailVerified: true });
}
