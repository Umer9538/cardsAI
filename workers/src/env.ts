/** Everything the Worker is configured with. See `workers/README.md`. */
export interface Env {
  // ---- vars (wrangler.toml) ----
  FIREBASE_PROJECT_ID: string;
  /** Public base URL for meal photos, e.g. "https://photos.carbsai.com". */
  PHOTO_PUBLIC_BASE: string;

  // ---- secrets (wrangler secret put) ----
  /** The whole service-account JSON, as one string. */
  FIREBASE_SERVICE_ACCOUNT: string;
  OPENAI_API_KEY: string;
  /** Mixed into the OTP HMAC. Never stored in Firestore. */
  OTP_PEPPER: string;
  /** Transactional email provider key. See email.ts. */
  EMAIL_API_KEY: string;
  /** e.g. "Carbsai <no-reply@yourdomain>" */
  EMAIL_FROM: string;

  // ---- bindings ----
  PHOTOS: R2Bucket;
}
