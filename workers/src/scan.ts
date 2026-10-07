import { HttpsError } from "./callable.js";
import { assertUnderDailyCap, recordSpend } from "./spend.js";
import type { Env } from "./env.js";
import { Firestore, documentId, increment, serverTimestamp } from "./firestore.js";
import { PROMPT_VERSION, SYSTEM_PROMPT, describePrompt, photoPrompt } from "./prompt.js";
import { MEAL_ANALYSIS_SCHEMA, sanitize, type MealAnalysis } from "./schema.js";
import { isPremium } from "./subscription.js";

/**
 * Meal analysis — the port of `analyzeMeal`.
 *
 * The model API key lives in this Worker and only here. That was always the
 * reason the server leg existed; the only thing that changed is which server.
 *
 * ---------------------------------------------------------------------------
 * Chat Completions, not the Responses API
 * ---------------------------------------------------------------------------
 * The Cloud Function version used OpenAI's Responses API. This calls
 * `/chat/completions` instead, because the default provider is now OpenRouter
 * and OpenRouter exposes Chat Completions only. That is not a downgrade for
 * this use: strict `json_schema` structured outputs, reasoning effort and image
 * input are all available on it, so every property the pipeline depends on
 * survives — including the one that matters most, that under strict mode the
 * model emits fields in schema order, which is why `observations` is first.
 *
 * It is also the more portable choice: Chat Completions works against OpenAI
 * directly too, so moving off OpenRouter is a `baseUrl` change in `config/scan`
 * rather than a rewrite. The two parameters that differ between them are noted
 * at their use sites.
 *
 * No SDK: the call is one POST, and going through `fetch` keeps the bundle
 * small and the wire format visible.
 */

const DEFAULTS = {
  /**
   * Where the model lives. OpenRouter by default; `https://api.openai.com/v1`
   * talks to OpenAI directly. Server-side config, like the model itself, so
   * switching provider needs no app release.
   */
  baseUrl: "https://openrouter.ai/api/v1",

  /**
   * `openai/gpt-5.6-luna` — vision, structured outputs, and the cheapest of the
   * 5.6 family. Published evaluations put ~99.6% of accuracy variance on model
   * choice rather than prompt wording, so this is the field to change first if
   * results disappoint. `openai/gpt-5.6-terra` is the accuracy upgrade.
   *
   * OpenRouter requires the organisation prefix; against OpenAI directly, drop
   * the `openai/`.
   */
  model: "openai/gpt-5.6-luna",
  /** Reasoning models. Low keeps the 10-second target reachable. */
  reasoningEffort: "low",
  /** Covers reasoning tokens as well as the visible answer — both are billed. */
  maxOutputTokens: 4000,
  /**
   * USD per million tokens, used only when the provider does not report its own
   * cost. OpenRouter always returns `usage.cost`, which is the real figure and
   * is preferred — model prices move faster than anyone updates a constant.
   */
  inputPricePerMTok: 0.2,
  outputPricePerMTok: 1.2,
  monthlyQuota: 100,
  /**
   * USD per day across the whole app before the model is refused. A fuse, not
   * accounting — see `spend.ts`. Server-side config, so it can be raised
   * without a deploy the moment real traffic justifies it.
   */
  dailySpendCapUsd: 20,
  /** Free scans in total, ever — the bucket never resets. */
  freeScanLimit: 3,
  /** Portion estimation depends on the texture downsampling destroys. */
  imageDetail: "high",
};

export type ScanConfig = typeof DEFAULTS;

/** Longest free text accepted on `hint` or `description`. */
const MAX_TEXT = 400;

function clampText(value: unknown, max: number): string | undefined {
  if (typeof value !== "string") return undefined;
  const trimmed = value.trim();
  return trimmed.length === 0 ? undefined : trimmed.slice(0, max);
}


/**
 * Reads `config/scan`, falling back per-field to [DEFAULTS].
 *
 * The model must be switchable without an app release; this is that seam. A
 * missing document, or a missing field within it, is normal.
 */
