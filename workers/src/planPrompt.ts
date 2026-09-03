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
 */

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

export interface PlanRequest {
  calories: number;
  protein: number;
  carbs: number;
  fat: number;
  mealsPerDay: number;
  dietPreference?: string;
  goal?: string;
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

  if (request.dietPreference && request.dietPreference !== "none") {
    lines.push(`Diet preference: ${request.dietPreference}.`);
  }
  if (request.goal) lines.push(`Goal: ${request.goal}.`);
  if (request.notes?.trim()) {
    // Treated as the strongest signal in the prompt: it is the only part the
    // person typed themselves, and it is where allergies arrive.
    lines.push(
      `The person adds, and this takes priority over everything above except ` +
        `the calorie and macro targets: ${request.notes.trim()}`,
    );
  }

  return lines.join("\n");
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
