import { HttpsError } from "./callable.js";
import type { Env } from "./env.js";
import { documentId, Firestore, increment, serverTimestamp } from "./firestore.js";
import { assertUnderDailyCap, recordSpend } from "./spend.js";
import {
  isQualifier,
  PLAN_PROMPT_VERSION,
  PLAN_SCHEMA,
  PLAN_SYSTEM_PROMPT,
  planPrompt,
  purposeFor,
  type AvoidanceEntry,
  type PlanGoal,
  type PlanMotivation,
  type PlanRequest,
  type TasteBlock,
} from "./planPrompt.js";
import { loadConfig, modelApiKey, UpstreamError, type ScanConfig } from "./scan.js";
import { AVOIDANCES, AXES, COOK_TIMES, DISHES, type TastePole } from "./taxonomy.js";

/**
 * Generates a one-day eating plan for this user.
 *
 * **The targets are computed here, from the profile, and never taken from the
 * request.** They are `TargetCalculator`'s arithmetic, ported below, which is
 * where the deficit cap and the calorie floors are applied — so a client that
 * sent its own numbers could ask the model to plan a 600 kcal day, and the one
 * guard the app has against that would be bypassed by the feature that most
 * needs it. Nor are the *stored* targets trusted on their own: `users/{uid}`
 * is owner-writable, so `profile.targets` is whatever the client last wrote.
 * The client sends only what the taste quiz learned about the *food* — dish
 * ids, pole names, avoidance and cook-time keys — plus free text. Every id is
 * resolved against `taxonomy.ts` and anything it does not know is dropped
 * rather than rejected, so an older client that sends nothing but `notes`
 * still gets a plan.
 *
 * Costs roughly what a photo scan costs, so it is capped per day on the same
 * private counter pattern as the rewarded ads: the document lives under
 * `users/{uid}/private/**`, which has no rules match and is reachable only by
 * the service account.
 */

const RULES = {
  /** Plans a person may generate in a day. */
  maxPerDay: 3,
  /** Seconds between generations, so a double tap costs one call. */
  cooldownSeconds: 20,
  /** A plan is longer than a scan result and reasons about a whole day. */
  maxOutputTokens: 6000,
  /** Most dishes a request may name. The taxonomy holds twenty. */
  maxLiked: 20,
  /** Longest free text accepted — interpolated into the prompt, so a bill. */
  maxNotes: 400,
} as const;

const today = (): string => new Date().toISOString().slice(0, 10);

/**
 * The wire shape, as sent by `TasteProfile.toJson()`. Everything is `unknown`
 * because nothing here is trusted until `parseTaste` has looked at it.
 */
export interface GeneratePlanRequest {
  liked?: unknown;
  leaning?: unknown;
  avoid?: unknown;
  cookTime?: unknown;
  notes?: unknown;
}

/** `parseTaste`'s output: only keys the taxonomy knows, deduped and capped. */
export interface ParsedTaste {
  /** Dish ids, in the order sent, at most [RULES.maxLiked]. */
  liked: string[];
  /** Axis key → pole, in `AXES` order. */
  leaning: Record<string, TastePole>;
  /** Avoidance keys, in the order sent. */
  avoid: string[];
  /** A `COOK_TIMES` key. */
  cookTime?: string;
  notes: string;
}

interface PlanItem {
  name: string;
  calories: number;
  protein: number;
  carbs: number;
  fat: number;
}

interface PlanMeal {
  slot: string;
  title: string;
  items: PlanItem[];
}

export interface GeneratedPlan {
  name: string;
  description: string;
  goal: string;
  eat: string[];
  limit: string[];
  meals: PlanMeal[];
  /** True when the first attempt named an excluded food and a second was made. */
  retried: boolean;
  /**
   * What the day was written for — "Weight loss", "Building muscle" — as the
   * server read it off the profile's goal and motivation, or null when the
   * profile has no goal. The app shows it as the first "Built for you" chip.
   * Not the model's output: it is `purposeFor`'s label, so it is the same
   * string whatever the model did with the instruction.
   */
  purpose: string | null;
}

/** What the model returns: the plan without the fields this file adds. */
type ModelPlan = Omit<GeneratedPlan, "retried" | "purpose">;

/** One excluded food group a plan broke, and where. */
export interface Violation {
  /** The `AVOIDANCES` key. */
  key: string;
  label: string;
  /**
   * The scan words that fired, lowercase, each once — "tortilla" for
   * "Spiced egg and avocado tortillas". The retry names them, because the
   * most common way a compliant plan fails this check is a meal *title* that
   * drops a qualifier the items carry: "corn tortillas" in the list,
   * "tortillas" in the title.
   */
  words: string[];
  /**
   * The offending texts verbatim — an item name, a meal title, the plan's
   * name or description, an "eat" chip — each once, in the order the plan
   * lists them. Quoted back to the model on the retry, so it has something
   * concrete to change.
   */
  hits: string[];
}

