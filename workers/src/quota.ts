/**
 * Which document an account's scan allowance is counted in.
 *
 * This lives in its own module because **two routes write it**: `scan.ts`
 * reserves against the bucket, and `rewards.ts` adds bonus scans to it. A
 * bonus landing in a document the scan never reads is a reward that silently
 * does nothing — the user watches an advert, is told it worked, and still has
 * no scans. They must agree, so they share one function rather than two copies
 * of a path string.
 */

/** `YYYY-MM`. The premium allowance renews monthly. */
export function premiumBucketId(now: Date = new Date()): string {
  return now.toISOString().slice(0, 7);
}

/**
 * `free-YYYY-MM-DD`. The free allowance renews **daily**.
 *
 * It used to be the literal string `free`, which never reset — so the free
 * tier was three scans for the lifetime of the account. Three scans cannot
 * produce even one "day with a full picture" (two eating occasions), which is
 * the app's own measure of whether someone is actually tracking, so nobody
 * reached the habit the product exists to build.
 *
 * A daily bucket also bounds the cost of a free account to
 * `freeScanLimit × cost-per-scan` per day, which a lifetime bucket could not
 * do once the limit was generous enough to be worth having.
 *
 * The old `free` document is deliberately **not** read or migrated. Leaving it
 * behind is the migration: every existing account simply starts tomorrow on a
 * fresh daily allowance, which is the outcome a migration would have had to
 * work to produce. It is removed with the account by the deletion sweep, which
 * enumerates subcollections rather than naming documents.
 *
 * The prefix matters. Without it a free bucket (`2026-11-19`) and a premium
 * one (`2026-11`) are two formats of the same thing in one collection, and the
 * only thing telling them apart is string length.
 */
export function freeBucketId(now: Date = new Date()): string {
  return `free-${now.toISOString().slice(0, 10)}`;
}

/**
 * One document per account per day, which accumulates.
 *
 * Deliberate: each is about a hundred bytes, so a thousand daily users cost
 * roughly 36 MB a year against a 1 GiB free allowance, and every read is by
 * exact path rather than a query. Scans still cost exactly one quota write
 * each, as they did against the lifetime bucket — the renewal is free.
 */
export function quotaPath(uid: string, bucketId: string): string {
  return `users/${uid}/quota/${bucketId}`;
}
