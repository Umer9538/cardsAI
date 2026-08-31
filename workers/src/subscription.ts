import { HttpsError } from "./callable.js";
import type { Env } from "./env.js";
import { Firestore, serverTimestamp } from "./firestore.js";

/**
 * Entitlement lives on the server and nowhere else.
 *
 * `users/{uid}/subscription/current` is read-only to the client by the
 * Firestore rules, which are unchanged by this port — the Worker writes it with
 * a service-account token, exactly as the Admin SDK did. An entitlement a
 * client can write is not an entitlement.
 *
 * ---------------------------------------------------------------------------
 * RECEIPTS ARE STILL NOT VALIDATED
 * ---------------------------------------------------------------------------
 * The client sends a real store receipt and platform, and this grants the plan
 * without checking either — because there are no App Store / Play Console
 * products to check against until those are created.
 *
 * When they exist, the ONLY code that changes is `validateReceipt` below:
 *
 *   Google Play → androidpublisher.purchases.subscriptionsv2.get, using a
 *     service account with "View financial data" granted in Play Console.
 *   Apple → the App Store Server API (verifyReceipt is deprecated), with an
 *     in-app purchase key from App Store Connect.
 *
 * Both calls are ordinary HTTPS, so a Worker can make them — which the Spark
 * plan could not. Everything around them is already shaped for it.
 *
 * Both stores also send server notifications when a subscription renews,
 * lapses, is refunded or is cancelled. Without handling those, a lapsed
 * subscription stays active here until its renewsAt passes. That needs one
 * more route per store.
 *
 * DO NOT SHIP with validateReceipt as it stands. It hands premium to anyone
 * who calls it.
 */

const PLANS = {
  monthly: { days: 30 },
  annual: { days: 365 },
} as const;

type PlanId = keyof typeof PLANS;

function isPlanId(value: unknown): value is PlanId {
  return typeof value === "string" && value in PLANS;
}

const docPath = (uid: string) => `users/${uid}/subscription/current`;

interface Entitlement {
  status: "none" | "active" | "expired" | "cancelled";
  planId: string | null;
  startedAt: string | null;
  renewsAt: string | null;
}

/**
 * Where store-receipt validation goes.
 *
 * Must return the plan and expiry the STORE says the account has — never what
 * the caller claims.
 */
async function validateReceipt(
  uid: string,
  planId: PlanId,
  receipt: string | undefined,
  platform: string | undefined,
): Promise<{ planId: PlanId; expiresAt: Date }> {
  console.warn(
    "subscription granted without receipt validation",
    JSON.stringify({ uid, planId, platform, hasReceipt: Boolean(receipt) }),
  );
  const expiresAt = new Date();
  expiresAt.setDate(expiresAt.getDate() + PLANS[planId].days);
  return { planId, expiresAt };
}

export async function activateSubscription(
  env: Env,
  uid: string,
  data: { planId?: string; receipt?: string; platform?: string },
): Promise<{ subscription: Entitlement }> {
  if (!isPlanId(data.planId)) {
    throw new HttpsError("invalid-argument", "Choose a plan first.");
  }

  const db = new Firestore(env);
  const validated = await validateReceipt(uid, data.planId, data.receipt, data.platform);
  const now = new Date();

  const entitlement: Entitlement = {
    status: "active",
    planId: validated.planId,
    startedAt: now.toISOString(),
    renewsAt: validated.expiresAt.toISOString(),
  };

  await db.set(docPath(uid), {
    ...entitlement,
    // A real timestamp beside the ISO string: only this one is comparable
    // server-side, and `isPremium` reads it. The string is what the client
    // model parses.
    updatedAt: serverTimestamp(),
    renewsAtTs: validated.expiresAt,
  });

  console.log("subscription activated", uid, validated.planId);
  return { subscription: entitlement };
}

/**
 * Stops the renewal, keeping access until the paid term ends.
 *
 * With real purchases this cannot actually cancel anything — only the stores
 * can, and both require the user to do it in their own subscription settings.
 * At that point this becomes a deep link out, and the entitlement changes only
 * when the store's server notification says it has.
 */
export async function cancelSubscription(
  env: Env,
  uid: string,
): Promise<{ subscription: Entitlement }> {
  const db = new Firestore(env);
  const data = await db.get(docPath(uid));

  if (!data || data.status !== "active") {
    return {
      subscription: { status: "none", planId: null, startedAt: null, renewsAt: null },
    };
  }

  const entitlement: Entitlement = {
    status: "cancelled",
    planId: (data.planId as string | null) ?? null,
    startedAt: (data.startedAt as string | null) ?? null,
    renewsAt: (data.renewsAt as string | null) ?? null,
  };

  await db.set(docPath(uid), { ...entitlement, updatedAt: serverTimestamp() });
  console.log("subscription cancelled", uid);
  return { subscription: entitlement };
}

/**
 * Whether [uid] is entitled right now.
 *
 * Used by the scan pipeline to size the quota. A cancelled subscription is
 * still entitled until its term runs out — the money has been taken.
 */
export async function isPremium(db: Firestore, uid: string): Promise<boolean> {
  const data = await db.get(docPath(uid));
  if (!data) return false;
  if (data.status === "active") return true;
  if (data.status === "cancelled" && data.renewsAtTs instanceof Date) {
    return data.renewsAtTs.getTime() > Date.now();
  }
  return false;
}
