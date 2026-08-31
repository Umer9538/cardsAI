import { HttpsError } from "./callable.js";
import type { Env } from "./env.js";
import { Firestore, type Write } from "./firestore.js";

/**
 * The local mirror of USDA FoodData Central.
 *
 * Searching FDC live was both slow and unreliable — 1 to 5 seconds, and roughly
 * one call in twelve failing even after five retries, because their edge drops
 * requests. Neither is acceptable behind a search box. So the generic datasets
 * are copied into Firestore once and searched from there: the client queries it
 * directly, which is fast, works offline through Firestore's cache, and cannot
 * be broken by FDC being down.
 *
 * Only the generic datasets are mirrored — Foundation, SR Legacy and Survey
 * (FNDDS). Branded is excluded for the same reason `searchFoods` excludes it:
 * it is enormous, it dominates ranking, and packaged goods are reachable by
 * barcode instead.
 *
 * ---------------------------------------------------------------------------
 * How search works without full-text search
 * ---------------------------------------------------------------------------
 * Firestore has no LIKE and no full-text index. Each food therefore stores a
 * `tokens` array — its description reduced to lowercase words — and the client
 * queries `array-contains-any`, then ranks the candidates itself.
 *
 * Whole words only, no prefixes. Indexing every prefix would let "chick" match
 * "chicken", but a two- or three-letter token matches thousands of documents,
 * and `array-contains-any` returns an arbitrary page of them rather than the
 * best ones — so a partial word would actively make results worse. People
 * search for food in whole words.
 *
 * `tokenize` is duplicated in `FirestoreFoodRepository` on the Dart side. The
 * two must agree: a token written here and not produced there is a food that
 * can never be found.
 */

const LIST_URL = "https://api.nal.usda.gov/fdc/v1/foods/list";

/** The generic datasets, in the order they are synced. */
export const DATASETS = ["Foundation", "SR Legacy", "Survey (FNDDS)"] as const;
export type Dataset = (typeof DATASETS)[number];

/**
 * How generic a dataset's foods are. Lower sorts first.
 *
 * This is what makes search usable, and it is not a cosmetic preference.
 * `array-contains-any` returns an *arbitrary* page of matches, so without an
 * ordering the ranker only ever sees 60 random foods that share a word — which
 * is how "olive oil" came back as OLIVE GARDEN lasagna and "banana" as banana
 * split. Ordering the query by this pulls the reference foods into the page,
 * and the text ranking then chooses between them.
 *
 * Survey (FNDDS) is not junk — "Chicken breast, grilled without sauce" lives
 * there — it just also holds every restaurant dish, so it goes last.
 */
const RANK: Record<Dataset, number> = {
  Foundation: 0,
  "SR Legacy": 1,
  "Survey (FNDDS)": 2,
};

/** FDC's maximum. Fewer pages means fewer chances to be dropped mid-sync. */
const PAGE_SIZE = 200;

/** Firestore allows 500 writes per commit; 200 keeps the payload comfortable. */
const COMMIT_SIZE = 200;

/**
 * Keyed by nutrient *number*, not id.
 *
 * FDC returns nutrients in two shapes and the number is the only key present in
 * both. `/foods/list?format=full` carries `{number, amount, unitName}` and no
 * id whatsoever; search carries `{nutrientId, nutrientNumber, value}`. Keying
 * on the id worked against search and silently matched nothing against list —
 * which is how the first sync stored zero foods out of 394 that all had
 * complete nutrition.
 *
 * 208 is energy in kcal; 268 is the same energy in kJ.
 */
const NUTRIENTS = {
  calories: "208",
  protein: "203",
  carbs: "205",
  fat: "204",
  fiber: "291",
  sugar: "269",
} as const;

/** For the search shape, which gives an id and may omit the number. */
const NUMBER_BY_ID: Record<number, string> = {
  1008: "208",
  1003: "203",
  1005: "205",
  1004: "204",
  1079: "291",
  2000: "269",
};

/**
 * Words worth indexing.
 *
 * Two characters and under are dropped: FDC descriptions are full of "or",
 * "in", "w/" and they match everything, which is the opposite of useful in an
 * `array-contains-any` query.
 *
 * MUST match `FirestoreFoodRepository.tokenize` on the client.
 */
