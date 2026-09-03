import { HttpsError } from "./callable.js";
import { Firestore } from "./firestore.js";
import type { Env } from "./env.js";

/**
 * Food search, against USDA FoodData Central.
 *
 * Behind the Worker rather than called from the app, because FDC needs an API
 * key and a key in the binary is a key that has been published. Open Food Facts
 * keeps the barcode path — it needs no key, and it is the stronger of the two
 * for packaged goods, which is exactly what a barcode identifies.
 *
 * The split plays to each database's strengths. Someone typing "chicken breast"
 * wants the reference food, and FDC is where that lives — it is also the source
 * the scan prompt already tells the model to match its composition against, so
 * a searched food and an estimated one now agree on what chicken breast is.
 */

const BASE = "https://api.nal.usda.gov/fdc/v1/foods/search";

/**
 * Generic foods only. Branded is excluded on purpose.
 *
 * Unfiltered, a search for "grilled chicken breast" returns a frozen dinner and
 * a deli pack before it returns chicken — Branded is by far the largest dataset
 * and it dominates the ranking. Foundation and SR Legacy are the lab-analysed
 * reference foods; Survey (FNDDS) is foods as actually eaten, which is what a
 * diary is recording. Packaged products are reachable by barcode instead.
 */
const DATA_TYPES = "Foundation,SR Legacy,Survey (FNDDS)";

/** FDC nutrient ids. Values are per 100g across all these datasets. */
const NUTRIENTS = {
  calories: 1008, // Energy, KCAL (1062 is the kJ twin — not this one)
  protein: 1003,
  carbs: 1005, // Carbohydrate, by difference — total, inclusive of fibre
  fat: 1004,
  fiber: 1079,
  sugar: 2000,
} as const;

/**
 * FDC's search endpoint fails intermittently, and it is not our request.
 *
 * Roughly half of otherwise-identical calls come back HTTP 400 carrying an
 * *nginx* HTML error page rather than a JSON error — and the same query
 * succeeds on immediate retry. An application-level rejection would be JSON, so
 * this is the edge dropping requests, not a malformed URL.
 *
 * Measured against the live API, in order of what was tried:
 *
 *     1 attempt                     ~50% failed
 *     3 attempts                    ~22% failed
 *     5 attempts, %20 encoding       ~8% failed  (11/12), 1.0-4.7s
 *
 * The last two changes went in together, so how much each contributed is not
 * separable — `%20` was adopted because it is unambiguous, not because it was
 * proven to help.
 *
 * Five is where this stops. The delays stay small deliberately: this sits
 * behind someone typing in a search box, and a slow answer is its own kind of
 * failure. The residual few percent is caught by `WorkerFoodRepository`, which
 * falls back to Open Food Facts, so a search always returns something.
 *
 * 429 is never retried — that is a real rate limit and hammering it is rude.
 */
const ATTEMPTS = 5;
const BACKOFF_MS = [150, 300, 600, 1000];

async function fetchSearch(url: string): Promise<Response> {
  let last!: Response;
  for (let attempt = 0; attempt < ATTEMPTS; attempt++) {
    last = await fetch(url, { headers: { accept: "application/json" } });
    if (last.ok || last.status === 429) return last;
    if (attempt < ATTEMPTS - 1) {
      console.warn(`fdc search ${last.status}, retrying (${attempt + 1}/${ATTEMPTS - 1})`);
      await new Promise((resolve) => setTimeout(resolve, BACKOFF_MS[attempt]));
    }
  }
  return last;
}

interface FdcNutrient {
  nutrientId?: number;
  unitName?: string;
  value?: number;
}

interface FdcFood {
  fdcId?: number;
  description?: string;
  dataType?: string;
  foodNutrients?: FdcNutrient[];
}

/** Longest query accepted. FDC ignores more and it is a prompt-free path. */
const MAX_QUERY = 80;

/** Searches one account may run in an hour. */
const MAX_SEARCHES_PER_HOUR = 120;

/**
 * Counts a search against this account's hour.
 *
 * Deliberately generous: a person typing "chicken biryani" with a 450ms debounce
 * spends a handful, and 120 is far above any real session. It is there to stop a
 * script, not to ration a user — so it refuses rather than degrading, and says
 * to wait rather than blaming the food database.
 */