export async function loadConfig(db: Firestore): Promise<ScanConfig> {
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

interface ChatBody {
  choices?: Array<{
    finish_reason?: string;
    message?: { content?: string | null; refusal?: string | null };
  }>;
  usage?: {
    prompt_tokens?: number;
    completion_tokens?: number;
    completion_tokens_details?: { reasoning_tokens?: number };
    /** OpenRouter reports the real cost in USD. OpenAI does not. */
    cost?: number;
  };
  error?: { message?: string };
}

export async function analyzeMeal(
  env: Env,
  uid: string,
  data: ScanRequest,
): Promise<Record<string, unknown>> {
  const db = new Firestore(env);
  const config = await loadConfig(db);

  const { imageBase64, mimeType } = data;
  const isPhoto = typeof imageBase64 === "string" && imageBase64.length > 0;

  // Both free-text fields are clamped before they go anywhere near the prompt.
  //
  // `prompt.ts` interpolates them raw, so an unbounded string is an unbounded
  // bill: a one-megabyte "description" is roughly 250k input tokens charged
  // against a single quota unit, a ~40x multiplier on a scan that is supposed
  // to cost a tenth of a cent. The image had a size guard from the start and
  // these did not, which mattered less while nothing in the app could reach
  // `hint` — the capture screen offers it now.
  //
  // Truncated rather than rejected: a long note is a person typing, not an
  // attack, and 400 characters is far more than the field is for.
  const hint = clampText(data.hint, MAX_TEXT);
  const description = clampText(data.description, MAX_TEXT);

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

  // Not an image at all — wrong bytes, a `data:` prefix, a file picked from
  // Downloads that was never a photo. Caught here from the first sixteen
  // bytes rather than six seconds later as a provider 400 that used to read
  // "contact support".
  if (isPhoto && !looksLikeImage(imageBase64)) {
    throw new HttpsError(
      "invalid-argument",
      "That photo could not be read. Try another one, or describe your meal.",
    );
  }

  // Before the per-user quota, because it is the cheaper check and the one
  // that protects the account rather than the person.
  await assertUnderDailyCap(db, config.dailySpendCapUsd);

  const bucket = await quotaBucket(db, uid, config);
  await reserveQuota(db, uid, bucket);

  const started = Date.now();

  // The catch below refunds the quota unit; these say it has already been
  // given back, or that the call was billed and must not be. Without the
  // first flag a scan that found no food and then failed to write its log
  // refunded twice and drove `used` negative.
  let refunded = false;
  let billed = false;

  try {
    const content = isPhoto
      ? [
          { type: "text", text: photoPrompt(hint) },
          {
            type: "image_url",
            image_url: {
              url: `data:${mimeType ?? "image/jpeg"};base64,${imageBase64}`,
              // "low" downsamples to a flat, small token count; portion
              // estimation depends on exactly the fine texture that destroys.
              detail: config.imageDetail,
            },
          },
        ]
      : [{ type: "text", text: describePrompt(description!.trim()) }];

    const response = await fetch(`${config.baseUrl}/chat/completions`, {
      method: "POST",
      headers: {
        authorization: `Bearer ${modelApiKey(env)}`,
        "content-type": "application/json",
        // Attribution on OpenRouter's app rankings. Ignored elsewhere.
        "X-OpenRouter-Title": "Carbs AI",
      },
      body: JSON.stringify({
        model: config.model,
        messages: [
          { role: "system", content: SYSTEM_PROMPT },
          { role: "user", content },
        ],
        // OpenRouter's unified shape. Against OpenAI directly this is the
        // top-level string `reasoning_effort` instead. These are reasoning
        // models, and they reject the `temperature` a non-reasoning model
        // would want — so none is sent.
        reasoning: { effort: config.reasoningEffort },
        // Reasoning tokens are billed as output and count against this, so it
        // has to cover both the thinking and the answer.
        max_tokens: config.maxOutputTokens,
        response_format: {
          type: "json_schema",
          json_schema: {
            name: "meal_analysis",
            strict: true,
            schema: MEAL_ANALYSIS_SCHEMA,
          },
        },
        // Only route to providers that actually honour strict structured
        // outputs and reasoning. Without this OpenRouter may fall through to an
        // endpoint that treats the schema as a suggestion, which fails as
        // unparseable JSON later instead of as a clear error now.
        provider: { require_parameters: true },
      }),
    });

    if (!response.ok) {
      throw new UpstreamError(response.status, await response.text());
    }

    const body = (await response.json()) as ChatBody;
    const choice = body.choices?.[0];

    // Cost is recorded here, before the refusal, truncation and parse checks
    // below — every one of those is a call the provider has already billed,
    // and each used to throw past `recordSpend`, so the most expensive
    // failures were the ones the daily fuse could not see. Awaited, not
    // fire-and-forget: an un-awaited promise can be cancelled when the
    // response is returned, and `recordSpend` swallows its own errors, so
    // awaiting it cannot fail a scan.
    const usage = body.usage;
    const spentUsd =
      typeof usage?.cost === "number"
        ? usage.cost
        : ((usage?.prompt_tokens ?? 0) / 1_000_000) * config.inputPricePerMTok +
          ((usage?.completion_tokens ?? 0) / 1_000_000) * config.outputPricePerMTok;
    if (spentUsd > 0) {
      billed = true;
      await recordSpend(db, spentUsd);
    }

    // A refusal arrives in its own field rather than as schema-shaped output,
    // so it has to be looked for explicitly.
    const refusal = choice?.message?.refusal;
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
    if (choice?.finish_reason === "length") {
      console.error("truncated response", uid, config.maxOutputTokens);
      // Deliberately not refunded: this is the most expensive call the route
      // can make — the whole output budget spent on reasoning — and refunding
      // it let one account retry it without limit.
      refunded = true;
      throw new HttpsError(
        "resource-exhausted",
        "That one took too long to work out. Try a closer photo.",
      );
    }

    const text = choice?.message?.content;
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

    const analysis = sanitize(parsed, isPhoto);

    // Nothing edible in the picture: the person gets a question, not a
    // plate, and should not pay a scan for it. The model call itself is
    // still recorded against the daily spend cap, which is what bounds
    // someone feeding the analyser wallpaper.
    if (analysis.items.length === 0) {
      await releaseQuota(db, uid, bucket.id);
      refunded = true;
    }
    const latencyMs = Date.now() - started;

    const inputTokens = body.usage?.prompt_tokens ?? 0;
    const outputTokens = body.usage?.completion_tokens ?? 0;
    const reasoningTokens =
      body.usage?.completion_tokens_details?.reasoning_tokens ?? 0;

    // Computed above, where it is recorded against the daily cap; the same
    // figure is written to the scan log so the two can never disagree.
    const costUsd = spentUsd;

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
      /** Whether costUsd came from the provider or from our own price table. */
      costReported: typeof body.usage?.cost === "number",
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
    // One refund at most, and none for a call the provider billed.
    if (!refunded) {
      refunded = true;
      await releaseQuota(db, uid, bucket.id);
    }

    if (error instanceof HttpsError) throw error;
    if (billed) console.warn("billed scan failed after the model answered", uid);

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
      // With a photo attached this is the provider failing to decode it — a
      // corrupt or truncated file that passed the magic-byte check. Without
      // one it is almost always a config/scan edit that named a model without
      // vision or without structured outputs.
      throw new HttpsError(
        isPhoto ? "invalid-argument" : "failed-precondition",
        isPhoto
          ? "That photo could not be read. Try a clearer one, or describe your meal."
          : "The analyser rejected that request. Please contact support.",
      );
    }
    throw new HttpsError(
      "unavailable",
      "We could not read that one. Try again, or describe your meal.",
    );
  }
}

