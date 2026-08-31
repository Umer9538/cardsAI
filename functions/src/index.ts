import { FieldValue } from "firebase-admin/firestore";
import { defineSecret } from "firebase-functions/params";
import { HttpsError, onCall, type CallableRequest } from "firebase-functions/v2/https";
import { logger } from "firebase-functions/v2";
import OpenAI from "openai";

import { db } from "./app.js";
import { PROMPT_VERSION, SYSTEM_PROMPT, describePrompt, photoPrompt } from "./prompt.js";
import { MEAL_ANALYSIS_SCHEMA, sanitize, type MealAnalysis } from "./schema.js";
import { isPremium } from "./subscription.js";

// Email verification codes. Re-exported here so `firebase deploy --only
// functions` picks them up; the implementation lives next door because it
// shares nothing with the scan pipeline but the app instance.
export { sendEmailOtp, verifyEmailOtp } from "./otp.js";
export { activateSubscription, cancelSubscription } from "./subscription.js";
export { grantBonusScans } from "./rewards.js";

/**
 * Held in Google Secret Manager, never in source and never in the client.
 *
 *   firebase functions:secrets:set OPENAI_API_KEY
 */
const OPENAI_API_KEY = defineSecret("OPENAI_API_KEY");

/**
 * Defaults for anything the `config/scan` document does not override.
 *
 * Model ids and prices move faster than app releases, which is the entire
 * reason this is server-side config. Verify both against current OpenAI pricing
 * before trusting the cost figures written to the scan log.
 */
const DEFAULTS = {
  /**
   * `gpt-5.6-luna` — vision, structured outputs, and the cheapest of the 5.6
   * family at $0.20/$1.20 per MTok. Published evaluations put ~99.6% of
   * accuracy variance on model choice rather than prompt wording, so this is
   * the field to change first if results disappoint. `gpt-5.6-terra`
   * ($2/$12) is the accuracy upgrade.
   */
  model: "gpt-5.6-luna",

  /**
   * Reasoning effort. These are reasoning models, and the schema's
   * `observations` field already gives a chain-of-thought foothold, so a low
   * setting buys most of the benefit without the latency — this sits in front
   * of a 10-second target. Raise to "medium" if eval accuracy justifies it.
   */
  reasoningEffort: "low" as
    | "none"
    | "minimal"
    | "low"
    | "medium"
    | "high"
    | "xhigh"
    | "max",

  /** Covers reasoning tokens as well as the visible answer — both are billed. */
  maxOutputTokens: 4000,

  /** USD per million tokens. */
  inputPricePerMTok: 0.2,
  outputPricePerMTok: 1.2,

  /** Scans per premium user per calendar month. */
  monthlyQuota: 100,

  /**
   * Scans a free account gets in total, ever — not per month.
   *
   * The PRD's "taste of value" number. It counts against a bucket that never
   * resets, so a free user cannot wait for the month to roll over.
   */
  freeScanLimit: 3,

  /**
   * "low" downsamples server-side to a flat, small token count; "high" keeps
   * detail at several times the price. The client already ships a 1280px long
   * edge, and portion estimation depends on exactly the fine texture that
   * downsampling destroys — so "high" earns its cost here. "auto" would let
   * the API decide silently.
   */
  imageDetail: "high" as "low" | "high" | "auto",
};

type ScanConfig = typeof DEFAULTS;

/**
 * Reads `config/scan`, falling back per-field to [DEFAULTS].
 *
 * The PRD requires the model be switchable without an app release; this is that
 * seam. A missing document, or a missing field within it, is normal.
 */
async function loadConfig(): Promise<ScanConfig> {
  try {
    const snap = await db.doc("config/scan").get();
    return { ...DEFAULTS, ...(snap.data() ?? {}) } as ScanConfig;
  } catch (error) {
    logger.warn("config/scan unreadable; using defaults", { error });
    return DEFAULTS;
  }
}

function requireAuth(request: CallableRequest): string {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Sign in to scan a meal.");
  return uid;
}

