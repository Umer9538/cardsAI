import { randomInt, createHmac, timingSafeEqual } from "node:crypto";

import { getAuth } from "firebase-admin/auth";
import { FieldValue, Timestamp } from "firebase-admin/firestore";
import { defineSecret } from "firebase-functions/params";
import { HttpsError, onCall, type CallableRequest } from "firebase-functions/v2/https";
import { logger } from "firebase-functions/v2";
import nodemailer from "nodemailer";

import { db } from "./app.js";

/**
 * SMTP credentials, in Secret Manager.
 *
 * Deliberately generic rather than tied to one vendor's SDK — any provider with
 * an SMTP endpoint works, and switching is a secret change rather than a code
 * change. Brevo (300/day free forever) is the suggested default; Resend and
 * Gmail also work.
 *
 *   firebase functions:secrets:set SMTP_HOST
 *   firebase functions:secrets:set SMTP_PORT
 *   firebase functions:secrets:set SMTP_USER
 *   firebase functions:secrets:set SMTP_PASS
 *   firebase functions:secrets:set SMTP_FROM      # "Carbsai <no-reply@yourdomain>"
 *   firebase functions:secrets:set OTP_PEPPER     # any long random string
 */
const SMTP_HOST = defineSecret("SMTP_HOST");
const SMTP_PORT = defineSecret("SMTP_PORT");
const SMTP_USER = defineSecret("SMTP_USER");
const SMTP_PASS = defineSecret("SMTP_PASS");
const SMTP_FROM = defineSecret("SMTP_FROM");

/**
 * Server-side secret mixed into the code hash.
 *
 * Without it, a leaked database is trivially brute-forced: there are only a
 * million six-digit codes, so an attacker with the stored hash and the uid can
 * enumerate every one in milliseconds. The pepper is not in the database, so a
 * database leak alone is not enough.
 */
const OTP_PEPPER = defineSecret("OTP_PEPPER");

export const OTP_SECRETS = [
  SMTP_HOST,
  SMTP_PORT,
  SMTP_USER,
  SMTP_PASS,
  SMTP_FROM,
  OTP_PEPPER,
];

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

/** `users/{uid}/private/emailOtp` — unreachable from any client by the rules. */
function otpDoc(uid: string) {
  return db.doc(`users/${uid}/private/emailOtp`);
}

/**
 * HMAC rather than a bare hash, keyed by the pepper and bound to the uid.
 *
 * Binding to the uid means a code minted for one account cannot be replayed
 * against another even if it is observed in transit.
 */
function hashCode(code: string, uid: string, pepper: string): Buffer {
  return createHmac("sha256", pepper).update(`${uid}:${code}`).digest();
}

/** Cryptographically random, zero-padded. `Math.random` is not acceptable here. */
function generateCode(): string {
  return randomInt(0, 10 ** RULES.digits)
    .toString()
    .padStart(RULES.digits, "0");
}

function requireAuth(request: CallableRequest): { uid: string } {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Sign in first.");
  return { uid };
}

