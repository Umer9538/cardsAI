/**
 * The diet-plan generator's prompt and its strict output schema.
 *
 * Separate from `prompt.ts` because the two jobs pull in opposite directions.
 * The scan prompt is an *estimator*: it is told to push back on portion size
 * and to flag its own uncertainty. This one is a *planner*: it has an exact
 * calorie and macro target handed to it and its whole job is to hit it with
 * food a particular person will actually eat.
 *
 * What it must not do is give medical advice, and the system prompt says so
 * plainly. A calorie tracker that starts prescribing for conditions is a
 * different regulated product.
 *
 * Bump [PLAN_PROMPT_VERSION] on every edit to the wording below. It is written
 * onto each plan-log record, so a change in plan quality can be lined up
 * against the prompt that produced it.
 */

import type { Cuisine, Dish, TastePole } from "./taxonomy.js";
import { POLE_INSTRUCTION } from "./taxonomy.js";

/**
 * 1 — free text only.
 * 2 — the taste quiz: liked dishes, this-or-that poles, cook time and a hard
 *     avoidance rule that outranks the notes.
 * 3 — the avoidance rule names each excluded entry's own words and the
 *     substitutes the post-check permits; a pole instruction that would
 *     recommend an excluded food is replaced by a qualified one; diet
 *     preference and goal are rendered from the client's enum names rather
 *     than interpolated from the stored string.
 * 4 — a purpose block, derived from the profile's goal and motivation: what
 *     the day is *for* (muscle, fat loss, weight gain, eating better), with
 *     the food-level consequences spelled out, rather than a bare "Goal:
 *     lose weight" line.
 */
export const PLAN_PROMPT_VERSION = 4;

export const PLAN_SYSTEM_PROMPT = `
You write practical one-day eating plans for a calorie tracking app.

You are given a person's daily targets and preferences. Produce a plan that
hits those targets with real, ordinary food they can buy and cook.

Rules:
- The day's meals must add up to within 5% of the calorie target, and each
  macro within 15% of its target. This is the whole job; do not approximate.
- Use the person's stated cuisine and diet preference. If they said vegetarian,
  nothing contains meat or fish. If they named a cuisine, most meals belong to
  it — a plan that ignores this is useless to them.
- Portions must be written into the food name, with a unit: "Chicken breast,
  grilled, 150 g", "Roti, 2 medium", "Olive oil, 1 tbsp". A name without a
  portion is not a plan.
- Nutrition figures are per the stated portion, not per 100 g, and should match
  USDA FoodData Central reference values for that food.
- Ordinary food. No supplements, no meal-replacement shakes, nothing that has
  to be ordered specially.
- Never give medical or clinical advice, never mention treating or managing a
  disease, and never suggest a calorie target of your own — the target you are
  given already has safety floors applied.
- Write in plain British English. No emoji, no exclamation marks, no coaching
  voice.
`.trim();

/**
 * One excluded food group, as the prompt names it and the post-check scans
 * for it. `words` and `except` are the `AVOIDANCES` lists; the prompt quotes
 * the first few of each so the model is told, in the scanner's own
 * vocabulary, what counts and what is allowed.
 */
export interface AvoidanceEntry {
  /** The `AVOIDANCES` key — what the pole overrides are keyed on. */
  readonly key: string;
  readonly label: string;
  readonly words: readonly string[];
  /**
   * The safe compounds the post-check permits. `planner.ts` has already
   * removed any that another chosen avoidance would flag, so "peanut butter"
   * is not offered as a dairy substitute to someone who also excluded nuts.
   */
  readonly except: readonly string[];
}

/** The cook-time ceiling. `maxMinutes` of zero means the meals are bought, not cooked. */
export interface CookTimeEntry {
  readonly label: string;
  readonly maxMinutes: number;
}

/**
 * What the quiz learned about the food, already resolved against the taxonomy.
 *
 * Everything here is a *resolved* object rather than an id, so the prompt
 * renderer cannot be handed a value the taxonomy does not know. `planner.ts`
 * does the resolving and drops anything it cannot resolve.
 */
