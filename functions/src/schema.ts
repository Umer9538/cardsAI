/**
 * The response contract for a meal analysis.
 *
 * Two things about the shape are deliberate and load-bearing:
 *
 * 1. `observations` comes FIRST. Under strict mode the model emits fields in
 *    schema order, so a free-text field at the top is where it works out what
 *    it is looking at and what the scale references are *before* it commits to
 *    a number. That is chain-of-thought inside a structured output, and CoT is
 *    one of the few prompt-side interventions measured to improve accuracy on
 *    this task. Reordering this field is a silent accuracy regression.
 *
 * 2. Every quantity carries `minimum`/`maximum`. Strict mode enforces numeric
 *    bounds, so a decimal-place slip is rejected at generation rather than
 *    arriving and being clamped after the fact. `sanitize()` below still runs
 *    as defence in depth, and to catch the relationships a schema cannot
 *    express (fibre ≤ carbs).
 *
 * Strict mode also requires: every key in `properties` present in `required`,
 * `additionalProperties: false` on every object, and optionality expressed as a
 * nullable type rather than omission. Breaking any of those is a 400, not a
 * silent degradation — which is why `clarifying_question` is
 * `["string", "null"]` *and* required.
 */

/** Ceilings for one plausible portion of one food. Shared by schema and sanitizer. */
export const LIMITS = {
  calories: 4000,
  protein_g: 400,
  carbs_g: 800,
  fat_g: 400,
  fiber_g: 200,
  sugar_g: 800,
  portion_grams: 5000,
  /** A plate with more parts than this is being over-split. */
  maxItems: 20,
} as const;

export const MEAL_ANALYSIS_SCHEMA = {
  type: "object",
  additionalProperties: false,
  required: ["observations", "items", "overall_confidence", "clarifying_question"],
  properties: {
    observations: {
      type: "string",
      description:
        "Think here first, in 2-4 sentences, before filling anything else in. " +
        "What is on the plate? What in the frame gives you scale (plate rim, " +
        "fork, hand, can, mug)? Roughly how much food is there relative to " +
        "that reference? Note anything that makes this hard: poor light, a " +
        "steep angle, food hidden under other food, an unidentifiable sauce.",
    },
    items: {
      type: "array",
      maxItems: LIMITS.maxItems,
      description:
        "Every distinct food. An empty array means nothing edible could be " +
        "identified.",
      items: {
        type: "object",
        additionalProperties: false,
        required: [
          "name",
          "portion_desc",
          "portion_grams",
          "calories",
          "protein_g",
          "carbs_g",
          "fat_g",
          "fiber_g",
          "sugar_g",
          "confidence",
        ],
        properties: {
          name: {
            type: "string",
            description:
              "The food as a person would say it, e.g. 'Grilled Chicken " +
              "Strips'. Title case. No brand unless it is legible in frame.",
          },
          portion_desc: {
            type: "string",
            description:
              "Household measure, e.g. '1 cup', '2 slices', 'half a plate'.",
          },
          portion_grams: {
            type: "number",
            minimum: 0,
            maximum: LIMITS.portion_grams,
            description:
              "Edible weight of this portion in grams. Decide this BEFORE the " +
              "nutrients — every figure below follows from it.",
          },
          calories: {
            type: "number",
            minimum: 0,
            maximum: LIMITS.calories,
            description: "kcal for this portion, at this weight.",
          },
          protein_g: { type: "number", minimum: 0, maximum: LIMITS.protein_g },
          carbs_g: {
            type: "number",
            minimum: 0,
            maximum: LIMITS.carbs_g,
            description: "TOTAL carbohydrate, inclusive of fibre.",
          },
          fat_g: { type: "number", minimum: 0, maximum: LIMITS.fat_g },
          fiber_g: {
            type: "number",
            minimum: 0,
            maximum: LIMITS.fiber_g,
            description: "Subset of carbs_g. Never larger than it.",
          },
          sugar_g: {
            type: "number",
            minimum: 0,
            maximum: LIMITS.sugar_g,
            description: "Subset of carbs_g. Never larger than it.",
          },
          confidence: {
            type: "string",
            enum: ["high", "medium", "low"],
            description:
              "Covers BOTH the identification and the portion. Use 'low' " +
              "freely — a flagged guess is more useful than a confident wrong " +
              "number, and the person can fix a portion in one tap.",
          },
        },
      },
    },
    overall_confidence: {
      type: "string",
      enum: ["high", "medium", "low"],
      description: "Confidence in the analysis as a whole.",
    },
    clarifying_question: {
      type: ["string", "null"],
      description:
        "One short question that would most improve the estimate, or null " +
        "when the photo is clear enough. Ask about the food, never the person.",
    },
  },
} as const;

