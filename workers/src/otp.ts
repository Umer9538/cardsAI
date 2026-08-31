import { base64ToBytes, bytesToBase64, timingSafeEqual, utf8 } from "./bytes.js";
import { HttpsError } from "./callable.js";
import { sendEmail } from "./email.js";
import type { Env } from "./env.js";
import { Firestore, increment, serverTimestamp } from "./firestore.js";
import { getUser, setEmailVerified } from "./identity.js";

/**
 * Our own email verification codes.
 *
 * Firebase's built-in verification is a link, which the artboard's six-box
 * screen cannot express — so the codes are ours. Every security property from
 * the Cloud Function version is preserved; only the crypto library changed
 * (`node:crypto` to WebCrypto) and the mail transport (SMTP to an HTTP API,
 * because Workers cannot speak SMTP — see email.ts).
 *
 * The document lives at `users/{uid}/private/emailOtp`, which has no rules
 * match on purpose: being able to read the attempt counter, or delete the
 * document to reset it, would defeat the brute-force limit. Only a
 * service-account token reaches it, which is what this Worker holds.
 */

const RULES = {
  /** Six digits, to match the design's six boxes. */
  digits: 6,
  /** Long enough to switch apps and read an email, short enough to matter. */
  ttlMinutes: 10,
  /** Wrong guesses before the code is burned. */
  maxAttempts: 5,
  /** Minimum gap between sends, so "Resend" cannot be used to spam an inbox. */
  resendCooldownSeconds: 60,
  /** Sends per address per hour. */
  maxSendsPerHour: 5,
} as const;

const otpPath = (uid: string) => `users/${uid}/private/emailOtp`;

/**
 * HMAC rather than a bare hash, keyed by the pepper and bound to the uid.
 *
 * A bare hash would be pointless — there are only a million six-digit codes, so
 * a database leak would be brute-forced instantly. The pepper is not in the
 * database. Binding to the uid means a code minted for one account cannot be
 * replayed against another even if it is observed in transit.
 */
