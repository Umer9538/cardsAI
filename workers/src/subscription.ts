import { HttpsError } from "./callable.js";
import type { Env } from "./env.js";
import { Firestore, serverTimestamp } from "./firestore.js";
import { appleConfigured, validateAppleReceipt } from "./appstore.js";
import { playConfigured, validatePlayPurchase } from "./play.js";
import { rememberPurchase } from "./storeNotify.js";

/**
 * Entitlement lives on the server and nowhere else.
 *
 * `users/{uid}/subscription/current` is read-only to the client by the
 * Firestore rules, which are unchanged by this port — the Worker writes it with
 * a service-account token, exactly as the Admin SDK did. An entitlement a
 * client can write is not an entitlement.
 *
 * Receipts are now checked with the store that issued them: `play.ts` asks
 * Play what a purchase token is worth, `appstore.ts` asks Apple what a receipt
 * holds, and the plan and expiry written here come from that answer rather
 * than from anything the caller sent. A caller can no longer name their own
 * plan, or their own renewal date.
 *
 * With neither store configured this **refuses**, unless
 * `ALLOW_UNVERIFIED_PURCHASES` is explicitly set — which is for development
 * against a build that has no store products yet. Refusing is the safe
 * default, and the previous version had it the other way round: it granted
 * whatever was asked for and only wrote a warning to the log.
 *
 * Refunds and lapses arrive on `/storeNotify/*`, so access ends when the money
 * does rather than when `renewsAt` happens to pass.
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
 * What the STORE says this account has — never what the caller claims.
 *
 * The returned plan id is Play's or Apple's product id. They are the same
 * strings as the local plan ids by construction (`monthly`, `annual`), and
 * that is checked rather than assumed: a mismatch means the store sold
 * something this server does not know about.
 */
async function validateReceipt(
  env: Env,
  uid: string,
  planId: PlanId,
  receipt: string | undefined,
  platform: string | undefined,
): Promise<{ planId: PlanId; expiresAt: Date; storeId: string }> {
  const configured =
    (platform === "google" && playConfigured(env)) ||
    (platform === "apple" && appleConfigured(env));

  if (!configured) {
    if (env.ALLOW_UNVERIFIED_PURCHASES !== "1") {
      console.error("purchase refused: no store credentials", platform);
      throw new HttpsError(
        "failed-precondition",
        "Purchases are not available yet. Please try again later.",
      );
    }
    // Development only, and loud about it.
    console.warn(
      "ALLOW_UNVERIFIED_PURCHASES: granting without a store check",
      JSON.stringify({ uid, planId, platform }),
    );
    const expiresAt = new Date();
    expiresAt.setDate(expiresAt.getDate() + PLANS[planId].days);
    return { planId, expiresAt, storeId: receipt ?? uid };
  }

  if (!receipt) {
    throw new HttpsError("invalid-argument", "That purchase is missing its receipt.");
  }

  const verified =
    platform === "google"
      ? await validatePlayPurchase(env, receipt)
      : await validateAppleReceipt(env, receipt);

  if (!isPlanId(verified.productId)) {
    // The store sold a product this server has no term for. Granting the
    // requested plan instead would let a cheap product buy an expensive one.
    console.error("unknown product from store", verified.productId, platform);
    throw new HttpsError("failed-precondition", "That plan is not available.");
  }

  return {
    planId: verified.productId,
    expiresAt: verified.expiresAt,
    storeId: verified.storeId,
  };
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
  const validated = await validateReceipt(
    env,
    uid,
    data.planId,
    data.receipt,
    data.platform,
  );
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

  // So a later refund or lapse can be traced back to this account. Without
  // it a store notification arrives naming a purchase and there is no way to
  // tell whose it is. Best effort: the purchase is already paid for and
  // granted, and failing here would undo that over bookkeeping.
  if (data.receipt && data.platform) {
    await rememberPurchase(
      env,
      uid,
      data.platform,
      data.receipt,
      validated.storeId,
    ).catch((error) => console.error("purchase index failed", error));
  }

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
