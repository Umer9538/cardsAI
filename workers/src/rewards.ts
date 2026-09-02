import { HttpsError } from "./callable.js";
import type { Env } from "./env.js";
import { Firestore, increment, serverTimestamp } from "./firestore.js";

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
 * worth nothing. What makes that acceptable rather than reckless is that the
 * payout is *bounded*: a hard daily cap means the worst case is a fixed, small
 * number of free scans per account per day, which costs cents rather than being
 * an open tap.
 *
 * The real fix is AdMob Server-Side Verification — AdMob calls a URL of ours
 * directly when a reward is genuinely earned, signed with a key verified
 * against Google's key server. A Worker is a better host for that callback than
 * a Cloud Function was, since it is a plain HTTP endpoint. It still needs live
 * ad units to configure. Until then, do not raise these caps.
 */

const RULES = {
  /**
   * Scans granted per ad. Must match `AdConfig.scansPerRewardedAd`, where the
   * arithmetic for why this is 1 rather than 3 is written out: at a Tier-2
   * eCPM one impression funds less than one scan, so three made every rewarded
   * view in this app's home market cost more than it earned.
   */
  scansPerAd: 1,
  maxAdsPerDay: 5,
  /** A rewarded ad cannot finish faster than this. */
  cooldownSeconds: 30,
} as const;

const today = (): string => new Date().toISOString().slice(0, 10);

export async function grantBonusScans(
  env: Env,
  uid: string,
): Promise<{ granted: number; scansPerAd: number }> {
  const db = new Firestore(env);
  const day = today();
  const rewardPath = `users/${uid}/private/rewards`;

  // The counter and the grant move together, or a burst of parallel calls
  // would each read the same count and each pay out.
  const granted = await db.transaction(async (tx) => {
    const data = await tx.get(rewardPath);

    const sameDay = data?.day === day;
    const adsToday = sameDay ? ((data?.adsToday as number | undefined) ?? 0) : 0;

    if (adsToday >= RULES.maxAdsPerDay) {
      throw new HttpsError(
        "resource-exhausted",
        "That is all the bonus scans for today. Come back tomorrow, or upgrade for more.",
      );
    }

    const lastAt = data?.lastGrantedAt instanceof Date ? data.lastGrantedAt.getTime() : 0;
    if ((Date.now() - lastAt) / 1000 < RULES.cooldownSeconds) {
      throw new HttpsError("resource-exhausted", "Give it a moment before watching another.");
    }

    tx.set(rewardPath, {
      day,
      adsToday: adsToday + 1,
      lastGrantedAt: serverTimestamp(),
    });
    return RULES.scansPerAd;
  });

  // Free accounts count against the lifetime "free" bucket, so that is where
  // the bonus has to land for it to be usable. Premium accounts do not see
  // rewarded ads at all.
  await db.set(`users/${uid}/quota/free`, {
    bonus: increment(granted),
    updatedAt: serverTimestamp(),
  });

  console.log("bonus scans granted", uid, granted);
  return { granted, scansPerAd: RULES.scansPerAd };
}