async function hashCode(code: string, uid: string, pepper: string): Promise<Uint8Array> {
  const key = await crypto.subtle.importKey(
    "raw",
    utf8(pepper),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign("HMAC", key, utf8(`${uid}:${code}`));
  return new Uint8Array(signature);
}

/**
 * A uniformly random six-digit code.
 *
 * Rejection sampling rather than `% 1_000_000`: the modulo would make the low
 * codes very slightly likelier, which is exactly the kind of bias that makes a
 * six-digit space smaller than it looks.
 */
function generateCode(): string {
  const ceiling = 10 ** RULES.digits;
  const limit = Math.floor(0x1_0000_0000 / ceiling) * ceiling;
  const buffer = new Uint32Array(1);
  let value: number;
  do {
    crypto.getRandomValues(buffer);
    value = buffer[0];
  } while (value >= limit);
  return String(value % ceiling).padStart(RULES.digits, "0");
}

function emailBody(code: string): { text: string; html: string } {
  const spaced = code.split("").join(" ");
  return {
    text:
      `Your Carbsai verification code is ${code}.\n\n` +
      `It expires in ${RULES.ttlMinutes} minutes. ` +
      "If you did not ask for this, you can ignore this email.",
    html: `
<div style="font-family:-apple-system,Segoe UI,Roboto,sans-serif;max-width:420px;margin:0 auto;padding:32px 24px;color:#121212">
  <h1 style="font-size:20px;margin:0 0 8px">Verify your email</h1>
  <p style="margin:0 0 24px;color:#555;font-size:15px">Enter this code in Carbsai to finish setting up your account.</p>
  <div style="font-size:32px;font-weight:600;letter-spacing:8px;background:#F5F3F0;border-radius:12px;padding:20px;text-align:center">${spaced}</div>
  <p style="margin:24px 0 0;color:#777;font-size:13px">Expires in ${RULES.ttlMinutes} minutes. If you did not ask for this, ignore this email.</p>
</div>`.trim(),
  };
}

/**
 * Mints a code, stores its HMAC, and emails the code.
 *
 * The plaintext code is never written to Firestore and never logged — only the
 * HMAC is stored, so neither a database dump nor these logs can be used to sign
 * in as someone.
 */
export async function sendEmailOtp(
  env: Env,
  uid: string,
): Promise<{ sent?: boolean; alreadyVerified?: boolean; expiresInMinutes?: number }> {
  const db = new Firestore(env);
  const user = await getUser(env, uid);

  if (!user.email) {
    throw new HttpsError("failed-precondition", "This account has no email address.");
  }
  if (user.emailVerified) return { alreadyVerified: true };

  const now = Date.now();
  const existing = await db.get(otpPath(uid));

  // Throttle before doing any work: both guards protect someone else's inbox,
  // since the address is not necessarily the caller's to spam.
  const lastSentAt =
    existing?.lastSentAt instanceof Date ? existing.lastSentAt.getTime() : 0;
  const since = (now - lastSentAt) / 1000;
  if (since < RULES.resendCooldownSeconds) {
    throw new HttpsError(
      "resource-exhausted",
      `Wait ${Math.ceil(RULES.resendCooldownSeconds - since)} seconds before asking for another code.`,
    );
  }

  const windowStart =
    existing?.windowStart instanceof Date ? existing.windowStart.getTime() : 0;
  const sendsThisHour = (existing?.sendsThisHour as number | undefined) ?? 0;
  const withinWindow = now - windowStart < 60 * 60 * 1000;
  if (withinWindow && sendsThisHour >= RULES.maxSendsPerHour) {
    throw new HttpsError("resource-exhausted", "Too many codes requested. Try again in an hour.");
  }

  const code = generateCode();

  // Replaces rather than merges: a fresh code must reset the attempt counter,
  // and leaving a stale field behind is how a burned code comes back to life.
  await db.set(
    otpPath(uid),
    {
      hash: bytesToBase64(await hashCode(code, uid, env.OTP_PEPPER)),
      expiresAt: new Date(now + RULES.ttlMinutes * 60 * 1000),
      attempts: 0,
      lastSentAt: serverTimestamp(),
      windowStart: withinWindow ? new Date(windowStart) : new Date(now),
      sendsThisHour: withinWindow ? sendsThisHour + 1 : 1,
    },
    false,
  );

  const { text, html } = emailBody(code);
  try {
    await sendEmail(env, {
      to: user.email,
      subject: `${code} is your Carbsai verification code`,
      text,
      html,
    });
  } catch (error) {
    // The code is already stored; leaving it would let a later guess succeed
    // against a code nobody received.
    await db.delete(otpPath(uid)).catch(() => undefined);
    console.error("otp send failed", uid, error);
    throw new HttpsError(
      "unavailable",
      "We could not send that email. Check the address and try again.",
    );
  }

  console.log("otp sent", uid);
  return { sent: true, expiresInMinutes: RULES.ttlMinutes };
}

/**
 * Checks a code and, on success, marks the account's email verified.
 *
 * Verification is recorded on the Firebase user rather than in our own data, so
 * `emailVerified` stays the single source of truth and the ID token carries it.
 */
export async function verifyEmailOtp(
  env: Env,
  uid: string,
  data: { code?: string },
): Promise<{ verified: boolean }> {
  const code = (data.code ?? "").trim();
  if (!/^\d{6}$/.test(code)) {
    throw new HttpsError("invalid-argument", "Enter the 6-digit code.");
  }

  const db = new Firestore(env);
  const stored = await db.get(otpPath(uid));
  if (!stored) {
    throw new HttpsError("not-found", "That code has expired. Ask for a new one.");
  }

  const expiresAt = stored.expiresAt instanceof Date ? stored.expiresAt.getTime() : 0;
  if (expiresAt < Date.now()) {
    await db.delete(otpPath(uid));
    throw new HttpsError("deadline-exceeded", "That code has expired. Ask for a new one.");
  }

  const attempts = (stored.attempts as number | undefined) ?? 0;
  if (attempts >= RULES.maxAttempts) {
    await db.delete(otpPath(uid));
    throw new HttpsError("resource-exhausted", "Too many wrong codes. Ask for a new one.");
  }

  const expected = base64ToBytes(stored.hash as string);
  const actual = await hashCode(code, uid, env.OTP_PEPPER);

  if (!timingSafeEqual(expected, actual)) {
    await db.set(otpPath(uid), { attempts: increment(1) });
    const left = RULES.maxAttempts - attempts - 1;
    throw new HttpsError(
      "invalid-argument",
      left > 0
        ? `That code is not right. ${left} ${left === 1 ? "try" : "tries"} left.`
        : "That code is not right. Ask for a new one.",
    );
  }

  // Single-use: burn it before returning, so a captured code cannot be replayed.
  await db.delete(otpPath(uid));
  await setEmailVerified(env, uid);

  console.log("otp verified", uid);
  return { verified: true };
}