async function assertSearchAllowed(db: Firestore, uid: string): Promise<void> {
  const hour = new Date().toISOString().slice(0, 13);
  const path = `users/${uid}/private/search`;

  await db.transaction(async (tx) => {
    const data = await tx.get(path);
    const used = data?.hour === hour ? ((data?.count as number | undefined) ?? 0) : 0;

    if (used >= MAX_SEARCHES_PER_HOUR) {
      throw new HttpsError(
        "resource-exhausted",
        "That is a lot of searching. Give it a few minutes.",
      );
    }
    tx.set(path, { hour, count: used + 1 });
  });
}

export async function searchFoods(
  env: Env,
  uid: string,
  data: { query?: string; limit?: number },
): Promise<{ items: unknown[] }> {
  const query = (data.query ?? "").trim().slice(0, MAX_QUERY);
  // Two characters is the shortest query worth a round trip; below that the
  // result set is noise.
  if (query.length < 2) return { items: [] };

  if (!env.USDA_API_KEY) {
    throw new HttpsError("failed-precondition", "Food search is not configured yet.");
  }

  // One shared FDC key serves everyone, at 1000 requests an hour, and this
  // route retries up to five times per call. Unmetered, one client typing fast
  // could exhaust the hour for every other user — search being the path that is
  // meant to always work makes that the worst thing to leave open.
  await assertSearchAllowed(new Firestore(env), uid);

  // Built by hand rather than with URLSearchParams, which encodes a space as
  // `+`. That is correct for form bodies and merely legal in a query string;
  // `%20` is unambiguous, and this endpoint is fussy enough not to hand it
  // anything it might interpret twice.
  const pageSize = Math.min(Math.max(data.limit ?? 20, 1), 50);
  const url =
    `${BASE}?api_key=${encodeURIComponent(env.USDA_API_KEY)}` +
    `&query=${encodeURIComponent(query)}` +
    `&dataType=${encodeURIComponent(DATA_TYPES)}` +
    `&pageSize=${pageSize}`;

  const response = await fetchSearch(url);

  if (response.status === 429) {
    // FDC allows 1000 requests per hour per key.
    throw new HttpsError("resource-exhausted", "Food search is busy. Try again shortly.");
  }
  if (!response.ok) {
    console.error(
      `fdc search failed after ${ATTEMPTS} attempts`,
      response.status,
      (await response.text()).slice(0, 200),
    );
    throw new HttpsError("unavailable", "Food search is unavailable. Try again.");
  }

  const body = (await response.json()) as { foods?: FdcFood[] };

  const items = (body.foods ?? [])
    .map(toFoodItem)
    .filter((item): item is Record<string, unknown> => item !== null);

  return { items };
}

/**
 * One FDC food as the app's own `FoodItem` JSON.
 *
 * Emitting the model's shape rather than inventing a second one means the
 * client calls `FoodItem.fromJson` and there is one contract, not two.
 */
function toFoodItem(food: FdcFood): Record<string, unknown> | null {
  const name = food.description?.trim();
  if (!name) return null;

  const byId = new Map<number, number>();
  for (const n of food.foodNutrients ?? []) {
    if (typeof n.nutrientId !== "number" || typeof n.value !== "number") continue;
    // Energy appears in both KCAL and kJ under different ids; guard the unit
    // anyway, so a dataset that reuses the id cannot slip 4.184x through.
    if (n.nutrientId === NUTRIENTS.calories && n.unitName?.toUpperCase() !== "KCAL") {
      continue;
    }
    byId.set(n.nutrientId, n.value);
  }

  // A food with no energy figure is useless in a diary, and some Foundation
  // entries genuinely have none. Dropping it beats showing a 0 kcal food.
  const calories = byId.get(NUTRIENTS.calories);
  if (calories === undefined) return null;

  const at = (id: number): number => byId.get(id) ?? 0;

  return {
    // Fresh per result rather than derived from fdcId: the same food can be
    // added to one meal twice, and the scan controller keys portion edits and
    // removals on this id.
    id: crypto.randomUUID(),
    name: name.length > 120 ? `${name.slice(0, 117)}...` : name,
    // Every dataset here reports per 100g, so that is the portion offered. The
    // result screen's portion control takes it from there.
    portionDescription: "100 g",
    portionGrams: 100,
    nutrition: {
      calories,
      protein: at(NUTRIENTS.protein),
      carbs: at(NUTRIENTS.carbs),
      fat: at(NUTRIENTS.fat),
      fiber: at(NUTRIENTS.fiber),
      sugar: at(NUTRIENTS.sugar),
    },
    source: "database",
    // The composition is measured, but the *portion* is still the user's to
    // set — so this is not "high".
    confidence: "medium",
    userEdited: false,
  };
}