export interface TasteBlock {
  /** Dishes tapped on the two grids. */
  readonly liked: readonly Dish[];
  /** One pole per answered this-or-that axis, in axis order. */
  readonly leaning: readonly TastePole[];
  /** Hard exclusions. Rendered above the notes and outranking them. */
  readonly avoid: readonly AvoidanceEntry[];
  readonly cookTime?: CookTimeEntry;
}

/** `WeightGoal.name` as the client stores it — the direction the target moves. */
export type PlanGoal = "lose" | "maintain" | "gain";

/** `Motivation.name` as the client stores it — what brought them to the app. */
export type PlanMotivation = "lose" | "muscle" | "healthier" | "understand";

/**
 * What the plan is for, derived from the profile — never sent by the client.
 *
 * `label` is the short form the app shows as the first "Built for you" chip
 * and writes to the plan log; `instruction` is the paragraph the prompt
 * renders. `key` is stable across wording changes, for anyone reading logs.
 */
export interface Purpose {
  readonly key: "muscle" | "loss" | "gain" | "eatBetter" | "maintenance";
  readonly label: string;
  readonly instruction: string;
}

const PURPOSES: Readonly<Record<Purpose["key"], Purpose>> = {
  muscle: {
    key: "muscle",
    label: "Building muscle",
    instruction:
      "Purpose: building muscle. Protein at or above target and spread across " +
      "every meal, 25–45 g each, never front-loaded into one; one meal is the " +
      "post-training meal — larger, carb-and-protein led — and its title says " +
      "so; calorie-dense whole foods; no meal under 300 kcal unless it is a snack.",
  },
  loss: {
    key: "loss",
    label: "Weight loss",
    instruction:
      "Purpose: fat loss at a deficit. High-volume, high-fibre, high-protein " +
      "meals that keep them full — vegetables, pulses, lean protein; protein at " +
      "or above target; no liquid calories; nothing that reads as a diet-food " +
      "punishment.",
  },
  gain: {
    key: "gain",
    label: "Weight gain",
    instruction:
      "Purpose: healthy weight gain. Calorie-dense whole foods — nuts and seeds, " +
      "oils, full portions of starch — and larger portions rather than more " +
      "meals; protein at target.",
  },
  eatBetter: {
    key: "eatBetter",
    label: "Eating better",
    instruction:
      "Purpose: eating better at maintenance. Variety across the day, vegetables " +
      "in most meals, minimal ultra-processed food, nothing extreme.",
  },
  maintenance: {
    key: "maintenance",
    label: "Maintenance",
    instruction: "Purpose: a balanced day at maintenance.",
  },
};

/**
 * The purpose for a (goal, motivation) pair. Mirrors `PlanPurpose.from` in
 * `lib/core/nutrition/plan_purpose.dart`, which the local planner and the
 * quiz's build step use; the two must agree or the chip the person watches
 * being sent is not the one the plan comes back with.
 *
 * Muscle wins whatever the goal: someone cutting while training still needs
 * the protein spread and the post-training meal, and someone gaining for the
 * gym needs them more than they need nuts. No goal means no purpose — the
 * target is then the default, not a deficit or a surplus, and a plan that
 * claimed "weight loss" over it would be claiming something the numbers do
 * not do.
 */
export function purposeFor(goal?: PlanGoal, motivation?: PlanMotivation): Purpose | undefined {
  if (motivation === "muscle") return PURPOSES.muscle;
  switch (goal) {
    case "lose":
      return PURPOSES.loss;
    case "gain":
      return PURPOSES.gain;
    case "maintain":
      return motivation === "healthier" || motivation === "understand"
        ? PURPOSES.eatBetter
        : PURPOSES.maintenance;
    default:
      return undefined;
  }
}

