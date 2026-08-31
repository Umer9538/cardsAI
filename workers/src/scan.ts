import { HttpsError } from "./callable.js";
import type { Env } from "./env.js";
import { Firestore, documentId, increment, serverTimestamp } from "./firestore.js";
import { PROMPT_VERSION, SYSTEM_PROMPT, describePrompt, photoPrompt } from "./prompt.js";
import { MEAL_ANALYSIS_SCHEMA, sanitize, type MealAnalysis } from "./schema.js";
import { isPremium } from "./subscription.js";

/**
 * Meal analysis — the port of `analyzeMeal`.
 *
 * The OpenAI key lives in this Worker and only here. That was always the
 * reason the server leg existed; the only thing that changed is which server.
 *
 * The `openai` npm package is not used: the call is one POST, and going
 * through `fetch` keeps the bundle small and the wire format visible. It does
 * mean `output_text` has to be assembled by hand — that convenience property
 * is synthesised by the SDK, not returned by the API.
 */

const OPENAI_URL = "https://api.openai.com/v1/responses";

const DEFAULTS = {
  /**
   * `gpt-5.6-luna` — vision, structured outputs, and the cheapest of the 5.6
   * family at $0.20/$1.20 per MTok. Published evaluations put ~99.6% of
   * accuracy variance on model choice rather than prompt wording, so this is
   * the field to change first if results disappoint. `gpt-5.6-terra`
   * ($2/$12) is the accuracy upgrade.
   */
  model: "gpt-5.6-luna",
  /** Reasoning models. Low keeps the 10-second target reachable. */
  reasoningEffort: "low",
  /** Covers reasoning tokens as well as the visible answer — both are billed. */
  maxOutputTokens: 4000,
  inputPricePerMTok: 0.2,
  outputPricePerMTok: 1.2,
  monthlyQuota: 100,
  /** Free scans in total, ever — the bucket never resets. */
  freeScanLimit: 3,
  /** Portion estimation depends on the texture downsampling destroys. */
  imageDetail: "high",
};

type ScanConfig = typeof DEFAULTS;

/**
 * Reads `config/scan`, falling back per-field to [DEFAULTS].
 *
 * The model must be switchable without an app release; this is that seam. A
 * missing document, or a missing field within it, is normal.
 */
async function loadConfig(db: Firestore): Promise<ScanConfig> {
  try {
    const doc = await db.get("config/scan");
    return { ...DEFAULTS, ...(doc ?? {}) } as ScanConfig;
  } catch (error) {
    console.warn("config/scan unreadable; using defaults", error);
    return DEFAULTS;
  }
}

/** YYYY-MM, the premium quota bucket. */
function currentPeriod(): string {
  return new Date().toISOString().slice(0, 7);
}

interface Bucket {
  id: string;
  limit: number;
  premium: boolean;
}

async function quotaBucket(db: Firestore, uid: string, config: ScanConfig): Promise<Bucket> {
  return (await isPremium(db, uid))
    ? { id: currentPeriod(), limit: config.monthlyQuota, premium: true }
    : { id: "free", limit: config.freeScanLimit, premium: false };
}

/**
 * Counts a scan against the allowance, transactionally.
 *
 * Reserved BEFORE the model call, not after: ten scans fired at once would
 * otherwise all read the same stale count, all pass, and all be paid for. The
 * reservation is refunded when the call fails, so a timeout costs nobody a scan.
 */
async function reserveQuota(db: Firestore, uid: string, bucket: Bucket): Promise<void> {
  const path = `users/${uid}/quota/${bucket.id}`;

  await db.transaction(async (tx) => {
    const doc = await tx.get(path);
    const used = (doc?.used as number | undefined) ?? 0;
    const bonus = (doc?.bonus as number | undefined) ?? 0;
    const limit = bucket.limit + bonus;

    if (used >= limit) {
      throw new HttpsError(
        "resource-exhausted",
        bucket.premium
          ? `You have used all ${limit} scans this month. Describe and search still work.`
          : `You have used your ${limit} free scans. Upgrade for more.`,
      );
    }
    tx.set(path, { used: increment(1), updatedAt: serverTimestamp() });
  });
}

