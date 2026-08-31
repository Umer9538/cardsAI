/**
 * The Firebase callable wire protocol, reimplemented.
 *
 * The app still calls these through `cloud_functions`, using
 * `httpsCallableFromUrl` to point at this Worker instead of Google's function
 * host. That is deliberate: the SDK keeps attaching the Firebase ID token, and
 * every `FirebaseFunctionsException` translation already written in the Dart
 * repositories keeps working unchanged. In exchange, this Worker has to speak
 * the protocol exactly.
 *
 *   request   POST, Authorization: Bearer <idToken>, body {"data": ...}
 *   success   200, body {"result": ...}
 *   failure   mapped HTTP status, body {"error": {"status", "message"}}
 *
 * The status STRING is what the SDK turns back into `e.code`, and `message` is
 * what reaches the user — several of these are written to be read by a person,
 * so they must survive the round trip verbatim.
 */

export type ErrorCode =
  | "invalid-argument"
  | "failed-precondition"
  | "unauthenticated"
  | "permission-denied"
  | "not-found"
  | "resource-exhausted"
  | "deadline-exceeded"
  | "unavailable"
  | "internal";

const HTTP_STATUS: Record<ErrorCode, number> = {
  "invalid-argument": 400,
  "failed-precondition": 400,
  unauthenticated: 401,
  "permission-denied": 403,
  "not-found": 404,
  "resource-exhausted": 429,
  "deadline-exceeded": 504,
  unavailable: 503,
  internal: 500,
};

/** The canonical gRPC names the SDK maps back onto its own codes. */
const CANONICAL: Record<ErrorCode, string> = {
  "invalid-argument": "INVALID_ARGUMENT",
  "failed-precondition": "FAILED_PRECONDITION",
  unauthenticated: "UNAUTHENTICATED",
  "permission-denied": "PERMISSION_DENIED",
  "not-found": "NOT_FOUND",
  "resource-exhausted": "RESOURCE_EXHAUSTED",
  "deadline-exceeded": "DEADLINE_EXCEEDED",
  unavailable: "UNAVAILABLE",
  internal: "INTERNAL",
};

export class HttpsError extends Error {
  constructor(
    readonly code: ErrorCode,
    message: string,
  ) {
    super(message);
    this.name = "HttpsError";
  }

  toResponse(): Response {
    return json(
      { error: { status: CANONICAL[this.code], message: this.message } },
      HTTP_STATUS[this.code],
    );
  }
}

export function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json; charset=utf-8" },
  });
}

/** Reads the `{"data": ...}` envelope. A bare body is accepted too. */
export async function callableData<T>(request: Request): Promise<T> {
  let body: unknown;
  try {
    body = await request.json();
  } catch {
    return {} as T;
  }
  if (body && typeof body === "object" && "data" in body) {
    return ((body as { data: T }).data ?? {}) as T;
  }
  return (body ?? {}) as T;
}
