import type { Env } from "./env.js";
import { Firestore } from "./firestore.js";
import { deleteUser } from "./identity.js";

/**
 * Account deletion, for real.
 *
 * Both stores are required to say yes to this, and the client can only reach
 * one of them. `firestore.rules` deny client writes to `scans`, `quota`,
 * `subscription` and `private/**` — deliberately, because a user who can write
 * their own quota has unlimited scans — so a client-side purge deletes the
 * diary and leaves the scan log, the entitlement and the OTP state behind
 * under a uid nobody owns. Play's data-deletion policy and GDPR Art. 17 both
 * ask for all of it.
 *
 * Deleting the Firebase user is also easier here. `user.delete()` on the
 * client throws `requires-recent-login` for anyone signed in longer than a few
 * minutes, which is almost everyone; the Identity Toolkit admin API has no
 * such rule.
 *
 * ---------------------------------------------------------------------------
 * IT RUNS IN PASSES, AND THAT IS NOT OPTIONAL
 * ---------------------------------------------------------------------------
 * A Worker invocation may make **50 outbound subrequests** on the free plan.
 * Every Firestore REST call is one. The first version of this walked the tree
 * depth-first and asked every *document* for its subcollections, which is one
 * subrequest per document to discover nothing — a fresh account with eight
 * saved plans and a handful of meals blew the limit and died with
 * "Too many subrequests by single Worker invocation", leaving the account
 * half-deleted. Found on a device; no test would have shown it, because the
 * limit is a property of the runtime.
 *
 * So: no per-document recursion, a hard budget, and a `done` flag. The client
 * calls again while `done` is false. That also makes deletion work for someone
 * with two years of diary, which no single invocation could ever finish.
 *
 * Order is data first: if the account row went first the uid would be gone and
 * the remaining documents unattributable. A pass that runs out of budget
 * therefore leaves an account that can still sign in and try again, which is
 * the recoverable direction.
 */

/**
 * Subrequests one pass may spend.
 *
 * Well under the platform's 50, because the OAuth token exchange, the photo
 * purge and the Identity Toolkit call all come out of the same allowance — and
 * running out is a half-deleted account rather than a slow one.
 */
const BUDGET = 30;

export async function deleteAccount(
  env: Env,
  uid: string,
): Promise<{ deleted: boolean; done: boolean }> {
  const db = new Firestore(env);
  const root = `users/${uid}`;
  let spent = 0;

  const collections = await db.collectionIds(root);
  spent++;

  for (const collection of collections) {
    // Leave room for the listing *and* the commit it implies.
    while (spent < BUDGET - 2) {
      const path = `${root}/${collection}`;
      const ids = await db.documentIds(path, 300);
      spent++;
      if (ids.length === 0) break;

      await db.deleteAll(ids.map((id) => `${path}/${id}`));
      spent += Math.ceil(ids.length / 400);

      // A short page was the last one.
      if (ids.length < 300) break;
    }
    if (spent >= BUDGET - 2) {
      // Out of budget with data still to go. Say so; the client calls again.
      return { deleted: false, done: false };
    }
  }

  // Everything under the account is gone. Now the account itself.
  await purgePhotos(env, uid);
  spent++;

  await db.delete(root);
  await deleteUser(env, uid);

  return { deleted: true, done: true };
}

/**
 * The meal photos.
 *
 * Best effort: R2 is optional (the binding is absent until the bucket exists),
 * and an orphaned image is not a reason to fail a deletion that has already
 * removed everything identifying. R2 operations are not subrequests, so this
 * does not compete with the Firestore budget.
 */
async function purgePhotos(env: Env, uid: string): Promise<void> {
  const bucket = env.PHOTOS;
  if (!bucket) return;

  try {
    let cursor: string | undefined;
    do {
      const page = await bucket.list({ prefix: `users/${uid}/`, cursor });
      const keys = page.objects.map((o) => o.key);
      if (keys.length > 0) await bucket.delete(keys);
      cursor = page.truncated ? page.cursor : undefined;
    } while (cursor);
  } catch (error) {
    console.error("photo purge failed", error);
  }
}
