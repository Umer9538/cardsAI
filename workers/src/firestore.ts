import type { Env } from "./env.js";
import { accessToken, projectId } from "./google.js";

/**
 * Firestore over its REST API.
 *
 * This is the largest single piece of the port, because the Admin SDK was
 * doing more than it looked like: value encoding, field transforms, and
 * read-write transactions. All three are load-bearing here —
 * `reserveQuota` is only safe because it is genuinely transactional, and the
 * OTP and reward counters have the same property.
 *
 * Authority comes from the service-account token, which bypasses security
 * rules exactly as the Admin SDK did. That is what keeps
 * `users/{uid}/private/**` reachable here and nowhere else.
 *
 * Only the operations this project actually uses are implemented. Adding a
 * query would mean `runQuery`; nothing needs one yet — every read is a
 * document get by path.
 */

const BASE = "https://firestore.googleapis.com/v1";

// ---------------------------------------------------------------------------
// Value encoding
// ---------------------------------------------------------------------------

type FirestoreValue = Record<string, unknown>;

/** A field transform, applied server-side rather than read-modify-written. */
export class Transform {
  constructor(
    readonly kind: "increment" | "serverTimestamp",
    readonly amount = 0,
  ) {}
}

export const increment = (by: number): Transform => new Transform("increment", by);
export const serverTimestamp = (): Transform => new Transform("serverTimestamp");

function encode(value: unknown): FirestoreValue {
  if (value === null || value === undefined) return { nullValue: null };
  if (value instanceof Date) return { timestampValue: value.toISOString() };
  switch (typeof value) {
    case "boolean":
      return { booleanValue: value };
    case "string":
      return { stringValue: value };
    case "number":
      // Firestore distinguishes the two, and `integerValue` travels as a
      // string because JSON numbers cannot hold int64.
      return Number.isInteger(value)
        ? { integerValue: String(value) }
        : { doubleValue: value };
  }
  if (Array.isArray(value)) {
    return { arrayValue: { values: value.map(encode) } };
  }
  return { mapValue: { fields: encodeFields(value as Record<string, unknown>) } };
}

function encodeFields(data: Record<string, unknown>): Record<string, FirestoreValue> {
  const fields: Record<string, FirestoreValue> = {};
  for (const [key, value] of Object.entries(data)) {
    if (value instanceof Transform) continue;
    fields[key] = encode(value);
  }
  return fields;
}

function decode(value: FirestoreValue): unknown {
  if ("nullValue" in value) return null;
  if ("booleanValue" in value) return value.booleanValue as boolean;
  if ("stringValue" in value) return value.stringValue as string;
  if ("integerValue" in value) return Number(value.integerValue);
  if ("doubleValue" in value) return value.doubleValue as number;
  // Timestamps come back as RFC3339 and are handed on as Date, so callers can
  // compare them without re-parsing at every use site.
  if ("timestampValue" in value) return new Date(value.timestampValue as string);
  if ("arrayValue" in value) {
    const values = (value.arrayValue as { values?: FirestoreValue[] }).values ?? [];
    return values.map(decode);
  }
  if ("mapValue" in value) {
    return decodeFields((value.mapValue as { fields?: Record<string, FirestoreValue> }).fields);
  }
  return null;
}

function decodeFields(
  fields: Record<string, FirestoreValue> | undefined,
): Record<string, unknown> {
  const data: Record<string, unknown> = {};
  for (const [key, value] of Object.entries(fields ?? {})) data[key] = decode(value);
  return data;
}

function transformsOf(data: Record<string, unknown>, ): unknown[] {
  const transforms: unknown[] = [];
  for (const [fieldPath, value] of Object.entries(data)) {
    if (!(value instanceof Transform)) continue;
    transforms.push(
      value.kind === "increment"
        ? { fieldPath, increment: { integerValue: String(value.amount) } }
        : { fieldPath, setToServerValue: "REQUEST_TIME" },
    );
  }
  return transforms;
}

/**
 * A 20-character Firestore-style document id.
 *
 * The REST API can generate one, but only as a side effect of `createDocument`,
 * which is a second round trip and a different write shape. Minting it here
 * keeps every write a plain set, and the id is available before the call — the
 * scan handler returns it to the client.
 */
export function documentId(): string {
  const alphabet =
    "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789";
  const bytes = crypto.getRandomValues(new Uint8Array(20));
  return Array.from(bytes, (b) => alphabet[b % alphabet.length]).join("");
}

// ---------------------------------------------------------------------------
// Client
// ---------------------------------------------------------------------------

export interface Write {
  path: string;
  data: Record<string, unknown>;
  /** Merge (the default) leaves untouched fields alone, as `set(merge:true)`. */
  merge?: boolean;
}

