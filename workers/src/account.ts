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
 * Order matters, and it is data first: if the account row went first, the
 * `uid` would be gone and the remaining documents unattributable — deletable
 * only by hand. A failure part-way therefore leaves an account that can still
 * sign in and try again, which is the recoverable direction.
 */

/**
 * How far down the tree to walk.
 *
 * The real layout is one level deep (`users/{uid}/private/{doc}`); three is
 * headroom for a collection added later, and a hard stop so a cycle in the
 * data — or a bug here — cannot recurse forever inside a request.
 */
const MAX_DEPTH = 3;

export async function deleteAccount(env: Env, uid: string): Promise<{ deleted: true }> {
  const db = new Firestore(env);

  await purge(db, `users/${uid}`, 0);
  await purgePhotos(env, uid);
  await deleteUser(env, uid);

  return { deleted: true };
}

/** Deletes every subcollection under [path], then the document itself. */
async function purge(db: Firestore, path: string, depth: number): Promise<void> {
  if (depth < MAX_DEPTH) {
    for (const collection of await db.collectionIds(path)) {
      const ids = await db.documentIds(`${path}/${collection}`);

      // Depth-first: a document's own subcollections outlive it otherwise.
      // Firestore keeps them as orphans reachable only by path, which is
      // exactly the residue this function exists to prevent.
      for (const id of ids) {
        await purge(db, `${path}/${collection}/${id}`, depth + 1);
      }
      await db.deleteAll(ids.map((id) => `${path}/${collection}/${id}`));
    }
  }

  await db.delete(path);
}

/**
 * The meal photos.
 *
 * Best effort: R2 is optional (the binding is absent until the bucket exists),
 * and an orphaned image is not a reason to fail a deletion that has already
 * removed everything identifying. Listing is paginated because an active diary
 * can hold more than one page of objects.
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
