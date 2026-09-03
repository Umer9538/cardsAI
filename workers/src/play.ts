import { HttpsError } from "./callable.js";
import type { Env } from "./env.js";
import { ANDROID_PUBLISHER_SCOPE, serviceAccountToken } from "./google.js";

/**
 * Google Play receipt validation.
 *
 * The client sends the **purchase token** — that is what
 * `PurchaseDetails.verificationData.serverVerificationData` is on Android —
 * and this asks Play what that token is actually worth. Everything returned
 * comes from Play; nothing the caller claimed is trusted.
 *
 * Setup, all in Play Console (Users and permissions → the service account):
 *   1. A service account with the "View financial data" permission, linked to
 *      the app. It does NOT have to be the Firebase one, and usually is not.
 *   2. The Google Play Android Developer API enabled on its Google Cloud
 *      project.
 *   3. `wrangler secret put PLAY_SERVICE_ACCOUNT` with that account's JSON.
 *
 * Newly linked accounts take up to 24 hours to work, which reads exactly like
 * a wrong key. If validation 401s on a fresh setup, wait before changing
 * anything.
 */

const BASE = "https://androidpublisher.googleapis.com/androidpublisher/v3";

/** Every state Play reports, and whether it still entitles the user. */
const ENTITLED = new Set([
  "SUBSCRIPTION_STATE_ACTIVE",
  // Payment failed but Play is retrying and access is meant to continue.
  "SUBSCRIPTION_STATE_IN_GRACE_PERIOD",
  // Cancelled, but paid up to expiryTime. The money has been taken.
  "SUBSCRIPTION_STATE_CANCELED",
]);

interface SubscriptionV2 {
  subscriptionState?: string;
  lineItems?: Array<{ productId?: string; expiryTime?: string }>;
  testPurchase?: Record<string, unknown>;
}

export interface StoreEntitlement {
  productId: string;
  expiresAt: Date;
  /**
   * How the store names this purchase in its notifications.
   *
   * Play uses the purchase token, Apple the original transaction id — and
   * Apple's is *not* the receipt that was sent here, so it has to be read out
   * of the validated response rather than assumed.
   */
  storeId: string;
}

export function playConfigured(env: Env): boolean {
  return Boolean(env.PLAY_SERVICE_ACCOUNT && env.ANDROID_PACKAGE_NAME);
}

export async function validatePlayPurchase(
  env: Env,
  purchaseToken: string,
): Promise<StoreEntitlement> {
  const token = await serviceAccountToken(
    env.PLAY_SERVICE_ACCOUNT,
    ANDROID_PUBLISHER_SCOPE,
    "PLAY_SERVICE_ACCOUNT",
  );

  const url =
    `${BASE}/applications/${encodeURIComponent(env.ANDROID_PACKAGE_NAME)}` +
    `/purchases/subscriptionsv2/tokens/${encodeURIComponent(purchaseToken)}`;

  const response = await fetch(url, {
    headers: { authorization: `Bearer ${token}` },
  });

  if (response.status === 404 || response.status === 410) {
    // Play does not know this token. Either it was made up, or it belongs to
    // a different app.
    throw new HttpsError("permission-denied", "That purchase could not be verified.");
  }
  if (!response.ok) {
    // A configuration problem, not a fraudulent user. Logged in full and
    // reported vaguely, because the detail is ours and not theirs.
    console.error("play validation failed", response.status, await response.text());
    throw new HttpsError(
      "unavailable",
      "We could not reach the Play Store to confirm that purchase. Please try again.",
    );
  }

  const body = (await response.json()) as SubscriptionV2;
  const state = body.subscriptionState ?? "";
  if (!ENTITLED.has(state)) {
    throw new HttpsError("permission-denied", "That subscription is not active.");
  }

  // A subscription has one line item; taking the latest expiry is what makes
  // an upgrade or a plan change resolve to the term the user actually holds.
  let expiresAt: Date | null = null;
  let productId = "";
  for (const item of body.lineItems ?? []) {
    if (!item.expiryTime) continue;
    const at = new Date(item.expiryTime);
    if (Number.isNaN(at.getTime())) continue;
    if (!expiresAt || at > expiresAt) {
      expiresAt = at;
      productId = item.productId ?? productId;
    }
  }

  if (!expiresAt) {
    throw new HttpsError("permission-denied", "That purchase has no active term.");
  }
  if (expiresAt.getTime() <= Date.now()) {
    throw new HttpsError("permission-denied", "That subscription has expired.");
  }

  return { productId, expiresAt, storeId: purchaseToken };
}