async function releaseQuota(db: Firestore, uid: string, bucketId: string): Promise<void> {
  try {
    await db.set(`users/${uid}/quota/${bucketId}`, { used: increment(-1) });
  } catch (error) {
    // Losing a refund is better than masking the original failure, which is
    // what the caller is actually waiting to hear about.
    console.warn("quota refund failed", uid, error);
  }
}

export interface ScanRequest {
  /** Base64 JPEG, no `data:` prefix. Absent on the text-only path. */
  imageBase64?: string;
  mimeType?: string;
  /** The one-line note the capture screen offers. */
  hint?: string;
  /** Free-text meal description, for the "describe it" fallback. */
  description?: string;
}

interface ResponsesBody {
  status?: string;
  incomplete_details?: { reason?: string };
  output_text?: string;
  output?: Array<{
    type: string;
    content?: Array<{ type: string; text?: string; refusal?: string }>;
  }>;
  usage?: {
    input_tokens?: number;
    output_tokens?: number;
    output_tokens_details?: { reasoning_tokens?: number };
  };
}

/** The SDK's `output_text`, assembled from the raw output items. */
function outputText(body: ResponsesBody): string {
  if (body.output_text) return body.output_text;
  let text = "";
  for (const item of body.output ?? []) {
    if (item.type !== "message") continue;
    for (const part of item.content ?? []) {
      if (part.type === "output_text" && part.text) text += part.text;
    }
  }
  return text;
}

/** A refusal arrives as its own content part, not as schema-shaped output. */
function refusalOf(body: ResponsesBody): string | null {
  for (const item of body.output ?? []) {
    if (item.type !== "message") continue;
    for (const part of item.content ?? []) {
      if (part.type === "refusal") return part.refusal ?? "refused";
    }
  }
  return null;
}