/** YYYY-MM, the quota bucket. */
function currentPeriod(): string {
  return new Date().toISOString().slice(0, 7);
}

/**
 * Which quota bucket an account counts against.
 *
 * Premium accounts get a fresh allowance every calendar month. Free accounts
 * count against a single bucket that never resets, so the free scans are a
 * lifetime allowance rather than something that returns each month.
 */
async function quotaBucket(
  uid: string,
  config: ScanConfig,
): Promise<{ id: string; limit: number; premium: boolean }> {
  const premium = await isPremium(uid);
  return premium
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
async function reserveQuota(
  uid: string,
  bucket: { id: string; limit: number; premium: boolean },
): Promise<void> {
  const ref = db.doc(`users/${uid}/quota/${bucket.id}`);

  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const used = (snap.data()?.used as number | undefined) ?? 0;
    const bonus = (snap.data()?.bonus as number | undefined) ?? 0;
    const limit = bucket.limit + bonus;

    if (used >= limit) {
      throw new HttpsError(
        "resource-exhausted",
        bucket.premium
          ? `You have used all ${limit} scans this month. Describe and search ` +
              "still work."
          : `You have used your ${limit} free scans. Upgrade for more.`,
      );
    }
    tx.set(
      ref,
      { used: FieldValue.increment(1), updatedAt: FieldValue.serverTimestamp() },
      { merge: true },
    );
  });
}

async function releaseQuota(uid: string, bucketId: string): Promise<void> {
  try {
    await db
      .doc(`users/${uid}/quota/${bucketId}`)
      .set({ used: FieldValue.increment(-1) }, { merge: true });
  } catch (error) {
    // Losing a refund is better than masking the original failure, which is
    // what the caller is actually waiting to hear about.
    logger.warn("quota refund failed", { uid, error });
  }
}

interface ScanRequest {
  /** Base64 JPEG, no `data:` prefix. Absent on the text-only path. */
  imageBase64?: string;
  mimeType?: string;
  /** The one-line note the capture screen offers. */
  hint?: string;
  /** Free-text meal description, for the "describe it" fallback. */
  description?: string;
}

