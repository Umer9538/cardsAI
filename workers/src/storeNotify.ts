import { HttpsError, json } from "./callable.js";
import type { Env } from "./env.js";
import { Firestore, serverTimestamp } from "./firestore.js";
import { appleConfigured, validateAppleReceipt } from "./appstore.js";
import { playConfigured, validatePlayPurchase } from "./play.js";
import { StoreEntitlement } from "./play.js";

/**
 * Store server notifications — how a subscription ends.
 *
 * Without these, a refunded or lapsed subscription stays premium here until
 * its `renewsAt` passes: up to a year of free access for anyone who buys the
 * annual plan and refunds it the next day.
 *
 * **The notification body is never trusted.** It is used only to find out
 * *which* purchase changed; the answer then comes from asking the store
 * directly over an authenticated call we make ourselves. That is what makes
 * these endpoints safe to expose without verifying Apple's JWS certificate
 * chain or Pub/Sub's OIDC token: forging a notification buys an attacker one
 * extra validation call against their own purchase, and the result of that
 * call is the truth either way.
 *
 * The URLs still carry `STORE_NOTIFY_KEY` in the path, so they are not
 * trivially discoverable and cannot be used to force validation traffic.
 *
 * Configure:
 *   Play Console → Monetisation setup → Real-time developer notifications →
 *     a Pub/Sub topic with a push subscription to
 *     `https://<worker>/storeNotify/google/<STORE_NOTIFY_KEY>`
 *   App Store Connect → App Information → App Store Server Notifications V2 →
 *     `https://<worker>/storeNotify/apple/<STORE_NOTIFY_KEY>`
 */

/** Where a purchase id is mapped back to the account that made it. */
const indexPath = (id: string) => `purchases/${id}`;

const entitlementPath = (uid: string) => `users/${uid}/subscription/current`;

/** Server-only copy of the receipt, for re-validating later. */
const receiptPath = (uid: string) => `users/${uid}/private/purchase`;

/** A Firestore-safe, fixed-length id for a purchase token of any shape. */
export async function purchaseKey(platform: string, value: string): Promise<string> {
  const digest = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(`${platform}:${value}`),
  );
  return Array.from(new Uint8Array(digest), (b) => b.toString(16).padStart(2, "0")).join("");
}

/**
 * Records who a purchase belongs to, so a later notification can find them.
 *
 * The receipt is kept under `users/{uid}/private/**`, which has no rules match
 * and is therefore unreachable by any client — it is a bearer credential for
 * that subscription.
 */
export async function rememberPurchase(
  env: Env,
  uid: string,
  platform: string,
  receipt: string,
  storeId: string,
): Promise<void> {
  const db = new Firestore(env);
  const key = await purchaseKey(platform, storeId);
  await Promise.all([
    db.set(indexPath(key), { uid, platform, updatedAt: serverTimestamp() }),
    db.set(receiptPath(uid), {
      platform,
      receipt,
      storeId,
      updatedAt: serverTimestamp(),
    }),
  ]);
}

export async function handleStoreNotification(
  env: Env,
  platform: string,
  key: string,
  request: Request,
): Promise<Response> {
  if (!env.STORE_NOTIFY_KEY || key !== env.STORE_NOTIFY_KEY) {
    throw new HttpsError("permission-denied", "Not allowed.");
  }

  const storeId =
    platform === "google"
      ? await googlePurchaseToken(request)
      : await appleOriginalTransactionId(request);

  // 200 on anything unrecognised. Both stores retry a non-2xx for days, and a
  // notification type we do not act on is not a failure.
  if (!storeId) return json({ ok: true });

  const db = new Firestore(env);
  const index = await db.get(indexPath(await purchaseKey(platform, storeId)));
  const uid = index?.uid as string | undefined;
  if (!uid) {
    // A purchase this server never saw — a restore on another account, or a
    // notification that arrived before activation. Nothing to revoke.
    console.warn("store notification for unknown purchase", platform);
    return json({ ok: true });
  }

  await reconcile(env, db, uid, platform);
  return json({ ok: true });
}