export interface PlanRequest {
  calories: number;
  protein: number;
  carbs: number;
  fat: number;
  mealsPerDay: number;
  /**
   * Already rendered from the client's enum name by `planner.ts` — "low
   * carb", not `lowCarb`, and never the stored string itself. Absent means no
   * preference.
   */
  dietPreference?: string;
  /** Likewise: "lose weight", from `WeightGoal.lose`. */
  goal?: string;
  /** What the day is for — `purposeFor` over the profile's goal and motivation. */
  purpose?: Purpose;
  /** The quiz's answers. Absent for the legacy text-only builder. */
  taste?: TasteBlock;
  /** Free text from the user: cuisine, allergies, dislikes, budget. */
  notes?: string;
}

export function planPrompt(request: PlanRequest): string {
  const lines = [
    `Daily targets: ${Math.round(request.calories)} kcal, ` +
      `${Math.round(request.protein)} g protein, ` +
      `${Math.round(request.carbs)} g carbohydrate, ` +
      `${Math.round(request.fat)} g fat.`,
    `Meals per day: ${request.mealsPerDay}.`,
  ];

  if (request.dietPreference) lines.push(`Diet preference: ${request.dietPreference}.`);
  if (request.goal) lines.push(`Goal: ${request.goal}.`);

  // Directly under the targets and above everything the quiz learned: the
  // purpose is what the numbers are *for*, and a taste line read first would
  // have the model building a menu before it knew whether the day is a cut
  // or a bulk. Its own paragraph, so "Purpose:" is not lost among one-liners.
  if (request.purpose) lines.push("", request.purpose.instruction);

  const taste = request.taste;
  const hasAvoidances = (taste?.avoid.length ?? 0) > 0;

  if (taste) {
    lines.push(...likedLines(taste));
    lines.push(...leaningLines(taste));
    lines.push(...cookTimeLines(taste));
    lines.push(...avoidanceLines(taste));
  }

  if (request.notes?.trim()) {
    // The strongest *soft* signal in the prompt: it is the only part the
    // person typed themselves. It sits below the MUST NOT rule on purpose —
    // a note saying "I love cheese" must not reopen a dairy exclusion, and the
    // post-check in `planner.ts` would reject the plan anyway.
    const outranked = hasAvoidances
      ? "the calorie and macro targets and the MUST NOT rule"
      : "the calorie and macro targets";
    lines.push(
      "",
      `The person adds, and this takes priority over everything above except ` +
        `${outranked}: ${request.notes.trim()}`,
    );
  }

  return lines.join("\n");
}

/**
 * (a) The dishes they tapped, then the cuisines that dominate them.
 *
 * The dishes are examples of taste, not a menu — said explicitly, because the
 * obvious failure is a day that schedules the nine tiles back to back and
 * ignores the targets. The cuisine line mirrors `TasteProfile.cuisines` on the
 * client (count descending, top two), so the "Built for" chips the person sees
 * name the same cuisines the model was told to build in.
 */
function likedLines(taste: TasteBlock): string[] {
  if (taste.liked.length === 0) return [];
  const out = ["", "What looks good to them:"];
  for (const dish of taste.liked) {
    out.push(`- ${dish.name} (${dish.cuisine}; ${dish.tags.join(", ")})`);
  }
  const top = topCuisines(taste.liked, 2);
  out.push(
    `Build the day mostly in ${joinWords(top)} cooking, in the styles those dishes share. ` +
      `They are examples of this person's taste, not a menu to copy: do not simply ` +
      `schedule them one after another.`,
  );
  return out;
}

/** (b) One instruction per answered axis, in axis order. */
function leaningLines(taste: TasteBlock): string[] {
  if (taste.leaning.length === 0) return [];
  const avoidKeys = taste.avoid.map((a) => a.key);
  return ["", ...taste.leaning.map((pole) => poleInstruction(pole, avoidKeys))];
}

