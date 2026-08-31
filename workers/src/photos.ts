import { HttpsError, json } from "./callable.js";
import type { Env } from "./env.js";

/**
 * Meal photos, in R2.
 *
 * This replaces Cloud Storage. R2 charges nothing for egress, which is the part
 * of an image-heavy app that eventually costs real money.
 *
 * What `storage.rules` used to enforce is enforced here instead, because R2 has
 * no rules layer: you reach your own subtree and nothing else, uploads are
 * bounded, and the content type must be an image. A bucket someone can write
 * arbitrary bytes to at arbitrary size is a bill waiting to happen.
 */

/** The client downsizes to a 1280px long edge at q80 — 150-300KB. */
const MAX_BYTES = 5 * 1024 * 1024;

const keyFor = (uid: string, mealId: string) => `users/${uid}/meals/${mealId}.jpg`;

/** Rejects anything that could escape the caller's own prefix. */
function requireMealId(value: string | null): string {
  if (!value || !/^[A-Za-z0-9_-]{1,64}$/.test(value)) {
    throw new HttpsError("invalid-argument", "That meal id is not valid.");
  }
  return value;
}

export async function uploadPhoto(env: Env, uid: string, request: Request): Promise<Response> {
  const mealId = requireMealId(request.headers.get("x-meal-id"));

  const contentType = request.headers.get("content-type") ?? "";
  if (!contentType.startsWith("image/")) {
    throw new HttpsError("invalid-argument", "Only images can be uploaded.");
  }

  const body = await request.arrayBuffer();
  if (body.byteLength === 0) {
    throw new HttpsError("invalid-argument", "That photo is empty.");
  }
  if (body.byteLength > MAX_BYTES) {
    throw new HttpsError(
      "invalid-argument",
      "That image is too large. It should be downsized before upload.",
    );
  }

  const key = keyFor(uid, mealId);
  await env.PHOTOS.put(key, body, {
    httpMetadata: {
      contentType: "image/jpeg",
      // Immutable: the key is derived from the meal id, so a given URL always
      // returns the same bytes and can be cached hard.
      cacheControl: "public, max-age=31536000, immutable",
    },
  });

  // No public base configured yet means the object is stored but not yet
  // servable. Returning null rather than a broken URL keeps the diary on the
  // local file, which is the same degradation the Storage path had.
  const base = env.PHOTO_PUBLIC_BASE.replace(/\/$/, "");
  return json({ url: base ? `${base}/${key}` : null });
}

export async function deletePhoto(env: Env, uid: string, request: Request): Promise<Response> {
  const mealId = requireMealId(new URL(request.url).searchParams.get("mealId"));
  // Already gone, or never uploaded. Nothing depends on this.
  await env.PHOTOS.delete(keyFor(uid, mealId)).catch(() => undefined);
  return json({ deleted: true });
}
