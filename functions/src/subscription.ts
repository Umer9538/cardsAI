import { FieldValue, Timestamp } from "firebase-admin/firestore";
import { HttpsError, onCall, type CallableRequest } from "firebase-functions/v2/https";
import { logger } from "firebase-functions/v2";

import { db } from "./app.js";

/**
 * Entitlement lives here, on the server, and nowhere else.
 *
 * `users/{uid}/subscription/current` is read-only to the client by the security
 * rules. That is the whole point: an entitlement a client can write is not an
 * entitlement.
 *
 * ---------------------------------------------------------------------------
 * RECEIPTS ARE NOT VALIDATED YET
 * ---------------------------------------------------------------------------
 * The client now sends a real store receipt and platform, and this grants the
 * plan without checking either — because there are no App Store / Play Console
 * products to check against until those are created.
 *
 * When they exist, the ONLY code that changes is `validateReceipt` below:
 *
 *   Google Play → androidpublisher.purchases.subscriptionsv2.get, using a
 *     service account with "View financial data" granted in Play Console and
 *     linked to this Firebase project. Read expiryTime and the product id from
 *     the response.
 *   Apple → the App Store Server API (verifyReceipt is deprecated). Requires
 *     an in-app purchase key from App Store Connect; the response carries the
 *     product id and expiresDate.
 *
 * Everything around it — the document, the rules, the client, the quota — is
 * already shaped for that and does not move.
 *
 * Both stores also send server notifications when a subscription renews,
 * lapses, is refunded, or is cancelled. Without handling those, a subscription
 * that lapses stays "active" here until its renewsAt passes, and a refunded one
 * stays active for the whole term. That needs an HTTP endpoint per store before
 * this is production-ready.
 *
 * DO NOT SHIP with validateReceipt as it stands. It hands premium to anyone who
 * calls it.
 */

const PLANS = {
  monthly: { days: 30 },
  annual: { days: 365 },
} as const;

type PlanId = keyof typeof PLANS;

function isPlanId(value: unknown): value is PlanId {
  return typeof value === "string" && value in PLANS;
}

function requireAuth(request: CallableRequest): string {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Sign in first.");
  return uid;
}

function subscriptionDoc(uid: string) {
  return db.doc(`users/${uid}/subscription/current`);
}

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
 * the caller claims. Until the products exist it takes the caller at their
 * word, which is why the warning above is shouted rather than muttered.
 */
async function validateReceipt(
  uid: string,
  planId: PlanId,
  receipt: string | undefined,
  platform: string | undefined,
): Promise<{ planId: PlanId; expiresAt: Date }> {
  logger.warn("subscription granted without receipt validation", {
    uid,
    planId,
    platform,
    hasReceipt: Boolean(receipt),
  });

  const expiresAt = new Date();
  expiresAt.setDate(expiresAt.getDate() + PLANS[planId].days);
  return { planId, expiresAt };
}

export const activateSubscription = onCall<{
  planId?: string;
  receipt?: string;
  platform?: string;
}>(
  { region: "us-central1", timeoutSeconds: 30 },
  async (request) => {
    const uid = requireAuth(request);
    const planId = request.data?.planId;

    if (!isPlanId(planId)) {
      throw new HttpsError("invalid-argument", "Choose a plan first.");
    }

    const validated = await validateReceipt(
      uid,
      planId,
      request.data?.receipt,
      request.data?.platform,
    );
    const now = new Date();

    const entitlement: Entitlement = {
      status: "active",
      planId: validated.planId,
      startedAt: now.toISOString(),
      renewsAt: validated.expiresAt.toISOString(),
    };

    await subscriptionDoc(uid).set(
      {
        ...entitlement,
        // Server timestamps for anything an audit would care about; the ISO
        // strings above are what the client model parses.
        updatedAt: FieldValue.serverTimestamp(),
        renewsAtTs: Timestamp.fromDate(validated.expiresAt),
      },
      { merge: true },
    );

    logger.info("subscription activated", { uid, planId: validated.planId });
    return { subscription: entitlement };
  },
);

/**
 * Stops the renewal, keeping access until the paid term ends.
 *
 * With real purchases this cannot actually cancel anything — only the App Store
 * or Play Store can, and both require the user to do it in their own
 * subscription settings. At that point this should become a deep link out to
 * those settings, and the entitlement should change only when the store's
 * server notification says it has.
 */
export const cancelSubscription = onCall(
  { region: "us-central1", timeoutSeconds: 30 },
  async (request) => {
    const uid = requireAuth(request);
    const snap = await subscriptionDoc(uid).get();
    const data = snap.data();

    if (!data || data.status !== "active") {
      const entitlement: Entitlement = {
        status: "none",
        planId: null,
        startedAt: null,
        renewsAt: null,
      };
      return { subscription: entitlement };
    }

    const entitlement: Entitlement = {
      status: "cancelled",
      planId: (data.planId as string | null) ?? null,
      startedAt: (data.startedAt as string | null) ?? null,
      renewsAt: (data.renewsAt as string | null) ?? null,
    };

    await subscriptionDoc(uid).set(
      { ...entitlement, updatedAt: FieldValue.serverTimestamp() },
      { merge: true },
    );

    logger.info("subscription cancelled", { uid });
    return { subscription: entitlement };
  },
);

/**
 * Whether [uid] is entitled right now.
 *
 * Used by the scan pipeline to size the quota. A cancelled subscription is
 * still entitled until its term runs out — the money has been taken.
 */
export async function isPremium(uid: string): Promise<boolean> {
  const snap = await subscriptionDoc(uid).get();
  const data = snap.data();
  if (!data) return false;

  if (data.status === "active") return true;
  if (data.status === "cancelled" && data.renewsAtTs) {
    return (data.renewsAtTs as Timestamp).toMillis() > Date.now();
  }
  return false;
}