export class Firestore {
  constructor(private readonly env: Env) {}

  private get root(): string {
    return `projects/${projectId(this.env)}/databases/(default)/documents`;
  }

  private async call(
    path: string,
    init: { method: string; body?: unknown },
  ): Promise<Record<string, unknown>> {
    const response = await fetch(`${BASE}/${path}`, {
      method: init.method,
      headers: {
        authorization: `Bearer ${await accessToken(this.env)}`,
        "content-type": "application/json",
      },
      body: init.body === undefined ? undefined : JSON.stringify(init.body),
    });

    if (response.status === 404) return { __missing: true };
    if (!response.ok) {
      const detail = await response.text();
      throw new Error(`Firestore ${init.method} ${path} -> ${response.status}: ${detail}`);
    }
    return (await response.json()) as Record<string, unknown>;
  }

  /** The document at [path], or null when it does not exist. */
  async get(path: string): Promise<Record<string, unknown> | null> {
    const doc = await this.call(`${this.root}/${path}`, { method: "GET" });
    if (doc.__missing) return null;
    return decodeFields(doc.fields as Record<string, FirestoreValue> | undefined);
  }

  /** Writes one document. Field transforms in [data] are applied server-side. */
  async set(path: string, data: Record<string, unknown>, merge = true): Promise<void> {
    await this.commit([{ path, data, merge }]);
  }

  async delete(path: string): Promise<void> {
    await this.call(`${this.root}/${path}`, { method: "DELETE" });
  }

  /** Applies [writes] atomically. */
  async commit(writes: Write[], transaction?: string): Promise<void> {
    await this.call(`${this.root}:commit`, {
      method: "POST",
      body: { writes: writes.map((w) => this.encodeWrite(w)), transaction },
    });
  }

  private encodeWrite(write: Write): Record<string, unknown> {
    const plain = Object.entries(write.data).filter(
      ([, value]) => !(value instanceof Transform),
    );
    const transforms = transformsOf(write.data);

    const encoded: Record<string, unknown> = {
      update: {
        name: `${this.root}/${write.path}`,
        fields: encodeFields(write.data),
      },
    };
    // Without an updateMask the write replaces the document. With one listing
    // only the fields present, it merges — which is what every caller wants,
    // and what keeps a quota refund from erasing the bonus beside it.
    if (write.merge !== false) {
      encoded.updateMask = { fieldPaths: plain.map(([key]) => key) };
    }
    if (transforms.length > 0) encoded.updateTransforms = transforms;
    return encoded;
  }

  /**
   * A read-write transaction.
   *
   * [run] may read documents and stage writes; the writes are committed
   * against the transaction, so Firestore aborts if anything read has changed
   * underneath. Retried on abort, because that is contention rather than
   * failure — which is exactly the case the quota reserve is guarding.
   */
  async transaction<T>(
    run: (tx: TransactionContext) => Promise<T>,
    attempts = 5,
  ): Promise<T> {
    let lastError: unknown;

    for (let attempt = 0; attempt < attempts; attempt++) {
      const begun = await this.call(`${this.root}:beginTransaction`, {
        method: "POST",
        body: { options: { readWrite: {} } },
      });
      const id = begun.transaction as string;
      const writes: Write[] = [];

      try {
        const result = await run({
          get: (path) => this.getInTransaction(path, id),
          set: (path, data, merge = true) => {
            writes.push({ path, data, merge });
          },
        });
        await this.commit(writes, id);
        return result;
      } catch (error) {
        // Roll back so the lock is not held for the transaction's full lifetime
        // while the client waits on a retry.
        await this.call(`${this.root}:rollback`, {
          method: "POST",
          body: { transaction: id },
        }).catch(() => undefined);

        // Anything the handler threw deliberately — a quota rejection — must
        // propagate, not be retried into four more attempts.
        if (!isAborted(error)) throw error;
        lastError = error;
      }
    }
    throw lastError;
  }

  private async getInTransaction(
    path: string,
    transaction: string,
  ): Promise<Record<string, unknown> | null> {
    const response = await this.call(`${this.root}:batchGet`, {
      method: "POST",
      body: { documents: [`${this.root}/${path}`], transaction },
    });
    const results = response as unknown as Array<{
      found?: { fields?: Record<string, FirestoreValue> };
      missing?: string;
    }>;
    const first = Array.isArray(results) ? results[0] : undefined;
    if (!first?.found) return null;
    return decodeFields(first.found.fields);
  }
}

export interface TransactionContext {
  get(path: string): Promise<Record<string, unknown> | null>;
  set(path: string, data: Record<string, unknown>, merge?: boolean): void;
}

function isAborted(error: unknown): boolean {
  return error instanceof Error && /\b(409|ABORTED)\b/.test(error.message);
}
