import { HttpsError } from "./callable.js";
import { Firestore, increment, serverTimestamp } from "./firestore.js";

/**
 * A ceiling on what the whole app can spend on the model in a day.
 *
 * The per-user quota caps how many scans one person gets. Nothing capped the
 * *total*, which is the number that matters when something goes wrong: a
 * scripted sign-up loop, a bug that retries in a tight loop, or a single
 * enthusiastic account on an unmetered path. The quota is per uid, and uids are
 * free.
 *
 * **It fails closed.** If the counter cannot be read, calls are refused rather
 * than allowed — the whole point of a spend limit is the case where something
 * is already going wrong, and a limiter that opens under failure is not one.
 *
 * The figure is deliberately coarse. It is not accounting; it is a fuse.
 */

/** USD per day across every user, before the model is refused. */
const DEFAULT_DAILY_LIMIT_USD = 20;

/**
 * Spend is counted in millionths of a dollar.
 *
 * Firestore's increment transform here is built for `integerValue`, and a scan
 * costs about $0.0012 — stored as dollars every call would round to zero and
 * the counter would sit at zero forever while the bill grew. Micros keep it
 * exact in whole numbers.
 */
const MICROS = 1_000_000;

const path = (day: string): string => `config/spend-${day}`;

const today = (): string => new Date().toISOString().slice(0, 10);

/**
 * Throws when today's spend is already over the ceiling.
 *
 * Called before the model, not after: a check that runs afterwards has already
 * paid for the call it was meant to prevent.
 */
export async function assertUnderDailyCap(db: Firestore, limitUsd?: number): Promise<void> {
  const limit = limitUsd && limitUsd > 0 ? limitUsd : DEFAULT_DAILY_LIMIT_USD;

  let spent: number;
  try {
    const doc = await db.get(path(today()));
    spent = Number(doc?.micros ?? 0) / MICROS;
    if (!Number.isFinite(spent)) spent = 0;
  } catch (error) {
    // Fail closed. See the note above: this exists for the moments when
    // something is already wrong, and those are exactly the moments a read
    // fails.
    console.error("spend cap unreadable; refusing", error);
    throw new HttpsError(
      "unavailable",
      "The service is briefly unavailable. Try again in a few minutes.",
    );
  }

  if (spent >= limit) {
    console.error("daily spend cap reached", JSON.stringify({ spent, limit }));
    throw new HttpsError(
      "resource-exhausted",
      "The service is at capacity for today. Please try again tomorrow.",
    );
  }
}

/**
 * Adds what a call actually cost.
 *
 * Best effort and deliberately not awaited by the caller's critical path: a
 * failure to record spend must never fail a scan the user has already paid for
 * in waiting. The consequence is that the ceiling can be crossed by whatever is
 * in flight, which is acceptable for a fuse.
 */
export async function recordSpend(db: Firestore, usd: number): Promise<void> {
  if (!Number.isFinite(usd) || usd <= 0) return;
  try {
    await db.set(path(today()), {
      micros: increment(Math.round(usd * MICROS)),
      updatedAt: serverTimestamp(),
    });
  } catch (error) {
    console.error("spend not recorded", error);
  }
}
