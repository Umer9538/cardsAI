/** Everything the Worker is configured with. See `workers/README.md`. */
export interface Env {
  // ---- vars (wrangler.toml) ----
  FIREBASE_PROJECT_ID: string;
  /** Public base URL for meal photos, e.g. "https://photos.carbsai.com". */
  PHOTO_PUBLIC_BASE: string;

  // ---- secrets (wrangler secret put) ----
  /** The whole service-account JSON, as one string. */
  FIREBASE_SERVICE_ACCOUNT: string;
  /**
   * The model API key, for whatever `config/scan.baseUrl` points at.
   *
   * `OPENAI_API_KEY` is the historical name and may hold an OpenRouter key;
   * `OPENROUTER_API_KEY` takes precedence if set, so the name can match the
   * contents. One of the two must exist.
   */
  OPENAI_API_KEY: string;
  OPENROUTER_API_KEY?: string;
  /** Mixed into the OTP HMAC. Never stored in Firestore. */
  OTP_PEPPER: string;
  /** Transactional email provider key. See email.ts. */
  EMAIL_API_KEY: string;
  /** e.g. "Carbsai <no-reply@yourdomain>" */
  EMAIL_FROM: string;

  // ---- bindings ----
  /// Optional: absent until R2 is enabled on the account and the binding is
  /// uncommented in wrangler.toml. `/photos` reports that plainly rather than
  /// throwing, because a missing photo is not worth failing a logged meal over.
  PHOTOS?: R2Bucket;
}
