import { HttpsError } from "./callable.js";
import type { Env } from "./env.js";
import { Firestore, serverTimestamp } from "./firestore.js";
import { PLAN_SCHEMA, PLAN_SYSTEM_PROMPT, planPrompt, type PlanRequest } from "./planPrompt.js";
import { loadConfig, modelApiKey, UpstreamError } from "./scan.js";

/**
 * Generates a one-day eating plan for this user.
 *
 * **The targets are read from Firestore, not taken from the request.** They are
 * the output of `TargetCalculator`, which applies the deficit cap and the
 * calorie floors — so a client that sent its own numbers could ask the model to
 * plan a 600 kcal day, and the one guard the app has against that would be
 * bypassed by the feature that most needs it. The client sends only free text.
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
} as const;

const today = (): string => new Date().toISOString().slice(0, 10);

export interface GeneratePlanRequest {
  notes?: string;
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
}

interface ChatBody {
  choices?: {
    message?: { content?: string; refusal?: string | null };
    finish_reason?: string;
  }[];
  usage?: { prompt_tokens?: number; completion_tokens?: number; cost?: number };
}

export async function generatePlan(
  env: Env,
  uid: string,
  data: GeneratePlanRequest,
): Promise<GeneratedPlan> {
  const db = new Firestore(env);

  const profile = await db.get(`users/${uid}`);
  if (!profile) {
    throw new HttpsError("failed-precondition", "Finish setting up your profile first.");
  }

  const targets = (profile.targets ?? {}) as Record<string, number>;
  const calories = Number(targets.calories ?? 0);
  if (!Number.isFinite(calories) || calories <= 0) {
    throw new HttpsError(
      "failed-precondition",
      "Answer a few questions about yourself first, so the plan has a target to hit.",
    );
  }

  const request: PlanRequest = {
    calories,
    protein: Number(targets.protein ?? 0),
    carbs: Number(targets.carbs ?? 0),
    fat: Number(targets.fat ?? 0),
    mealsPerDay: clampMeals(profile.mealsPerDay),
    dietPreference: asString(profile.dietPreference),
    goal: asString(profile.goal),
    // Clamped for the same reason `scan.ts` clamps its description: this is
    // interpolated into a prompt, and an unbounded string is an unbounded bill.
    notes: (data.notes ?? "").slice(0, 400),
  };

  await reserve(db, uid);

  const config = await loadConfig(db);
  const startedAt = Date.now();

  const response = await fetch(`${config.baseUrl}/chat/completions`, {
    method: "POST",
    headers: {
      authorization: `Bearer ${modelApiKey(env)}`,
      "content-type": "application/json",
      "X-OpenRouter-Title": "Carbsai",
    },
    body: JSON.stringify({
      model: config.model,
      messages: [
        { role: "system", content: PLAN_SYSTEM_PROMPT },
        { role: "user", content: planPrompt(request) },
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

  let plan: GeneratedPlan;
  try {
    plan = JSON.parse(raw) as GeneratedPlan;
  } catch {
    console.error("planner unparseable", uid, raw.slice(0, 400));
    throw new HttpsError("internal", "The plan came back malformed. Try again.");
  }

  console.log(
    "plan generated",
    JSON.stringify({
      uid,
      model: config.model,
      ms: Date.now() - startedAt,
      cost: body.usage?.cost ?? null,
      meals: plan.meals?.length ?? 0,
      calories: totalCalories(plan),
      target: Math.round(calories),
    }),
  );

  return plan;
}

function totalCalories(plan: GeneratedPlan): number {
  return Math.round(
    (plan.meals ?? []).reduce(
      (sum, meal) => sum + (meal.items ?? []).reduce((s, i) => s + (i.calories ?? 0), 0),
      0,
    ),
  );
}

function clampMeals(value: unknown): number {
  const n = Number(value);
  return Number.isFinite(n) && n >= 2 && n <= 6 ? Math.round(n) : 4;
}

function asString(value: unknown): string | undefined {
  return typeof value === "string" && value.length > 0 ? value : undefined;
}

/**
 * Counts this generation before the model call, not after.
 *
 * Same reasoning as the scan quota: checking afterwards would let a burst of
 * parallel calls all pass against the same stale count. Unlike a scan there is
 * nothing to refund — a failed generation still cost the tokens it burned.
 */
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