interface ChatBody {
  choices?: {
    message?: { content?: string; refusal?: string | null };
    finish_reason?: string;
  }[];
  usage?: { prompt_tokens?: number; completion_tokens?: number; cost?: number };
}

/** One model call's outcome, before the post-check. */
interface Attempt {
  plan: ModelPlan;
  inputTokens: number;
  outputTokens: number;
  costUsd: number;
  /** Whether `costUsd` is the provider's own figure. */
  costReported: boolean;
}

/**
 * Validates the request against the taxonomy.
 *
 * Malformed and unknown values are **dropped, not rejected**. The client and
 * this file can drift — a dish added to one before the other, a renamed pole —
 * and the right outcome for a tap the server does not recognise is a plan
 * that ignores it, not an error screen. The only rejection is a body that is
 * not an object at all, which no version of the client ever sent.
 */
export function parseTaste(data: unknown): ParsedTaste {
  if (data === null || typeof data !== "object" || Array.isArray(data)) {
    throw new HttpsError("invalid-argument", "The plan request was not understood.");
  }
  const body = data as GeneratePlanRequest;

  const liked = uniqueStrings(body.liked)
    .filter((id) => Object.prototype.hasOwnProperty.call(DISHES, id))
    .slice(0, RULES.maxLiked);

  const leaning: Record<string, TastePole> = {};
  if (body.leaning !== null && typeof body.leaning === "object" && !Array.isArray(body.leaning)) {
    const sent = body.leaning as Record<string, unknown>;
    // Walked in `AXES` order rather than the request's, so the prompt renders
    // the poles in the order the quiz asked them whatever the client sent.
    for (const axis of Object.keys(AXES)) {
      const pole = sent[axis];
      if (typeof pole === "string" && (AXES[axis] as readonly string[]).includes(pole)) {
        leaning[axis] = pole as TastePole;
      }
    }
  }

  const avoid = uniqueStrings(body.avoid).filter((key) =>
    Object.prototype.hasOwnProperty.call(AVOIDANCES, key),
  );

  const cookTime =
    typeof body.cookTime === "string" &&
    Object.prototype.hasOwnProperty.call(COOK_TIMES, body.cookTime)
      ? body.cookTime
      : undefined;

  // Clamped for the same reason `scan.ts` clamps its description: this is
  // interpolated into a prompt, and an unbounded string is an unbounded bill.
  const notes = typeof body.notes === "string" ? body.notes.slice(0, RULES.maxNotes) : "";

  return { liked, leaning, avoid, cookTime, notes };
}

/** The strings in an array, in order, first occurrence only. Anything else is empty. */
function uniqueStrings(value: unknown): string[] {
  if (!Array.isArray(value)) return [];
  const seen = new Set<string>();
  const out: string[] = [];
  for (const entry of value) {
    if (typeof entry === "string" && !seen.has(entry)) {
      seen.add(entry);
      out.push(entry);
    }
  }
  return out;
}

// ---------------------------------------------------------------------------
// The post-check
// ---------------------------------------------------------------------------

/**
 * The compiled form of one `AVOIDANCES` entry.
 *
 * `words` is a word-**start** match — `\bcream\w*` catches "cream", "creamy"
 * and "creamed"; `\bcod\w*` catches "cod" and not "avocado". `except` blanks
 * every safe compound first, as a whole phrase and plural-tolerant, and a
 * qualifier ("gluten-free", "non-dairy") takes the word after it too.
 *
 * These are the semantics of `AvoidanceCheck` in
 * `lib/core/nutrition/avoidance_check.dart`, and `test/avoidance_check_test.dart`
 * holds the cases both must pass. Word-start rather than whole-word because
 * the misses were worse than the hits: "Creamy korma", "Buttered toast" and
 * "Cheeseburger" all passed a whole-word scan, and a false pass reaches an
 * allergic person. The false positives a prefix introduces ("eggplant",
 * "hamburger" under pork) are enumerated in `except`, where they can be read.
 */
interface Matcher {
  words: RegExp;
  except: RegExp | null;
}

const matchers = new Map<string, Matcher>();

function matcherFor(key: string): Matcher | undefined {
  const cached = matchers.get(key);
  if (cached) return cached;
  const avoidance = AVOIDANCES[key];
  if (!avoidance) return undefined;

  const matcher: Matcher = {
    words: new RegExp(`\\b(?:${avoidance.words.map(escapeRegExp).join("|")})\\w*`, "i"),
    except:
      avoidance.except.length === 0
        ? null
        : new RegExp(`\\b(?:${avoidance.except.map(exception).join("|")})`, "gi"),
  };
  matchers.set(key, matcher);
  return matcher;
}

/** One exception as a pattern: the phrase, a plural, and — for a qualifier — the word it qualifies. */
function exception(phrase: string): string {
  return escapeRegExp(phrase) + (isQualifier(phrase) ? "(?:[ -]+\\w+)?" : "(?:s|es)?") + "\\b";
}