export function tokenize(text: string): string[] {
  const words = text
    .toLowerCase()
    .split(/[^a-z0-9]+/)
    .filter((word) => word.length > 2);
  // Firestore indexes every array element, and a description repeating a word
  // gains nothing from indexing it twice.
  return [...new Set(words)].slice(0, 40);
}

/**
 * FDC reports nutrients in two different shapes, and both turn up here.
 *
 *   search      { nutrientId: 1008, unitName: "KCAL", value: 135 }
 *   list/full   { nutrient: { id: 1008, unitName: "kcal" }, amount: 135 }
 *
 * Reading only the first shape is why the first sync stored nothing from 200
 * perfectly good records: the field was present, just spelled differently.
 */
interface FdcNutrient {
  number?: string;
  nutrientNumber?: string;
  nutrientId?: number;
  nutrient?: { id?: number; number?: string; unitName?: string };
  unitName?: string;
  value?: number;
  amount?: number;
}

function numberOf(n: FdcNutrient): string | undefined {
  const direct = n.number ?? n.nutrientNumber ?? n.nutrient?.number;
  if (typeof direct === "string") return direct;
  const id = n.nutrientId ?? n.nutrient?.id;
  return typeof id === "number" ? NUMBER_BY_ID[id] : undefined;
}

function valueOf(n: FdcNutrient): number | undefined {
  return n.value ?? n.amount;
}

function unitOf(n: FdcNutrient): string {
  return (n.unitName ?? n.nutrient?.unitName ?? "").toUpperCase();
}

interface FdcFood {
  fdcId?: number;
  description?: string;
  dataType?: string;
  foodNutrients?: FdcNutrient[];
}

/** One food as a Firestore document, or null when it is not worth storing. */
function toDocument(food: FdcFood): Record<string, unknown> | null {
  const name = food.description?.trim();
  if (!name || typeof food.fdcId !== "number") return null;

  const byNumber = new Map<string, number>();
  for (const n of food.foodNutrients ?? []) {
    const number = numberOf(n);
    const value = valueOf(n);
    if (number === undefined || typeof value !== "number") continue;
    // Guard the unit anyway: a dataset that reported energy in kJ under 208
    // would otherwise be 4.184x wrong and look perfectly plausible.
    if (number === NUTRIENTS.calories && unitOf(n) !== "KCAL") continue;
    byNumber.set(number, value);
  }

  // A food with no energy figure cannot be logged in a diary, so it is not
  // worth a document or the index entries that come with it.
  const calories = byNumber.get(NUTRIENTS.calories);
  if (calories === undefined) return null;

  const at = (number: string): number => byNumber.get(number) ?? 0;

  return {
    fdcId: food.fdcId,
    name: name.length > 120 ? `${name.slice(0, 117)}...` : name,
    tokens: tokenize(name),
    dataType: food.dataType ?? "",
    rank: RANK[(food.dataType ?? "") as Dataset] ?? 3,
    // Every dataset mirrored here reports per 100g.
    portionGrams: 100,
    calories,
    protein: at(NUTRIENTS.protein),
    carbs: at(NUTRIENTS.carbs),
    fat: at(NUTRIENTS.fat),
    fiber: at(NUTRIENTS.fiber),
    sugar: at(NUTRIENTS.sugar),
    syncedAt: new Date(),
  };
}

/**
 * Fetches one page of one dataset and writes it to `foods/{fdcId}`.
 *
 * Deliberately one page per call. A full sync is tens of thousands of foods
 * across a hundred-odd pages, and doing it in a single invocation would sit
 * against the Worker's limits with no way to resume when it fell over. A page
 * at a time is restartable from any point, and the cursor is just a number.
 */