/**
 * The key for whatever [DEFAULTS.baseUrl] points at.
 *
 * `OPENAI_API_KEY` is the historical name and currently holds an OpenRouter
 * key, which is a trap worth naming: set `OPENROUTER_API_KEY` instead and it
 * takes precedence, so the secret's name can match its contents.
 */
export function modelApiKey(env: Env): string {
  return env.OPENROUTER_API_KEY || env.OPENAI_API_KEY;
}

export class UpstreamError extends Error {
  constructor(readonly status: number, body: string) {
    super(`openai ${status}: ${body.slice(0, 500)}`);
  }
}

/**
 * Whether [base64] begins like a JPEG, PNG, WebP, GIF or HEIC/HEIF file.
 *
 * Only the first sixteen bytes are decoded, so this costs nothing on a
 * 300 KB upload. Anything the client can produce — the camera plugin, the
 * photo picker, the file picker — starts with one of these; anything else
 * is not a picture and would only come back as a provider error.
 */
export function looksLikeImage(base64: string): boolean {
  let head: Uint8Array;
  try {
    const chunk = base64.slice(0, 24).replace(/[^A-Za-z0-9+/=]/g, "");
    if (chunk.length < 16) return false;
    const bin = atob(chunk.slice(0, chunk.length - (chunk.length % 4)));
    head = Uint8Array.from(bin, (c) => c.charCodeAt(0));
  } catch {
    return false;
  }
  if (head.length < 12) return false;
  const ascii = (from: number, to: number): string =>
    String.fromCharCode(...head.slice(from, to));
  if (head[0] === 0xff && head[1] === 0xd8 && head[2] === 0xff) return true; // JPEG
  if (head[0] === 0x89 && ascii(1, 4) === "PNG") return true;
  if (ascii(0, 4) === "RIFF" && ascii(8, 12) === "WEBP") return true;
  if (ascii(0, 4) === "GIF8") return true;
  if (ascii(4, 8) === "ftyp") return true; // HEIC / HEIF / AVIF
  return false;
}