/** Whether [text] names the avoidance at [key]. Unknown keys name nothing. */
export function mentions(text: string, key: string): boolean {
  const matcher = matcherFor(key);
  if (!matcher) return false;
  let t = text.toLowerCase();
  if (matcher.except) t = t.replace(matcher.except, " ");
  return matcher.words.test(t);
}

/**
 * The scan words of [key] that fire on [text], lowercase, each once — what
 * the retry names, so the model knows which word to qualify or drop.
 */
export function matchedWords(text: string, key: string): string[] {
  const matcher = matcherFor(key);
  const avoidance = AVOIDANCES[key];
  if (!matcher || !avoidance) return [];
  let t = text.toLowerCase();
  if (matcher.except) t = t.replace(matcher.except, " ");
  const out: string[] = [];
  for (const word of avoidance.words) {
    if (new RegExp(`\\b${escapeRegExp(word)}\\w*`, "i").test(t) && !out.includes(word)) {
      out.push(word);
    }
  }
  return out;
}

/** The loose shape `violations` scans — a parsed model response, trusted for nothing. */
interface PlanLike {
  name?: unknown;
  description?: unknown;
  goal?: unknown;
  eat?: unknown;
  meals?: unknown;
}

/**
 * The avoidances a plan breaks, each once, in `avoidKeys` order.
 *
 * Scans everything the detail screen renders: the plan's name and
 * description, every "eat" chip, every meal title and every item name. Not
 * `limit` — a "no dairy" plan listing "cheese" under what it keeps low is
 * correct, not a violation. This is the guarantee behind the prompt's MUST
 * NOT: a plan that names an excluded food anywhere the person can see it
 * never reaches them.
 */
export function violations(plan: PlanLike, avoidKeys: readonly string[]): Violation[] {
  const texts = planTexts(plan);
  const out: Violation[] = [];
  const seen = new Set<string>();
  for (const key of avoidKeys) {
    const avoidance = AVOIDANCES[key];
    if (!avoidance || seen.has(key)) continue;
    seen.add(key);
    const hits = texts.filter((text) => mentions(text, key));
    if (hits.length === 0) continue;
    const words = new Set<string>();
    for (const text of hits) for (const w of matchedWords(text, key)) words.add(w);
    out.push({ key, label: avoidance.label, hits, words: [...words] });
  }
  return out;
}

/** Every visible string in the plan, once each, in reading order. */
function planTexts(plan: PlanLike): string[] {
  const out: string[] = [];
  const seen = new Set<string>();
  const add = (value: unknown): void => {
    if (typeof value !== "string" || value.trim().length === 0 || seen.has(value)) return;
    seen.add(value);
    out.push(value);
  };

  add(plan.name);
  add(plan.description);
  // The goal card renders this too; "Lean muscle on steak" under "No beef"
  // is the same failure as a steak in the day.
  add(plan.goal);
  if (Array.isArray(plan.eat)) plan.eat.forEach(add);
  if (Array.isArray(plan.meals)) {
    for (const meal of plan.meals as { title?: unknown; items?: unknown }[]) {
      if (meal === null || typeof meal !== "object") continue;
      add(meal.title);
      if (Array.isArray(meal.items)) {
        for (const item of meal.items as { name?: unknown }[]) {
          if (item !== null && typeof item === "object") add(item.name);
        }
      }
    }
  }
  return out;
}

/**
 * What the retry is told, appended below the original prompt.
 *
 * A fresh single-turn call has no memory of the first attempt, so "your
 * previous attempt included dairy" gives it nothing to change. The hits are
 * quoted verbatim instead — `"Raita, 50 g" and "Creamy korma, 200 g", which
 * are dairy` — so the model can see what the scanner caught, including the
 * derived forms it might not think of as the excluded food.
 */
export function retryInstruction(found: readonly Violation[]): string {
  const total = found.reduce((n, v) => n + v.hits.length, 0);
  const clauses = found.map(
    (v) => `${joinWords(v.hits.map(quote))}, which ${v.hits.length === 1 ? "reads" : "read"} as ${v.label}`,
  );

  let text: string;
  if (found.length === 1) {
    text =
      `Your previous attempt included ${clauses[0]} and must not appear in any ` +
      `form or as an ingredient. Rewrite the day without ${total === 1 ? "it" : "them"}.`;
  } else {
    // Clauses carry commas of their own, so they are separated by semicolons.
    const list = `${clauses.slice(0, -1).join("; ")}; and ${clauses[clauses.length - 1]}`;
    text =
      `Your previous attempt included ${list}. None of these may appear in any ` +
      `form or as an ingredient. Rewrite the day without them.`;
  }

  // Say which word fired and how to write the substitute if that is what was
  // meant. Observed live: items said "Corn tortillas, 2", the title said
  // "avocado tortillas", the retry repeated the title, the plan was refused.
  for (const v of found) {
    for (const word of v.words) {
      const allowed = qualifiedFormsOf(v.key, word);
      const bare = quote(word);
      text +=
        allowed.length > 0
          ? ` The word ${bare} is what reads as ${v.label}: if you mean ${joinWords(allowed)}, ` +
            `write it that way in full everywhere it appears — the meal title as well as ` +
            `the items — and otherwise leave it out.`
          : ` The word ${bare} is what reads as ${v.label}; leave it out everywhere.`;
    }
  }
  return text;
}