export async function syncPage(
  env: Env,
  dataset: Dataset,
  pageNumber: number,
): Promise<{
  dataset: Dataset;
  pageNumber: number;
  fetched: number;
  withNutrients: number;
  sampleKeys: string[];
  sampleNutrients: unknown[];
  stored: number;
  done: boolean;
}> {
  if (!env.USDA_API_KEY) {
    throw new HttpsError("failed-precondition", "USDA_API_KEY is not set.");
  }

  const response = await fetch(`${LIST_URL}?api_key=${encodeURIComponent(env.USDA_API_KEY)}`, {
    method: "POST",
    headers: { "content-type": "application/json", accept: "application/json" },
    body: JSON.stringify({
      dataType: [dataset],
      pageSize: PAGE_SIZE,
      pageNumber,
      // Abridged is the default and omits foodNutrients entirely, which makes
      // every record unusable here — a food with no energy figure cannot be
      // logged.
      format: "full",
    }),
  });

  if (!response.ok) {
    throw new HttpsError(
      "unavailable",
      `FDC list failed: HTTP ${response.status}`,
    );
  }

  const foods = (await response.json()) as FdcFood[];
  if (!Array.isArray(foods)) {
    throw new HttpsError("internal", "FDC list returned an unexpected shape.");
  }

  const documents = foods
    .map(toDocument)
    .filter((d): d is Record<string, unknown> => d !== null);

  const db = new Firestore(env);
  for (let i = 0; i < documents.length; i += COMMIT_SIZE) {
    const writes: Write[] = documents.slice(i, i + COMMIT_SIZE).map((data) => ({
      path: `foods/${data.fdcId}`,
      data,
      // Replace rather than merge: a food re-synced after FDC revised it should
      // not keep stale tokens from the old description alongside the new ones.
      merge: false,
    }));
    await db.commit(writes);
  }

  return {
    dataset,
    pageNumber,
    fetched: foods.length,
    // Reported so a sync that silently stores nothing says why: a page that
    // arrives with records but no nutrients is a response-shape problem, not an
    // empty dataset.
    withNutrients: foods.filter((f) => (f.foodNutrients?.length ?? 0) > 0).length,
    sampleKeys: foods.length > 0 ? Object.keys(foods[0]).sort() : [],
    sampleNutrients: (foods[0]?.foodNutrients ?? []).slice(0, 3),
    stored: documents.length,
    // A short page is the last page.
    done: foods.length < PAGE_SIZE,
  };
}

/**
 * Walks every dataset from the beginning.
 *
 * [budget] bounds how many pages one invocation will do, so this can be driven
 * either by cron in daily slices or by hand for the initial import. Progress is
 * kept in `config/foodSync` so the next call resumes rather than restarts.
 */
export async function syncCatalogue(
  env: Env,
  budget = 25,
  reset = false,
): Promise<Record<string, unknown>> {
  const db = new Firestore(env);
  const state = reset ? {} : ((await db.get("config/foodSync")) ?? {});

  let index = DATASETS.indexOf((state.dataset as Dataset) ?? DATASETS[0]);
  if (index < 0) index = 0;
  let page = (state.pageNumber as number | undefined) ?? 1;

  let stored = 0;
  let fetched = 0;
  let withNutrients = 0;
  let pages = 0;
  let sampleKeys: string[] = [];
  let sampleNutrients: unknown[] = [];

  while (pages < budget && index < DATASETS.length) {
    const result = await syncPage(env, DATASETS[index], page);
    stored += result.stored;
    fetched += result.fetched;
    withNutrients += result.withNutrients;
    if (sampleKeys.length === 0) {
      sampleKeys = result.sampleKeys;
      sampleNutrients = result.sampleNutrients;
    }
    pages++;

    if (result.done) {
      index++;
      page = 1;
    } else {
      page++;
    }
  }

  const finished = index >= DATASETS.length;
  await db.set("config/foodSync", {
    // Wrapping back to the first dataset means the next run re-checks
    // everything, which is how a revised food gets picked up at all — FDC has
    // no "changed since" filter.
    dataset: finished ? DATASETS[0] : DATASETS[index],
    pageNumber: finished ? 1 : page,
    lastRunAt: new Date(),
    ...(finished ? { lastCompletedAt: new Date() } : {}),
  });

  const summary = {
    pages,
    fetched,
    stored,
    withNutrients,
    finished,
    nextDataset: finished ? DATASETS[0] : DATASETS[index],
    nextPage: finished ? 1 : page,
    ...(stored === 0 && fetched > 0 ? { sampleKeys, sampleNutrients } : {}),
  };
  console.log("food catalogue sync", JSON.stringify(summary));
  return summary;
}