export interface AnalyzedItem {
  name: string;
  portion_desc: string;
  portion_grams: number;
  calories: number;
  protein_g: number;
  carbs_g: number;
  fat_g: number;
  fiber_g: number;
  sugar_g: number;
  confidence: "high" | "medium" | "low";
}

export interface MealAnalysis {
  observations: string;
  items: AnalyzedItem[];
  overall_confidence: "high" | "medium" | "low";
  clarifying_question: string | null;
}

/**
 * Defence in depth behind the schema's own bounds.
 *
 * The schema stops out-of-range numbers, but not the relationships between
 * them, and not a model that ignores its instructions on a bad day. Anything
 * corrected here also has its confidence dropped to `low`, so the UI flags it
 * rather than presenting a corrected-but-invented number as fact.
 */
export function sanitize(analysis: MealAnalysis): MealAnalysis {
  const items = analysis.items.map((item) => {
    let corrected = false;

    const bound = (value: number, max: number): number => {
      // NaN and Infinity fail every comparison, so test finiteness first
      // rather than relying on the clamp to catch them.
      if (!Number.isFinite(value) || value < 0) {
        corrected = true;
        return 0;
      }
      if (value > max) {
        corrected = true;
        return max;
      }
      return Math.round(value * 10) / 10;
    };

    const next: AnalyzedItem = {
      ...item,
      name: item.name.trim().slice(0, 120) || "Unknown",
      portion_desc: item.portion_desc.trim().slice(0, 80),
      portion_grams: bound(item.portion_grams, LIMITS.portion_grams),
      calories: bound(item.calories, LIMITS.calories),
      protein_g: bound(item.protein_g, LIMITS.protein_g),
      carbs_g: bound(item.carbs_g, LIMITS.carbs_g),
      fat_g: bound(item.fat_g, LIMITS.fat_g),
      fiber_g: bound(item.fiber_g, LIMITS.fiber_g),
      sugar_g: bound(item.sugar_g, LIMITS.sugar_g),
    };

    // Fibre and sugar are both components of total carbohydrate.
    if (next.fiber_g > next.carbs_g) {
      next.fiber_g = next.carbs_g;
      corrected = true;
    }
    if (next.sugar_g > next.carbs_g) {
      next.sugar_g = next.carbs_g;
      corrected = true;
    }

    // Sanity-check energy against the macros by the Atwater factors. A wide
    // tolerance on purpose: alcohol, sugar alcohols and rounding all move this
    // legitimately, so only a gross mismatch is worth flagging — and it is
    // flagged, never "fixed", because there is no way to tell which side is
    // wrong.
    const atwater =
      next.protein_g * 4 + next.carbs_g * 4 + next.fat_g * 9;
    if (atwater > 0 && next.calories > 0) {
      const ratio = next.calories / atwater;
      if (ratio < 0.5 || ratio > 2) corrected = true;
    }

    return corrected ? { ...next, confidence: "low" as const } : next;
  });

  const anyLow = items.some((item) => item.confidence === "low");

  return {
    observations: analysis.observations?.trim().slice(0, 1000) ?? "",
    items,
    overall_confidence:
      anyLow && analysis.overall_confidence === "high"
        ? "medium"
        : analysis.overall_confidence,
    clarifying_question: analysis.clarifying_question?.trim() || null,
  };
}