/**
 * The `except` phrases that contain [word] — the ways the model is allowed
 * to write it: "corn tortilla" for "tortilla", "oat milk" and "almond milk"
 * for "milk". Qualifiers ("gluten-free") are skipped: they are a prefix, not
 * a spelling of the food.
 */
function qualifiedFormsOf(key: string, word: string): string[] {
  const entry = AVOIDANCES[key];
  if (!entry) return [];
  return entry.except
    .filter((phrase) => !isQualifier(phrase) && phrase.includes(word))
    .slice(0, 4);
}

function quote(text: string): string {
  return `"${text.replace(/"/g, "'")}"`;
}

function escapeRegExp(text: string): string {
  return text.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

// ---------------------------------------------------------------------------
// The profile
// ---------------------------------------------------------------------------

/**
 * `DietPreference.name` and `WeightGoal.name` as the client stores them, and
 * how the prompt says each. Anything else on the document is dropped: both
 * fields are owner-writable strings interpolated into the prompt, so an
 * unrecognised value is either drift or a 900 KB "goal" that is a 40× token
 * bill and an instruction sitting above the MUST NOT rule. `anything` is the
 * absence of a preference and renders nothing.
 */
const DIET_PREFERENCE: Readonly<Record<string, string>> = {
  vegetarian: "vegetarian",
  vegan: "vegan",
  keto: "keto",
  lowCarb: "low carb",
  mediterranean: "Mediterranean",
};

const GOAL_TEXT: Readonly<Record<string, string>> = {
  lose: "lose weight",
  maintain: "maintain weight",
  gain: "gain weight",
};

function lookup(table: Readonly<Record<string, string>>, value: unknown): string | undefined {
  return typeof value === "string" && Object.prototype.hasOwnProperty.call(table, value)
    ? table[value]
    : undefined;
}

/**
 * `WeightGoal.name` and `Motivation.name` as the client stores them. Read
 * the same way as the tables above — an owner-written string is either one
 * of these or nothing — but kept as the enum name rather than rendered,
 * because `purposeFor` wants the pair, not two sentences.
 */
const GOALS: readonly PlanGoal[] = ["lose", "maintain", "gain"];
const MOTIVATIONS: readonly PlanMotivation[] = ["lose", "muscle", "healthier", "understand"];

function member<T extends string>(names: readonly T[], value: unknown): T | undefined {
  return typeof value === "string" && (names as readonly string[]).includes(value)
    ? (value as T)
    : undefined;
}

/**
 * `TargetCalculator`, ported from `lib/core/nutrition/target_calculator.dart`.
 *
 * **This is the guard CLAUDE.md describes** — the 25% deficit cap and the
 * 1200/1500 kcal floors that the planner exists to respect — and it has to
 * run here, not only on the client, because `users/{uid}` is owner-writable:
 * `profile.targets` is whatever the client last wrote, and a plan built from
 * the stored figures would let a client ask for a 600 kcal day by editing a
 * document it owns. So the targets are recomputed from the profile's own
 * inputs whenever they are all present; the stored figures are used only when
 * they are not (a skipped quiz); and in either case the result is clamped
 * below, which bounds what any input — including an absurd height or weight,
 * which are owner-written too — can produce.
 *
 * Mirror the Dart exactly. Its unit tests are the spec; `Gender.other` and
 * `unspecified` take the midpoint of the two sex constants, the deficit is a
 * fraction of maintenance rather than a fixed number, and the floor is the
 * last thing applied to the calories.
 */
const TARGETS = {
  /** kcal in a kilogram of body mass. */
  kcalPerKg: 7700,
  /** The most a target may sit below maintenance, as a share of it. */
  maxDeficitFraction: 0.25,
  minCaloriesFemale: 1200,
  minCaloriesMale: 1500,
  /** Nothing the calculator can produce for a real person exceeds this. */
  maxCalories: 6000,
  /** Grams per kg of bodyweight. Carbohydrate takes what is left. */
  proteinPerKg: 1.8,
  fatPerKg: 0.9,
  /** `UserProfile.weeklyRateKg`'s default, when the document has none. */
  defaultWeeklyRateKg: 0.5,
} as const;

/** `ActivityLevel.name` → multiplier. The five Harris-Benedict factors. */
const ACTIVITY_MULTIPLIER: Readonly<Record<string, number>> = {
  sedentary: 1.2,
  light: 1.375,
  moderate: 1.55,
  very: 1.725,
  athlete: 1.9,
};

/** `Gender.name` → the Mifflin-St Jeor constant. Unknown sex takes the midpoint. */
const GENDER_CONSTANT: Readonly<Record<string, number>> = {
  male: 5,
  female: -161,
  other: -78,
  unspecified: -78,
};

interface Targets {
  calories: number;
  protein: number;
  carbs: number;
  fat: number;
  /** Which path produced them; logged, so a stored-target plan is visible as one. */
  source: "computed" | "stored";
}

/** The targets for [profile], or undefined when there is nothing to plan against. */
export function targetsFor(profile: Record<string, unknown>): Targets | undefined {
  const gender =
    typeof profile.gender === "string" &&
    Object.prototype.hasOwnProperty.call(GENDER_CONSTANT, profile.gender)
      ? profile.gender
      : "unspecified";
  const floor = gender === "male" ? TARGETS.minCaloriesMale : TARGETS.minCaloriesFemale;

  const raw = computeTargets(profile, gender, floor) ?? storedTargets(profile);
  if (!raw) return undefined;

  // The clamp applies to both paths. Calories: the floor for their sex, and a
  // ceiling no real profile reaches. Macros: never negative, and never more
  // than the calories can contain — protein and fat are set from bodyweight,
  // and bodyweight is a number the client wrote.
  const calories = clamp(raw.calories, floor, TARGETS.maxCalories);
  return {
    calories,
    protein: clamp(raw.protein, 0, calories / 4),
    carbs: clamp(raw.carbs, 0, calories / 4),
    fat: clamp(raw.fat, 0, calories / 9),
    source: raw.source,
  };
}

/** `TargetCalculator.forProfile`, when every input `canPersonaliseTargets` needs is present. */
function computeTargets(
  profile: Record<string, unknown>,
  gender: string,
  floor: number,
): Targets | undefined {
  const weightKg = finite(profile.weightKg);
  const heightCm = finite(profile.heightCm);
  const age = ageFrom(profile.dateOfBirth);
  // Own-property lookup, like every other owner-written key in this file:
  // `"constructor"` on a raw index returns a function, the multiplication
  // goes NaN, and clamp() passes NaN straight through to the prompt.
  const activity =
    typeof profile.activityLevel === "string" &&
    Object.prototype.hasOwnProperty.call(ACTIVITY_MULTIPLIER, profile.activityLevel)
      ? ACTIVITY_MULTIPLIER[profile.activityLevel]
      : undefined;
  const goal = profile.goal;
  if (
    weightKg === undefined ||
    heightCm === undefined ||
    age === undefined ||
    activity === undefined ||
    (goal !== "lose" && goal !== "maintain" && goal !== "gain")
  ) {
    return undefined;
  }
  const weeklyRateKg = finite(profile.weeklyRateKg) ?? TARGETS.defaultWeeklyRateKg;

  // Mifflin-St Jeor, then the activity multiplier.
  const bmr = 10 * weightKg + 6.25 * heightCm - 5 * age + GENDER_CONSTANT[gender];
  const tdee = bmr * activity;

  // A rate is kilograms per week; the daily calorie change is that mass in
  // energy, spread over seven days. The deficit is capped as a fraction of
  // maintenance; a surplus is not.
  const dailyChange = (Math.abs(weeklyRateKg) * TARGETS.kcalPerKg) / 7;
  let calories =
    goal === "lose"
      ? tdee - Math.min(dailyChange, tdee * TARGETS.maxDeficitFraction)
      : goal === "gain"
        ? tdee + dailyChange
        : tdee;
  calories = Math.max(calories, floor);

  // Protein and fat from bodyweight; carbohydrate takes the remaining energy.
  const protein = TARGETS.proteinPerKg * weightKg;
  const fat = TARGETS.fatPerKg * weightKg;
  const carbs = Math.max(0, (calories - protein * 4 - fat * 9) / 4);

  return {
    calories: Math.round(calories),
    protein: Math.round(protein),
    carbs: Math.round(carbs),
    fat: Math.round(fat),
    source: "computed",
  };
}

/** The targets the client wrote, for a profile that skipped the quiz. */
function storedTargets(profile: Record<string, unknown>): Targets | undefined {
  const stored = profile.targets;
  if (stored === null || typeof stored !== "object" || Array.isArray(stored)) return undefined;
  const t = stored as Record<string, unknown>;
  const calories = finite(t.calories);
  if (calories === undefined || calories <= 0) return undefined;
  return {
    calories,
    protein: finite(t.protein) ?? 0,
    carbs: finite(t.carbs) ?? 0,
    fat: finite(t.fat) ?? 0,
    source: "stored",
  };
}

/** `UserProfile.age`: whole years from the stored ISO date of birth. */
function ageFrom(value: unknown): number | undefined {
  const dob = value instanceof Date ? value : typeof value === "string" ? new Date(value) : null;
  if (dob === null || Number.isNaN(dob.getTime())) return undefined;
  const now = new Date();
  let years = now.getUTCFullYear() - dob.getUTCFullYear();
  const hadBirthday =
    now.getUTCMonth() > dob.getUTCMonth() ||
    (now.getUTCMonth() === dob.getUTCMonth() && now.getUTCDate() >= dob.getUTCDate());
  if (!hadBirthday) years--;
  return years;
}

function finite(value: unknown): number | undefined {
  return typeof value === "number" && Number.isFinite(value) ? value : undefined;
}

function clamp(value: number, min: number, max: number): number {
  return Math.min(Math.max(value, min), max);
}

/**
 * Resolves the parsed keys into the objects the prompt renders.
 *
 * Each avoidance's `except` list is filtered against the *other* chosen
 * avoidances with the matcher itself, so the prompt never offers "peanut
 * butter" as a dairy substitute to someone who also excluded nuts, or "tuna
 * steak" as a beef substitute to someone who excluded seafood.
 */
function tasteBlock(taste: ParsedTaste): TasteBlock | undefined {
  const liked = taste.liked.map((id) => DISHES[id]);
  const leaning = Object.values(taste.leaning);
  const avoid: AvoidanceEntry[] = taste.avoid.map((key) => {
    const entry = AVOIDANCES[key];
    const others = taste.avoid.filter((k) => k !== key);
    return {
      key,
      label: entry.label,
      words: entry.words,
      except: entry.except.filter((phrase) => !others.some((other) => mentions(phrase, other))),
    };
  });
  const cookTime = taste.cookTime ? COOK_TIMES[taste.cookTime] : undefined;

  if (liked.length === 0 && leaning.length === 0 && avoid.length === 0 && !cookTime) {
    return undefined;
  }
  return { liked, leaning, avoid, cookTime };
}

// ---------------------------------------------------------------------------
// The call
// ---------------------------------------------------------------------------

export async function generatePlan(
  env: Env,
  uid: string,
  data: GeneratePlanRequest,
): Promise<GeneratedPlan> {
  const db = new Firestore(env);
  const taste = parseTaste(data);

  const profile = await db.get(`users/${uid}`);
  if (!profile) {
    throw new HttpsError("failed-precondition", "Finish setting up your profile first.");
  }

  const targets = targetsFor(profile);
  if (!targets) {
    throw new HttpsError(
      "failed-precondition",
      "Answer a few questions about yourself first, so the plan has a target to hit.",
    );
  }

  // The purpose is the server's reading of the profile, like the targets:
  // the client sends nothing about it. `motivation` was stored by onboarding
  // and, until this, read by nothing on this side.
  const purpose = purposeFor(
    member(GOALS, profile.goal),
    member(MOTIVATIONS, profile.motivation),
  );

  const request: PlanRequest = {
    calories: targets.calories,
    protein: targets.protein,
    carbs: targets.carbs,
    fat: targets.fat,
    mealsPerDay: clampMeals(profile.mealsPerDay),
    dietPreference: lookup(DIET_PREFERENCE, profile.dietPreference),
    goal: lookup(GOAL_TEXT, profile.goal),
    purpose,
    taste: tasteBlock(taste),
    notes: taste.notes,
  };

  const config = await loadConfig(db);
  await assertUnderDailyCap(db, config.dailySpendCapUsd);
  await reserve(db, uid);

  const startedAt = Date.now();
  const prompt = planPrompt(request);

  // The one reservation above covers both attempts: the person asked for one
  // plan and gets charged one, however many calls it took to make a clean one.
  // Spend, on the other hand, is recorded per call inside `callModel`, because
  // the bill is per call — and the log record sums every attempt for the same
  // reason, so the cost it carries is what the plan actually cost.
  const attempts: Attempt[] = [];
  let latest: Attempt | undefined;
  let firstViolations: Violation[] = [];
  let broken: Violation[] = [];
  let retried = false;

  // Counts and enum names only — never the notes text, which is the one thing
  // in the request the person wrote in their own words. Client-side rules have
  // no match for this collection, so it falls through to the catch-all deny
  // and only the service account reads it; account deletion sweeps it along
  // with every other subcollection of the user document. Written on every
  // exit, including the failures — a plan that was refused, or a retry that
  // threw, burned a reservation and two calls' worth of tokens, and a log
  // that only records successes would show that as a cheap day.
  const writeLog = async (error: string | null): Promise<void> => {
    const logId = documentId();
    try {
      await db.set(`users/${uid}/planLogs/${logId}`, {
        id: logId,
        model: config.model,
        reasoningEffort: config.reasoningEffort,
        promptVersion: PLAN_PROMPT_VERSION,
        likedCount: taste.liked.length,
        leaning: taste.leaning,
        avoid: taste.avoid,
        cookTime: taste.cookTime ?? null,
        hasNotes: taste.notes.trim().length > 0,
        meals: latest ? mealCount(latest.plan) : 0,
        calories: latest ? totalCalories(latest.plan) : 0,
        target: Math.round(targets.calories),
        targetSource: targets.source,
        purpose: purpose?.label ?? null,
        retried,
        violations: firstViolations.map((v) => v.label),
        /** Non-empty only when the retry failed too, and the plan was refused. */
        violationsAfterRetry: broken.map((v) => v.label),
        attempts: attempts.length,
        inputTokens: attempts.reduce((n, a) => n + a.inputTokens, 0),
        outputTokens: attempts.reduce((n, a) => n + a.outputTokens, 0),
        costUsd: attempts.reduce((n, a) => n + a.costUsd, 0),
        costReported: attempts.length > 0 && attempts.every((a) => a.costReported),
        latencyMs: Date.now() - startedAt,
        error,
        createdAt: serverTimestamp(),
      });
    } catch (logError) {
      // A lost log line must not fail a plan the person has already paid a
      // generation for — there is no refund on this counter — and must not
      // replace the error that actually stopped one.
      console.error("plan log not written", uid, logError);
    }
  };

  try {
    latest = await callModel(env, db, config, uid, prompt);
    attempts.push(latest);
    broken = violations(latest.plan, taste.avoid);
    firstViolations = broken;

    if (broken.length > 0) {
      retried = true;
      console.warn("plan violated avoidances; retrying", uid, describe(broken));
      // Cleared before the second call: if it throws, the log must not
      // report the first attempt's violations as a second plan's. The retry
      // is told about `firstViolations`, which still holds them — passing
      // the cleared list here sent an instruction that named nothing.
      broken = [];
      latest = await callModel(
        env,
        db,
        config,
        uid,
        `${prompt}\n\n${retryInstruction(firstViolations)}`,
      );
      attempts.push(latest);
      broken = violations(latest.plan, taste.avoid);
    }

    if (broken.length > 0) {
      console.error("plan still violated avoidances after retry", uid, describe(broken));
      throw new HttpsError(
        "failed-precondition",
        `The plan kept including ${joinWords(broken.map((v) => v.label))}. ` +
          `Try again, or say so in the notes.`,
      );
    }
  } catch (error) {
    await writeLog(errorCode(error));
    // The reservation is not refunded for a failed *generation* — a plan that
    // came back wrong still burned its tokens. But a call that never reached
    // the model burned nothing, and three of those in a row used to lock
    // someone out for the rest of the day for an outage that was ours.
    if (attempts.length === 0) await release(db, uid);
    throw error;
  }

  const plan: GeneratedPlan = { ...latest.plan, retried, purpose: purpose?.label ?? null };
  await writeLog(null);

  const costReported = attempts.every((a) => a.costReported);
  console.log(
    "plan generated",
    JSON.stringify({
      uid,
      model: config.model,
      promptVersion: PLAN_PROMPT_VERSION,
      ms: Date.now() - startedAt,
      attempts: attempts.length,
      cost: costReported ? attempts.reduce((n, a) => n + a.costUsd, 0) : null,
      inputTokens: attempts.reduce((n, a) => n + a.inputTokens, 0),
      outputTokens: attempts.reduce((n, a) => n + a.outputTokens, 0),
      meals: mealCount(plan),
      calories: totalCalories(plan),
      target: Math.round(targets.calories),
      targetSource: targets.source,
      purpose: purpose?.label ?? null,
      likedCount: taste.liked.length,
      leaning: taste.leaning,
      avoid: taste.avoid,
      cookTime: taste.cookTime ?? null,
      retried,
    }),
  );

  return plan;
}

/**
 * One call to the model, parsed and paid for.
 *
 * Spend is recorded here rather than by the caller so that a retry cannot
 * forget it: both attempts burn tokens, and both must land on the daily fuse.
 */
async function callModel(
  env: Env,
  db: Firestore,
  config: ScanConfig,
  uid: string,
  prompt: string,
): Promise<Attempt> {
  const response = await fetch(`${config.baseUrl}/chat/completions`, {
    method: "POST",
    headers: {
      authorization: `Bearer ${modelApiKey(env)}`,
      "content-type": "application/json",
      "X-OpenRouter-Title": "Carbs AI",
    },
    body: JSON.stringify({
      model: config.model,
      messages: [
        { role: "system", content: PLAN_SYSTEM_PROMPT },
        { role: "user", content: prompt },
      ],
      reasoning: { effort: config.reasoningEffort },
      max_tokens: RULES.maxOutputTokens,
      response_format: {
        type: "json_schema",
        json_schema: { name: "diet_plan", strict: true, schema: PLAN_SCHEMA },
      },
      provider: { require_parameters: true },
    }),
  });

  if (!response.ok) {
    throw new UpstreamError(response.status, await response.text());
  }

  const body = (await response.json()) as ChatBody;
  const choice = body.choices?.[0];

  const inputTokens = body.usage?.prompt_tokens ?? 0;
  const outputTokens = body.usage?.completion_tokens ?? 0;
  const costReported = typeof body.usage?.cost === "number";
  const costUsd = costReported
    ? (body.usage?.cost as number)
    : (inputTokens / 1_000_000) * config.inputPricePerMTok +
      (outputTokens / 1_000_000) * config.outputPricePerMTok;

  // Recorded before the checks below: a refusal or a truncation was billed
  // just the same. Awaited, because an un-awaited promise can be cancelled
  // when the response is returned — and `recordSpend` swallows its own
  // errors, so awaiting it cannot fail a generation.
  await recordSpend(db, costUsd);

  if (choice?.message?.refusal) {
    console.warn("planner refused", uid, choice.message.refusal);
    throw new HttpsError(
      "invalid-argument",
      "That could not be turned into a plan. Try describing what you eat differently.",
    );
  }
  if (choice?.finish_reason === "length") {
    console.error("planner truncated", uid, RULES.maxOutputTokens);
    throw new HttpsError("resource-exhausted", "The plan came back incomplete. Try again.");
  }

  const raw = choice?.message?.content;
  if (!raw) throw new HttpsError("internal", "The planner returned nothing. Try again.");

  let plan: ModelPlan;
  try {
    plan = JSON.parse(raw) as ModelPlan;
  } catch {
    console.error("planner unparseable", uid, raw.slice(0, 400));
    throw new HttpsError("internal", "The plan came back malformed. Try again.");
  }

  return { plan, inputTokens, outputTokens, costUsd, costReported };
}

/** The short code a failure is logged under — never the message, which may quote model output. */
function errorCode(error: unknown): string {
  if (error instanceof HttpsError) return error.code;
  if (error instanceof UpstreamError) return `upstream-${error.status}`;
  return "internal";
}

/** `dairy: "Raita, 50 g", "Creamy korma, 200 g"; gluten: "Roti, 2"` — for the console. */
function describe(found: readonly Violation[]): string {
  return found.map((v) => `${v.label}: ${v.hits.map(quote).join(", ")}`).join("; ");
}

function joinWords(words: readonly string[]): string {
  if (words.length <= 1) return words.join("");
  return `${words.slice(0, -1).join(", ")} and ${words[words.length - 1]}`;
}

function mealCount(plan: { meals?: unknown }): number {
  return Array.isArray(plan.meals) ? plan.meals.length : 0;
}

function totalCalories(plan: { meals?: unknown }): number {
  if (!Array.isArray(plan.meals)) return 0;
  return Math.round(
    (plan.meals as { items?: { calories?: unknown }[] }[]).reduce(
      (sum, meal) =>
        sum +
        (Array.isArray(meal?.items)
          ? meal.items.reduce((s, i) => s + (finite(i?.calories) ?? 0), 0)
          : 0),
      0,
    ),
  );
}

function clampMeals(value: unknown): number {
  const n = Number(value);
  return Number.isFinite(n) && n >= 2 && n <= 6 ? Math.round(n) : 4;
}

/**
 * Counts this generation before the model call, not after.
 *
 * Same reasoning as the scan quota: checking afterwards would let a burst of
 * parallel calls all pass against the same stale count. Unlike a scan there is
 * nothing to refund — a failed generation still cost the tokens it burned.
 */
/**
 * Gives back a reservation that bought nothing.
 *
 * Only for a failure before the model answered: once tokens are spent the
 * person has had their generation, whatever came back. Best effort — losing a
 * refund must not mask the error the caller is waiting to hear about.
 */
async function release(db: Firestore, uid: string): Promise<void> {
  try {
    await db.set(`users/${uid}/private/planner`, { plansToday: increment(-1) });
  } catch (error) {
    console.warn("planner reservation not released", uid, error);
  }
}

async function reserve(db: Firestore, uid: string): Promise<void> {
  const day = today();
  const path = `users/${uid}/private/planner`;

  await db.transaction(async (tx) => {
    const data = await tx.get(path);
    const sameDay = data?.day === day;
    const used = sameDay ? ((data?.plansToday as number | undefined) ?? 0) : 0;

    if (used >= RULES.maxPerDay) {
      throw new HttpsError(
        "resource-exhausted",
        "That is all the plans for today. Come back tomorrow.",
      );
    }

    const lastAt = data?.lastAt instanceof Date ? data.lastAt.getTime() : 0;
    if ((Date.now() - lastAt) / 1000 < RULES.cooldownSeconds) {
      throw new HttpsError("resource-exhausted", "Give the last one a moment to finish.");
    }

    tx.set(path, { day, plansToday: used + 1, lastAt: serverTimestamp() });
  });
}
