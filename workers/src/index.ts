import { requireAuth } from "./auth.js";
import { HttpsError, callableData, json } from "./callable.js";
import type { Env } from "./env.js";
import { sendEmailOtp, verifyEmailOtp } from "./otp.js";
import { searchFoods } from "./foods.js";
import { deletePhoto, uploadPhoto } from "./photos.js";
import { grantBonusScans } from "./rewards.js";
import { analyzeMeal, type ScanRequest } from "./scan.js";
import { activateSubscription, cancelSubscription } from "./subscription.js";

/**
 * The Carbsai backend.
 *
 * Replaces the Firebase Cloud Functions in `functions/`, so the Firebase
 * project can stay on Spark — Spark blocks outbound calls to any non-Google
 * host, which is what made the OpenAI call undeployable there.
 *
 * Firebase remains the system of record. Auth still issues the tokens, and
 * Firestore still holds every document; this Worker reaches both over REST with
 * a service-account token, which carries the same authority the Admin SDK did,
 * including bypassing security rules. The rules themselves are unchanged.
 *
 * The named routes speak the Firebase **callable** protocol, because the client
 * still calls them through `cloud_functions` with `httpsCallableFromUrl` — that
 * keeps the SDK attaching the ID token and keeps every error translation
 * already written in the Dart repositories. `/photos` is plain HTTP instead:
 * there is no callable shape for a binary body.
 */

type Callable = (env: Env, uid: string, data: unknown) => Promise<unknown>;

const CALLABLES: Record<string, Callable> = {
  analyzeMeal: (env, uid, data) => analyzeMeal(env, uid, data as ScanRequest),
  sendEmailOtp: (env, uid) => sendEmailOtp(env, uid),
  verifyEmailOtp: (env, uid, data) => verifyEmailOtp(env, uid, data as { code?: string }),
  activateSubscription: (env, uid, data) =>
    activateSubscription(env, uid, data as { planId?: string }),
  cancelSubscription: (env, uid) => cancelSubscription(env, uid),
  searchFoods: (env, uid, data) =>
    searchFoods(env, uid, data as { query?: string; limit?: number }),
  grantBonusScans: (env, uid) => grantBonusScans(env, uid),
};

const CORS: Record<string, string> = {
  "access-control-allow-origin": "*",
  "access-control-allow-headers": "authorization, content-type, x-meal-id",
  "access-control-allow-methods": "POST, DELETE, OPTIONS",
  "access-control-max-age": "86400",
};

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    // Preflight, for a web build. Mobile never sends one.
    if (request.method === "OPTIONS") {
      return new Response(null, { status: 204, headers: CORS });
    }
    return withCors(await route(request, env));
  },
};

/**
 * Every failure leaves here as a well-formed callable error.
 *
 * An unexpected throw must never reach the client as a stack trace or an
 * upstream provider's error string — both leak internals, and neither is
 * something to put in front of someone mid-meal.
 */
async function route(request: Request, env: Env): Promise<Response> {
  const path = new URL(request.url).pathname.replace(/^\/+|\/+$/g, "");

  try {
    if (path === "health") return json({ ok: true });

    if (path === "photos") {
      const uid = await requireAuth(request, env);
      if (request.method === "POST") return await uploadPhoto(env, uid, request);
      if (request.method === "DELETE") return await deletePhoto(env, uid, request);
      throw new HttpsError("not-found", "No such route.");
    }

    const handler = CALLABLES[path];
    if (!handler || request.method !== "POST") {
      throw new HttpsError("not-found", "No such route.");
    }

    const uid = await requireAuth(request, env);
    const data = await callableData<unknown>(request);
    return json({ result: await handler(env, uid, data) });
  } catch (error) {
    if (error instanceof HttpsError) return error.toResponse();
    console.error("unhandled", error instanceof Error ? error.stack : error);
    return new HttpsError("internal", "Something went wrong. Please try again.").toResponse();
  }
}

function withCors(response: Response): Response {
  const headers = new Headers(response.headers);
  for (const [key, value] of Object.entries(CORS)) headers.set(key, value);
  return new Response(response.body, { status: response.status, headers });
}