export async function analyzeMeal(
  env: Env,
  uid: string,
  data: ScanRequest,
): Promise<Record<string, unknown>> {
  const db = new Firestore(env);
  const config = await loadConfig(db);

  const { imageBase64, mimeType, hint, description } = data;
  const isPhoto = typeof imageBase64 === "string" && imageBase64.length > 0;

  if (!isPhoto && !description?.trim()) {
    throw new HttpsError("invalid-argument", "Send either a photo or a description.");
  }

  // The client ships 150-300KB, so anything near this is a client bug rather
  // than a user with a good camera.
  if (isPhoto && imageBase64.length > 7_000_000) {
    throw new HttpsError(
      "invalid-argument",
      "That image is too large. It should be downsized before upload.",
    );
  }

  const bucket = await quotaBucket(db, uid, config);
  await reserveQuota(db, uid, bucket);

  const started = Date.now();

  try {
    const content = isPhoto
      ? [
          { type: "input_text", text: photoPrompt(hint) },
          {
            type: "input_image",
            image_url: `data:${mimeType ?? "image/jpeg"};base64,${imageBase64}`,
            detail: config.imageDetail,
          },
        ]
      : [{ type: "input_text", text: describePrompt(description!.trim()) }];

    // The Responses API rather than Chat Completions: reasoning models take
    // `reasoning.effort` and `max_output_tokens` here, and reject the
    // `temperature` that a non-reasoning model would want.
    const response = await fetch(OPENAI_URL, {
      method: "POST",
      headers: {
        authorization: `Bearer ${env.OPENAI_API_KEY}`,
        "content-type": "application/json",
      },
      body: JSON.stringify({
        model: config.model,
        instructions: SYSTEM_PROMPT,
        input: [{ role: "user", content }],
        reasoning: { effort: config.reasoningEffort },
        max_output_tokens: config.maxOutputTokens,
        text: {
          format: {
            type: "json_schema",
            name: "meal_analysis",
            strict: true,
            schema: MEAL_ANALYSIS_SCHEMA,
          },
        },
      }),
    });

    if (!response.ok) {
      throw new UpstreamError(response.status, await response.text());
    }

    const body = (await response.json()) as ResponsesBody;

    const refusal = refusalOf(body);
    if (refusal) {
      console.warn("model refused", uid, refusal);
      throw new HttpsError(
        "invalid-argument",
        "That photo could not be analysed. Try another, or describe your meal.",
      );
    }

    // Running out of tokens mid-object leaves nothing usable. With reasoning
    // billed as output, this most often means effort is set too high for the
    // budget rather than the meal being complicated.
    if (body.status === "incomplete") {
      console.error("incomplete response", uid, body.incomplete_details?.reason);
      throw new HttpsError(
        "resource-exhausted",
        "That one took too long to work out. Try a closer photo.",
      );
    }

    const text = outputText(body);
    if (!text) throw new HttpsError("internal", "The analyser returned nothing.");

    // Guaranteed parseable under strict mode; the guard is for the window
    // after a config change where schema and model disagree.
    let parsed: MealAnalysis;
    try {
      parsed = JSON.parse(text) as MealAnalysis;
    } catch {
      console.error("unparseable response", text.slice(0, 500));
      throw new HttpsError("internal", "The analyser returned a bad response.");
    }

    const analysis = sanitize(parsed);
    const latencyMs = Date.now() - started;

    const inputTokens = body.usage?.input_tokens ?? 0;
    const outputTokens = body.usage?.output_tokens ?? 0;
    const reasoningTokens = body.usage?.output_tokens_details?.reasoning_tokens ?? 0;
    const costUsd =
      (inputTokens / 1_000_000) * config.inputPricePerMTok +
      (outputTokens / 1_000_000) * config.outputPricePerMTok;

    // The scan log is the eval set and the cost dashboard in one. The image is
    // never written here — only what it cost and what came back. `observations`
    // is kept because it is the model's own reasoning, and the fastest way to
    // see why a bad estimate went wrong.
    const scanId = documentId();
    await db.set(`users/${uid}/scans/${scanId}`, {
      id: scanId,
      input: isPhoto ? "photo" : "text",
      hint: hint ?? null,
      description: description ?? null,
      model: config.model,
      premium: bucket.premium,
      reasoningEffort: config.reasoningEffort,
      promptVersion: PROMPT_VERSION,
      observations: analysis.observations,
      itemCount: analysis.items.length,
      overallConfidence: analysis.overall_confidence,
      inputTokens,
      outputTokens,
      reasoningTokens,
      costUsd,
      latencyMs,
      createdAt: serverTimestamp(),
    });

    console.log("scan complete", JSON.stringify({
      uid, model: config.model, itemCount: analysis.items.length,
      latencyMs, reasoningTokens, costUsd,
    }));

    return {
      id: scanId,
      items: analysis.items,
      overallConfidence: analysis.overall_confidence,
      clarifyingQuestion: analysis.clarifying_question,
      model: config.model,
      latencyMs,
    };
  } catch (error) {
    await releaseQuota(db, uid, bucket.id);

    if (error instanceof HttpsError) throw error;

    // Everything below is an upstream failure. What the user sees is
    // deliberately generic: an OpenAI error string is not something to put in
    // front of someone, and can name internals.
    console.error("scan failed", uid, config.model, error);

    const status = error instanceof UpstreamError ? error.status : 0;
    if (status === 429) {
      throw new HttpsError("resource-exhausted", "The analyser is busy. Try again in a moment.");
    }
    if (status === 401 || status === 403) {
      throw new HttpsError(
        "failed-precondition",
        "The analyser is not configured correctly. Please contact support.",
      );
    }
    if (status === 400) {
      // Almost always a config/scan edit that named a model without vision or
      // without structured outputs.
      throw new HttpsError(
        "failed-precondition",
        "The analyser rejected that request. Please contact support.",
      );
    }
    throw new HttpsError(
      "unavailable",
      "We could not read that one. Try again, or describe your meal.",
    );
  }
}

class UpstreamError extends Error {
  constructor(readonly status: number, body: string) {
    super(`openai ${status}: ${body.slice(0, 500)}`);
  }
}