function transport() {
  const port = Number(SMTP_PORT.value() || 587);
  return nodemailer.createTransport({
    host: SMTP_HOST.value(),
    port,
    // 465 is implicit TLS; 587 upgrades with STARTTLS.
    secure: port === 465,
    auth: { user: SMTP_USER.value(), pass: SMTP_PASS.value() },
  });
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
 * HMAC is stored, so neither a database dump nor the function logs can be used
 * to sign in as someone.
 */
export const sendEmailOtp = onCall(
  { secrets: OTP_SECRETS, region: "us-central1", timeoutSeconds: 30 },
  async (request) => {
    const { uid } = requireAuth(request);

    const user = await getAuth().getUser(uid);
    if (!user.email) {
      throw new HttpsError("failed-precondition", "This account has no email address.");
    }
    if (user.emailVerified) return { alreadyVerified: true };

    const now = Date.now();
    const existing = (await otpDoc(uid).get()).data();

    // Throttle before doing any work: both guards protect someone else's inbox,
    // since the address is not necessarily the caller's to spam.
    const lastSentAt = (existing?.lastSentAt as Timestamp | undefined)?.toMillis() ?? 0;
    const since = (now - lastSentAt) / 1000;
    if (since < RULES.resendCooldownSeconds) {
      throw new HttpsError(
        "resource-exhausted",
        `Wait ${Math.ceil(RULES.resendCooldownSeconds - since)} seconds before asking for another code.`,
      );
    }

    const windowStart =
      (existing?.windowStart as Timestamp | undefined)?.toMillis() ?? 0;
    const sendsThisHour = (existing?.sendsThisHour as number | undefined) ?? 0;
    const withinWindow = now - windowStart < 60 * 60 * 1000;
    if (withinWindow && sendsThisHour >= RULES.maxSendsPerHour) {
      throw new HttpsError(
        "resource-exhausted",
        "Too many codes requested. Try again in an hour.",
      );
    }

    const code = generateCode();

    await otpDoc(uid).set({
      hash: hashCode(code, uid, OTP_PEPPER.value()).toString("base64"),
      expiresAt: Timestamp.fromMillis(now + RULES.ttlMinutes * 60 * 1000),
      attempts: 0,
      lastSentAt: FieldValue.serverTimestamp(),
      windowStart: withinWindow
        ? Timestamp.fromMillis(windowStart)
        : Timestamp.fromMillis(now),
      sendsThisHour: withinWindow ? sendsThisHour + 1 : 1,
    });

    const { text, html } = emailBody(code);
    try {
      await transport().sendMail({
        from: SMTP_FROM.value(),
        to: user.email,
        subject: `${code} is your Carbsai verification code`,
        text,
        html,
      });
    } catch (error) {
      // The code is already stored; leaving it would let a later guess succeed
      // against a code nobody received.
      await otpDoc(uid).delete().catch(() => undefined);
      logger.error("otp send failed", { uid, error });
      throw new HttpsError(
        "unavailable",
        "We could not send that email. Check the address and try again.",
      );
    }

    logger.info("otp sent", { uid });
    return { sent: true, expiresInMinutes: RULES.ttlMinutes };
  },
);

/**
 * Checks a code and, on success, marks the account's email verified.
 *
 * Verification is recorded on the Firebase user rather than in our own data, so
 * `user.emailVerified` stays the single source of truth and security rules can
 * key on it later if they need to.
 */
export const verifyEmailOtp = onCall<{ code?: string }>(
  { secrets: OTP_SECRETS, region: "us-central1", timeoutSeconds: 30 },
  async (request) => {
    const { uid } = requireAuth(request);
    const code = (request.data?.code ?? "").trim();

    if (!/^\d{6}$/.test(code)) {
      throw new HttpsError("invalid-argument", "Enter the 6-digit code.");
    }

    const snap = await otpDoc(uid).get();
    const data = snap.data();
    if (!data) {
      throw new HttpsError(
        "not-found",
        "That code has expired. Ask for a new one.",
      );
    }

    if ((data.expiresAt as Timestamp).toMillis() < Date.now()) {
      await otpDoc(uid).delete();
      throw new HttpsError(
        "deadline-exceeded",
        "That code has expired. Ask for a new one.",
      );
    }

    const attempts = (data.attempts as number | undefined) ?? 0;
    if (attempts >= RULES.maxAttempts) {
      await otpDoc(uid).delete();
      throw new HttpsError(
        "resource-exhausted",
        "Too many wrong codes. Ask for a new one.",
      );
    }

    const expected = Buffer.from(data.hash as string, "base64");
    const actual = hashCode(code, uid, OTP_PEPPER.value());

    // timingSafeEqual throws on a length mismatch, so guard it. Both sides are
    // 32-byte HMAC output, so this only trips on corrupt data.
    const ok = expected.length === actual.length && timingSafeEqual(expected, actual);

    if (!ok) {
      await otpDoc(uid).update({ attempts: FieldValue.increment(1) });
      const left = RULES.maxAttempts - attempts - 1;
      throw new HttpsError(
        "invalid-argument",
        left > 0
          ? `That code is not right. ${left} ${left === 1 ? "try" : "tries"} left.`
          : "That code is not right. Ask for a new one.",
      );
    }

    // Single-use: burn it before returning, so a captured code cannot be
    // replayed.
    await otpDoc(uid).delete();
    await getAuth().updateUser(uid, { emailVerified: true });

    logger.info("otp verified", { uid });
    return { verified: true };
  },
);