/**
 * The poles whose stock `POLE_INSTRUCTION` names a food an avoidance excludes,
 * and which avoidances clash with each. The `bread` line says "roti, wraps,
 * toast and flatbreads"; two lines under it, "MUST NOT contain gluten". The
 * model is then asked to satisfy both, and whichever it picks, the person
 * either gets a plan that ignores their starch preference or one the
 * post-check refuses. `assembled` names wraps too; `plants` names eggs; `meat`
 * names fish, and "meat" generically when beef is what they excluded. `rice`
 * only *mentions* bread ("rice over bread") — harmless in meaning, but the
 * rule is simpler if no pole line names an excluded food at all.
 *
 * Order matters: the override key is the pole followed by the clashing keys
 * in *this* order, so every subset of a pole's list must have an entry in
 * `POLE_OVERRIDES` below.
 */
const POLE_CONFLICTS: Readonly<Partial<Record<TastePole, readonly string[]>>> = {
  rice: ["gluten"],
  bread: ["gluten"],
  assembled: ["gluten"],
  plants: ["eggs"],
  meat: ["beef", "pork", "seafood"],
};

/**
 * The qualified instruction for each (pole, clashing avoidances) combination.
 *
 * Every food named here must pass the post-check for the avoidances in its
 * key: "gluten-free flatbreads" is blanked by the qualifier rule, "corn
 * tortillas", "rice noodles" and "lettuce wraps" are `except` phrases. Not
 * "rice-noodle wraps" — the exception is "rice noodle" with a space, and
 * "wraps" on its own is a hit — so this names the exact spellings the scanner
 * permits, which is also what steers the model into using them.
 */
const POLE_OVERRIDES: Readonly<Record<string, string>> = {
  "rice|gluten": "Rice is their starch of choice: prefer rice, grains and bowls, which suits the gluten exclusion.",
  "bread|gluten":
    "They would rather not build every meal on rice, but gluten is excluded: prefer potatoes, quinoa, buckwheat, gluten-free flatbreads and corn tortillas as the starch — and write those last two in full every time, in meal titles too.",
  "assembled|gluten":
    "They rarely cook. Favour meals that are assembled rather than cooked — bowls, salads, lettuce wraps, things from a tin or a packet.",
  "plants|eggs":
    "Plant-forward: pulses, tofu and vegetables should anchor most main meals, with meat occasional at most.",
  "meat|beef": "Meat-forward: chicken, fish or lamb should anchor most main meals.",
  "meat|pork": "Meat-forward: chicken, fish or beef should anchor most main meals.",
  "meat|seafood": "Meat-forward: chicken, lamb or beef should anchor most main meals.",
  "meat|beef|pork": "Meat-forward: chicken, fish or lamb should anchor most main meals.",
  "meat|beef|seafood": "Meat-forward: chicken or lamb should anchor most main meals.",
  "meat|pork|seafood": "Meat-forward: chicken, beef or lamb should anchor most main meals.",
  "meat|beef|pork|seafood": "Meat-forward: chicken or lamb should anchor most main meals.",
};

/** The line for [pole], qualified when one of [avoidKeys] clashes with it. */
export function poleInstruction(pole: TastePole, avoidKeys: readonly string[]): string {
  const clashes = (POLE_CONFLICTS[pole] ?? []).filter((key) => avoidKeys.includes(key));
  if (clashes.length === 0) return POLE_INSTRUCTION[pole];
  const override = POLE_OVERRIDES[[pole, ...clashes].join("|")];
  if (override === undefined) {
    // Every subset is meant to be in the table. Rendering the stock line here
    // would reintroduce the clash silently, so say so where `wrangler tail`
    // can see it, and fall back to the least specific override that exists.
    console.error("no pole override", pole, clashes.join(","));
    return POLE_OVERRIDES[`${pole}|${clashes[0]}`] ?? POLE_INSTRUCTION[pole];
  }
  return override;
}

/**
 * (c) The cook-time ceiling, and an honest word about any liked dish that
 * breaks it — the quiz let a fifteen-minute person tap biryani, and the plan
 * should carry its flavours rather than its hour.
 */