/**
 * Re-reads the subscription from the store and writes what it says.
 *
 * This is the only place entitlement is *lowered*, and it is deliberately
 * total: whatever the store reports now replaces what is stored, so a refund,
 * a lapse, a chargeback and a renewal all take the same path.
 */
async function reconcile(
  env: Env,
  db: Firestore,
  uid: string,
  platform: string,
): Promise<void> {
  const stored = await db.get(receiptPath(uid));
  const receipt = stored?.receipt as string | undefined;
  if (!receipt) {
    console.warn("no stored receipt to re-validate", uid);
    return;
  }

  const configured =
    (platform === "google" && playConfigured(env)) ||
    (platform === "apple" && appleConfigured(env));
  if (!configured) return;

  let verified: StoreEntitlement | null = null;
  try {
    verified =
      platform === "google"
        ? await validatePlayPurchase(env, receipt)
        : await validateAppleReceipt(env, receipt);
  } catch (error) {
    // A rejection is the answer, not an error: the store is saying this
    // purchase no longer entitles anyone. Anything else — the store
    // unreachable — must NOT revoke, or an outage cancels every subscriber.
    if (error instanceof HttpsError && error.code === "permission-denied") {
      verified = null;
    } else {
      throw error;
    }
  }

  if (!verified) {
    await db.set(entitlementPath(uid), {
      status: "expired",
      renewsAt: null,
      renewsAtTs: null,
      updatedAt: serverTimestamp(),
    });
    console.log("entitlement revoked", uid, platform);
    return;
  }

  await db.set(entitlementPath(uid), {
    status: "active",
    planId: verified.productId,
    renewsAt: verified.expiresAt.toISOString(),
    renewsAtTs: verified.expiresAt,
    updatedAt: serverTimestamp(),
  });
  console.log("entitlement renewed", uid, platform, verified.expiresAt.toISOString());
}

/** Pub/Sub push: `{message: {data: <base64 JSON>}}`. */
async function googlePurchaseToken(request: Request): Promise<string | null> {
  const body = (await request.json().catch(() => null)) as {
    message?: { data?: string };
  } | null;
  const data = body?.message?.data;
  if (!data) return null;

  try {
    const decoded = JSON.parse(atob(data)) as {
      subscriptionNotification?: { purchaseToken?: string };
      voidedPurchaseNotification?: { purchaseToken?: string };
    };
    return (
      decoded.subscriptionNotification?.purchaseToken ??
      // A refund or chargeback. The one that matters most here.
      decoded.voidedPurchaseNotification?.purchaseToken ??
      null
    );
  } catch {
    return null;
  }
}

/**
 * App Store Server Notifications V2: `{signedPayload: <JWS>}`, whose payload
 * carries another JWS in `data.signedTransactionInfo`.
 *
 * Both are decoded without checking their signatures, and that is safe here
 * *because the result is only used as a lookup key* — see the note at the top
 * of this file. Nothing about the entitlement comes from these bytes.
 */
async function appleOriginalTransactionId(request: Request): Promise<string | null> {
  const body = (await request.json().catch(() => null)) as {
    signedPayload?: string;
  } | null;
  const outer = decodeJwsPayload(body?.signedPayload);
  if (!outer) return null;

  const data = outer.data as Record<string, unknown> | undefined;
  const transaction = decodeJwsPayload(data?.signedTransactionInfo as string | undefined);
  const id =
    (transaction?.originalTransactionId as string | undefined) ??
    ((data?.originalTransactionId as string | undefined) ?? undefined);
  return id ?? null;
}

function decodeJwsPayload(jws: string | undefined): Record<string, unknown> | null {
  if (!jws) return null;
  const segment = jws.split(".")[1];
  if (!segment) return null;
  try {
    const padded = segment.replace(/-/g, "+").replace(/_/g, "/");
    return JSON.parse(atob(padded)) as Record<string, unknown>;
  } catch {
    return null;
  }
}
