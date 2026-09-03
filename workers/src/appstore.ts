import { HttpsError } from "./callable.js";
import type { Env } from "./env.js";
import { StoreEntitlement } from "./play.js";

/**
 * Apple receipt validation.
 *
 * `in_app_purchase` is on StoreKit 1 here (nothing opts into StoreKit 2), so
 * what the client sends is the **base64 app receipt** — and `verifyReceipt` is
 * the endpoint that takes one. It is deprecated but fully operational, and
 * this is the honest match for the receipt we actually have.
 *
 * Migrating to the App Store Server API means switching the client to
 * StoreKit 2 first, so it sends a transaction id. That is a client change, not
 * a server one; until it happens, calling the newer API here would be code
 * that cannot run.
 *
 * Setup: App Store Connect → your app → App Information → App-Specific Shared
 * Secret, then `wrangler secret put APPLE_SHARED_SECRET`.
 */

const PRODUCTION = "https://buy.itunes.apple.com/verifyReceipt";
const SANDBOX = "https://sandbox.itunes.apple.com/verifyReceipt";

/** Apple's status codes, for the two that mean something specific. */
const SANDBOX_RECEIPT_SENT_TO_PRODUCTION = 21007;
const PRODUCTION_RECEIPT_SENT_TO_SANDBOX = 21008;

interface VerifyResponse {
  status?: number;
  latest_receipt_info?: Array<{
    product_id?: string;
    expires_date_ms?: string;
    cancellation_date_ms?: string;
    original_transaction_id?: string;
  }>;
}

export function appleConfigured(env: Env): boolean {
  return Boolean(env.APPLE_SHARED_SECRET);
}

async function verify(url: string, body: unknown): Promise<VerifyResponse> {
  const response = await fetch(url, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify(body),
  });
  if (!response.ok) {
    console.error("verifyReceipt transport failed", response.status, await response.text());
    throw new HttpsError(
      "unavailable",
      "We could not reach the App Store to confirm that purchase. Please try again.",
    );
  }
  return (await response.json()) as VerifyResponse;
}

export async function validateAppleReceipt(
  env: Env,
  receipt: string,
): Promise<StoreEntitlement> {
  const payload = {
    "receipt-data": receipt,
    password: env.APPLE_SHARED_SECRET,
    // Without this, an expired subscription comes back with no renewal info
    // at all rather than as expired, which is indistinguishable from a receipt
    // that never had one.
    "exclude-old-transactions": true,
  };

  // Production first, then sandbox on 21007. Apple's own guidance, and the
  // only arrangement that works for both a TestFlight build and a shipped one
  // without a build-time switch — reviewers test against sandbox on a binary
  // that is otherwise production.
  let body = await verify(PRODUCTION, payload);
  if (body.status === SANDBOX_RECEIPT_SENT_TO_PRODUCTION) {
    body = await verify(SANDBOX, payload);
  } else if (body.status === PRODUCTION_RECEIPT_SENT_TO_SANDBOX) {
    body = await verify(PRODUCTION, payload);
  }

  if (body.status !== 0) {
    console.warn("verifyReceipt rejected", body.status);
    throw new HttpsError("permission-denied", "That purchase could not be verified.");
  }

  // The most recent transaction that has not been refunded and has not run
  // out. `latest_receipt_info` is ordered oldest-first often enough to be
  // unreliable, so it is scanned rather than indexed.
  let expiresAt: Date | null = null;
  let productId = "";
  let storeId = "";
  for (const entry of body.latest_receipt_info ?? []) {
    // A cancellation date means Apple refunded or revoked it. Access ends
    // immediately, whatever the expiry says.
    if (entry.cancellation_date_ms) continue;

    const ms = Number(entry.expires_date_ms);
    if (!Number.isFinite(ms)) continue;
    const at = new Date(ms);
    if (!expiresAt || at > expiresAt) {
      expiresAt = at;
      productId = entry.product_id ?? productId;
      storeId = entry.original_transaction_id ?? storeId;
    }
  }

  if (!expiresAt) {
    throw new HttpsError("permission-denied", "That receipt holds no subscription.");
  }
  if (expiresAt.getTime() <= Date.now()) {
    throw new HttpsError("permission-denied", "That subscription has expired.");
  }

  return { productId, expiresAt, storeId };
}