function cookTimeLines(taste: TasteBlock): string[] {
  const cookTime = taste.cookTime;
  if (!cookTime) return [];

  if (cookTime.maxMinutes <= 0) {
    return [
      "",
      "Assume meals are bought, not cooked: choose things available at cafés, " +
        "restaurants and takeaways, and name a typical portion as it is sold.",
    ];
  }

  const out = [
    "",
    `Every meal must be preparable in under ${cookTime.maxMinutes} minutes, including preparation.`,
  ];
  for (const dish of taste.liked) {
    if (dish.minutes > cookTime.maxMinutes) {
      out.push(
        `They liked ${dish.name}, which takes ${dish.minutes} minutes — use its ` +
          `flavours in something faster.`,
      );
    }
  }
  return out;
}

/**
 * (d) The hard rule. Rendered above the notes and said to outrank them.
 *
 * The model mostly listens; `violations()` in `planner.ts` is what makes it a
 * guarantee. The rest of the paragraph is built from the chosen entries
 * themselves — the words the post-check scans for, and the substitutes it
 * permits — because a plan that fails the check costs a second model call,
 * and a fixed reminder about paneer and burgers said nothing useful to
 * someone who excluded gluten. Naming the substitutes matters as much as
 * naming the words: told only "no dairy", the model reaches for "milk
 * alternative" or drops the porridge; told "oat milk is fine", it writes the
 * thing the scanner already knows is safe.
 */
function avoidanceLines(taste: TasteBlock): string[] {
  if (taste.avoid.length === 0) return [];
  const labels = taste.avoid.map((a) => a.label).join(", ");
  const includes = taste.avoid
    .map((a) => `${a.label} includes ${joinWords(distinct(a.words, 8))}`)
    .join("; ");

  let paragraph =
    `MUST NOT contain, in any form or as an ingredient: ${labels}. ` +
    `This rule outranks everything else in this message, including anything ` +
    `the person adds below. Check every ingredient of every item against it — ` +
    `${includes}. Do not name any of these foods anywhere in the plan — not in ` +
    `the name, the description, the goal or the eat list, and not even to say ` +
    `they are left out; the plan is checked for the words themselves. Write any ` +
    `substitute by its full qualified name every time it appears, in meal titles ` +
    `as well as items: "corn tortillas", "oat milk", "gluten-free flatbread" — a ` +
    `bare "tortillas" or "milk" is read as the excluded food.`;

  for (const entry of taste.avoid) {
    const allowed = substitutes(entry, 6);
    if (allowed.length === 0) continue;
    const list = joinWords(allowed);
    paragraph +=
      ` ${list[0].toUpperCase()}${list.slice(1)} ${allowed.length === 1 ? "is" : "are"} fine.`;
  }

  return ["", paragraph];
}

/**
 * The first [take] of [phrases], skipping spelling variants of one already
 * taken — the lists carry "yoghurt" and "yogurt", "omelette" and "omelet",
 * "soy milk" and "soya milk" so the scanner catches both, and reading both
 * back to the model is noise.
 */
function distinct(phrases: readonly string[], take: number): string[] {
  const out: string[] = [];
  for (const phrase of phrases) {
    if (out.length >= take) break;
    if (!out.some((taken) => isVariant(taken, phrase))) out.push(phrase);
  }
  return out;
}

/** Same number of words, each sharing its first three letters with its twin. */
function isVariant(a: string, b: string): boolean {
  const x = a.split(" ");
  const y = b.split(" ");
  return x.length === y.length && x.every((word, i) => word.slice(0, 3) === y[i].slice(0, 3));
}

/**
 * The substitutes worth telling the model about, at most [take].
 *
 * Multi-word phrases only: a single-word exception is a derived form
 * ("toasted", "eggless") or a compound ("butternut") that is an exception to
 * the scan rather than a food to recommend, and a qualifier ("dairy-free")
 * permits whatever follows it rather than naming anything. What is left is
 * grouped by the word it stands in for and taken round-robin, so the dairy
 * list spans milk, butter, cream, yoghurt and curd rather than being six
 * kinds of milk.
 */
