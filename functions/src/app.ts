import { initializeApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";

/**
 * The single place the Admin SDK is initialised.
 *
 * This exists because of ES module evaluation order: a re-export like
 * `export { x } from "./otp.js"` is hoisted and the imported module's body runs
 * *before* the importing module's. With `initializeApp()` sitting in index.ts,
 * otp.ts would call `getFirestore()` first and throw "The default Firebase app
 * does not exist" on every cold start — and only on cold start, which is the
 * worst kind of bug to find in production.
 *
 * Every module importing `db` from here transitively evaluates this first, so
 * initialisation is ordered by the module graph rather than by luck.
 */
initializeApp();

export const db = getFirestore();