async function analyze(
  request: CallableRequest<ScanRequest>,
): Promise<Record<string, unknown>> {
  const uid = requireAuth(request);
  const config = await loadConfig();

  const { imageBase64, mimeType, hint, description } = request.data ?? {};
  const isPhoto = typeof imageBase64 === "string" && imageBase64.length > 0;

  if (!isPhoto && !description?.trim()) {
    throw new HttpsError("invalid-argument", "Send either a photo or a description.");
  }

  // Callable payloads cap around 10MB and base64 inflates by a third. The
  // client ships 150-300KB, so anything near this is a client bug rather than
  // a user with a good camera.
  if (isPhoto && imageBase64.length > 7_000_000) {
    throw new HttpsError(
      "invalid-argument",
      "That image is too large. It should be downsized before upload.",
    );
  }

  const bucket = await quotaBucket(uid, config);
  await reserveQuota(uid, bucket);

  const started = Date.now();
  const openai = new OpenAI({ apiKey: OPENAI_API_KEY.value() });

  try {
    const content = isPhoto
      ? [
          { type: "input_text" as const, text: photoPrompt(hint) },
          {
            type: "input_image" as const,
            image_url: `data:${mimeType ?? "image/jpeg"};base64,${imageBase64}`,
            detail: config.imageDetail,
          },
        ]
      : [
          {
            type: "input_text" as const,
            text: describePrompt(description!.trim()),
          },
        ];

    // The Responses API rather than Chat Completions: reasoning models take
    // `reasoning.effort` and `max_output_tokens` here, and reject the
    // `temperature` that a non-reasoning model would want.
    const response = await openai.responses.create({
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
          schema: MEAL_ANALYSIS_SCHEMA as unknown as Record<string, unknown>,
        },
      },
    });

    // A refusal arrives as its own content part rather than as schema-shaped
    // output, so it has to be looked for explicitly. Narrowing on the message
    // item type first is what makes `content` well-typed — the output array
    // also carries reasoning and tool items that have no content at all.
    let refusal: string | null = null;
    for (const item of response.output ?? []) {
      if (item.type !== "message") continue;
      for (const part of item.content) {
        if (part.type === "refusal") {
          refusal = part.refusal;
          break;
        }
      }
      if (refusal) break;
    }

    if (refusal) {
      logger.warn("model refused", { uid, refusal });
      throw new HttpsError(
        "invalid-argument",
        "That photo could not be analysed. Try another, or describe your meal.",
      );
    }

    // Running out of tokens mid-object leaves nothing usable. With reasoning
    // billed as output, this most often means effort is set too high for the
    // budget rather than the meal being complicated.
    if (response.status === "incomplete") {
      logger.error("incomplete response", {
        uid,
        reason: response.incomplete_details?.reason,
        maxOutputTokens: config.maxOutputTokens,
      });
      throw new HttpsError(
        "resource-exhausted",
        "That one took too long to work out. Try a closer photo.",
      );
    }

    const text = response.output_text;
    if (!text) throw new HttpsError("internal", "The analyser returned nothing.");

    // Guaranteed parseable under strict mode; the guard is for the window
    // after a config change where schema and model disagree.
    let parsed: MealAnalysis;
    try {
      parsed = JSON.parse(text) as MealAnalysis;
    } catch {
      logger.error("unparseable response", { text: text.slice(0, 500) });
      throw new HttpsError("internal", "The analyser returned a bad response.");
    }

    const analysis = sanitize(parsed);
    const latencyMs = Date.now() - started;

    const inputTokens = response.usage?.input_tokens ?? 0;
    const outputTokens = response.usage?.output_tokens ?? 0;
    const reasoningTokens =
      response.usage?.output_tokens_details?.reasoning_tokens ?? 0;
    const costUsd =
      (inputTokens / 1_000_000) * config.inputPricePerMTok +
      (outputTokens / 1_000_000) * config.outputPricePerMTok;

    // The scan log is the eval set and the cost dashboard in one. The image is
    // never written here — only what it cost and what came back. `observations`
    // is kept because it is the model's own reasoning, and the fastest way to
    // see why a bad estimate went wrong.
    const scanRef = db.collection(`users/${uid}/scans`).doc();
    await scanRef.set({
      id: scanRef.id,
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
      createdAt: FieldValue.serverTimestamp(),
    });

    logger.info("scan complete", {
      uid,
      model: config.model,
      itemCount: analysis.items.length,
      latencyMs,
      reasoningTokens,
      costUsd,
    });

    return {
      id: scanRef.id,
      items: analysis.items,
      overallConfidence: analysis.overall_confidence,
      clarifyingQuestion: analysis.clarifying_question,
      model: config.model,
      latencyMs,
    };
  } catch (error) {
    await releaseQuota(uid, bucket.id);

    if (error instanceof HttpsError) throw error;

    // Everything below is an upstream failure. What the user sees is
    // deliberately generic: an OpenAI error string is not something to put in
    // front of someone, and can name internals.
    logger.error("scan failed", { uid, model: config.model, error });

    const status = (error as { status?: number }).status;
    if (status === 429) {
      throw new HttpsError(
        "resource-exhausted",
        "The analyser is busy. Try again in a moment.",
      );
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

/**
 * Analyses a meal photo, or a written description.
 *
 * The API key lives here and only here. The app never holds it, which is the
 * entire reason this function exists rather than the client calling OpenAI
 * directly.
 */
export const analyzeMeal = onCall<ScanRequest>(
  {
    secrets: [OPENAI_API_KEY],
    region: "us-central1",
    // Reasoning plus a large image can run long; the client shows a working
    // state from the first frame and gives up before this.
    timeoutSeconds: 120,
    memory: "512MiB",
    // Cold starts are the worst part of the 10-second target. One warm
    // instance removes most of it for a few dollars a month; 0 while developing.
    minInstances: 0,
    maxInstances: 20,
    enforceAppCheck: false,
  },
  analyze,
);
