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

/**
 * How many documents the day's total is spread across.
 *
 * **This is not tuning, it is a hard Firestore limit.** A single document
 * sustains about one write a second, and `recordSpend` runs on every scan and
 * every plan — so one document put a ceiling on the app that no amount of
 * paying Google would lift. At a couple of scans each, contention becomes
 * visible in the low tens of thousands of daily users, and it fails as
 * transaction aborts on the critical path of the app's core feature.
 *
 * Sixteen shards buys 16x that, which is several hundred thousand daily users
 * — well past anything else in the system. The cost is that reading the total
 * is 16 document reads instead of 1, taken in a single `batchGet` round trip,
 * which is the right trade: the read is cheap and the write is the thing that
 * fails under load.
 *
 * Raising this is safe and backwards compatible — a shard that has never been
 * written reads as zero. **Lowering it is not**: today's spend already sitting
 * in a shard above the new count would stop being counted, and the fuse would
 * read low for the rest of the day.
 */
const SHARDS = 16;

/** The legacy single-document path, still read so nothing is lost mid-day. */
const legacyPath = (day: string): string => `config/spend-${day}`;

const shardPath = (day: string, shard: number): string =>
  `config/spend-${day}-${shard}`;

const allPaths = (day: string): string[] => [
  legacyPath(day),
  ...Array.from({ length: SHARDS }, (_, i) => shardPath(day, i)),
];

const today = (): string => new Date().toISOString().slice(0, 10);

/**
 * Throws when today's spend is already over the ceiling.
 *
 * Called before the model, not after: a check that runs afterwards has already
 * paid for the call it was meant to prevent.
 */
export async function assertUnderDailyCap(db: Firestore, limitUsd?: number): Promise<void> {
  // Zero is a kill switch, not an omission: setting `config/scan.dailySpendCapUsd`
  // to 0 used to fall through to the $20 default, so the one lever an operator
  // would reach for in an incident did nothing. Only a missing or negative
  // value takes the default.
  const limit =
    typeof limitUsd === "number" && Number.isFinite(limitUsd) && limitUsd >= 0
      ? limitUsd
      : DEFAULT_DAILY_LIMIT_USD;

  let spent: number;
  try {
    // Every shard plus the legacy document, in one round trip. The legacy path
    // is included so a deploy that lands mid-day does not reset the fuse to
    // zero and hand out a second $20 of model calls.
    const docs = await db.batchGet(allPaths(today()));
    const micros = docs.reduce<number>((sum, doc) => {
      const value = Number(doc?.micros ?? 0);
      return sum + (Number.isFinite(value) ? value : 0);
    }, 0);
    spent = micros / MICROS;
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

  if (limit === 0 || spent >= limit) {
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
    // A random shard. Spreading by uid would look tidier and would be wrong:
    // one heavy account would then own one shard and hit the same per-document
    // ceiling the sharding exists to escape.
    const shard = Math.floor(Math.random() * SHARDS);
    await db.set(shardPath(today(), shard), {
      micros: increment(Math.round(usd * MICROS)),
      updatedAt: serverTimestamp(),
    });
  } catch (error) {
    console.error("spend not recorded", error);
  }
}