function substitutes(entry: AvoidanceEntry, take: number): string[] {
  const groups = new Map<string, string[]>();
  for (const phrase of entry.except) {
    if (isQualifier(phrase) || !phrase.includes(" ")) continue;
    const word = entry.words.find((w) => phrase.includes(w));
    if (word === undefined) continue;
    const group = groups.get(word) ?? [];
    group.push(phrase);
    groups.set(word, group);
  }

  const lists = [...groups.values()];
  const out: string[] = [];
  for (let round = 0; out.length < take && lists.some((l) => round < l.length); round++) {
    for (const list of lists) {
      if (out.length >= take) break;
      const phrase = list[round];
      if (phrase !== undefined && !out.some((taken) => isVariant(taken, phrase))) {
        out.push(phrase);
      }
    }
  }
  return out;
}

/**
 * Whether an `except` phrase is a qualifier — one that permits the word after
 * it ("gluten-free bread", "non-dairy milk") rather than being a safe
 * compound itself. The same test as `AvoidanceCheck.isQualifier` on the
 * client; `planner.ts` builds its matcher on it.
 */
export function isQualifier(phrase: string): boolean {
  return phrase.endsWith("free") || phrase.startsWith("non-");
}

/** Cuisines by how many liked dishes belong to them, most first. */
export function topCuisines(liked: readonly Dish[], take: number): Cuisine[] {
  const counts = new Map<Cuisine, number>();
  for (const dish of liked) {
    counts.set(dish.cuisine, (counts.get(dish.cuisine) ?? 0) + 1);
  }
  return [...counts.entries()]
    .sort((a, b) => b[1] - a[1])
    .slice(0, take)
    .map(([cuisine]) => cuisine);
}

function joinWords(words: readonly string[]): string {
  if (words.length <= 1) return words.join("");
  return `${words.slice(0, -1).join(", ")} and ${words[words.length - 1]}`;
}

/**
 * Strict `json_schema`, under the same three rules `schema.ts` documents: every
 * key in `properties` is also in `required`, `additionalProperties` is false
 * everywhere, and optionality is a nullable type rather than an omission.
 */
export const PLAN_SCHEMA = {
  type: "object",
  additionalProperties: false,
  required: ["name", "description", "goal", "eat", "limit", "meals"],
  properties: {
    name: {
      type: "string",
      description: "Short plan name, two or three words. Not the person's name.",
    },
    description: {
      type: "string",
      description: "One sentence on what the plan is.",
    },
    goal: {
      type: "string",
      description: "What following it is for, in five words or fewer.",
    },
    eat: {
      type: "array",
      minItems: 3,
      maxItems: 8,
      items: { type: "string" },
      description: "Foods the plan is built on. One or two words each.",
    },
    limit: {
      type: "array",
      minItems: 2,
      maxItems: 6,
      items: { type: "string" },
      description: "What it keeps low. One or two words each.",
    },
    meals: {
      type: "array",
      minItems: 2,
      maxItems: 6,
      items: {
        type: "object",
        additionalProperties: false,
        required: ["slot", "title", "items"],
        properties: {
          slot: {
            type: "string",
            enum: ["breakfast", "lunch", "dinner", "snack"],
          },
          title: { type: "string" },
          items: {
            type: "array",
            minItems: 1,
            maxItems: 6,
            items: {
              type: "object",
              additionalProperties: false,
              required: ["name", "calories", "protein", "carbs", "fat"],
              properties: {
                name: {
                  type: "string",
                  description: "Food with its portion, e.g. 'Roti, 2 medium'.",
                },
                calories: { type: "number", minimum: 0, maximum: 2000 },
                protein: { type: "number", minimum: 0, maximum: 200 },
                carbs: { type: "number", minimum: 0, maximum: 400 },
                fat: { type: "number", minimum: 0, maximum: 200 },
              },
            },
          },
        },
      },
    },
  },
} as const;
