import { FieldValue, Timestamp } from "firebase-admin/firestore";
import { HttpsError, onCall, type CallableRequest } from "firebase-functions/v2/https";
import { logger } from "firebase-functions/v2";

import { db } from "./app.js";

/**
 * Bonus scans, earned by watching a rewarded ad.
 *
 * The `bonus` field this writes is already read by the scan quota, so a granted
 * reward widens the allowance without any special case at scan time.
 *
 * ---------------------------------------------------------------------------
 * TRUST
 * ---------------------------------------------------------------------------
 * This trusts the client's word that an ad was watched, and a client's word is
 * worth nothing — anyone can call a callable function. What makes that
 * acceptable rather than reckless is that the payout is *bounded*: a hard daily
 * cap means the worst case is a fixed, small number of free scans per account
 * per day, which costs cents rather than being an open tap.
 *
 * The real fix is AdMob **Server-Side Verification**: AdMob calls a URL of ours
 * directly when a reward is genuinely earned, signed with a key we verify
 * against Google's published key server. That removes the client from the loop
 * entirely. It needs live ad units to configure and test, so it is deliberately
 * left until those exist — see the note in CLAUDE.md. Until then, do not raise
 * these caps.
 */

const RULES = {
  /** Scans granted per ad. Must match `AdConfig.scansPerRewardedAd`. */
  scansPerAd: 3,
  /** Ads that can pay out per account per day. */
  maxAdsPerDay: 5,
  /** Minimum gap between payouts — a rewarded ad cannot finish faster. */
  cooldownSeconds: 30,
} as const;

function requireAuth(request: CallableRequest): string {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Sign in first.");
  return uid;
}

function today(): string {
  return new Date().toISOString().slice(0, 10);
}

export const grantBonusScans = onCall(
  { region: "us-central1", timeoutSeconds: 30 },
  async (request) => {
    const uid = requireAuth(request);
    const day = today();

    const rewardRef = db.doc(`users/${uid}/private/rewards`);

    // The counter and the grant move together, or a burst of parallel calls
    // would each read the same count and each pay out.
    const granted = await db.runTransaction(async (tx) => {
      const snap = await tx.get(rewardRef);
      const data = snap.data();

      const sameDay = data?.day === day;
      const adsToday = sameDay ? ((data?.adsToday as number) ?? 0) : 0;

      if (adsToday >= RULES.maxAdsPerDay) {
        throw new HttpsError(
          "resource-exhausted",
          `That is all the bonus scans for today. Come back tomorrow, or ` +
            "upgrade for more.",
        );
      }

      const lastAt = (data?.lastGrantedAt as Timestamp | undefined)?.toMillis() ?? 0;
      if ((Date.now() - lastAt) / 1000 < RULES.cooldownSeconds) {
        throw new HttpsError(
          "resource-exhausted",
          "Give it a moment before watching another.",
        );
      }

      tx.set(
        rewardRef,
        {
          day,
          adsToday: adsToday + 1,
          lastGrantedAt: FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
      return RULES.scansPerAd;
    });

    // Free accounts count against the lifetime "free" bucket, so that is where
    // the bonus has to land for it to be usable. Premium accounts do not see
    // rewarded ads at all.
    await db.doc(`users/${uid}/quota/free`).set(
      {
        bonus: FieldValue.increment(granted),
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );

    logger.info("bonus scans granted", { uid, granted });
    return { granted, scansPerAd: RULES.scansPerAd };
  },
);
