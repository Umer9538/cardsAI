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
  /**
   * USDA FoodData Central key, for food search. Free, and rate-limited to 1000
   * requests an hour. Behind the Worker because a key in the app binary is a
   * key that has been published.
   */
  USDA_API_KEY: string;
  /**
   * Gates `/syncFoods`, which rewrites the whole food catalogue. Not a normal
   * callable: any signed-in user could otherwise trigger tens of thousands of
   * Firestore writes.
   */
  SYNC_KEY: string;
  /** e.g. "Carbs AI <no-reply@yourdomain>" */
  EMAIL_FROM: string;

  // ---- purchases ----
  /**
   * The app's Play package name, e.g. "com.carbsai.app". Receipt validation
   * cannot be done without it: a purchase token is only meaningful against the
   * app it was bought in.
   */
  ANDROID_PACKAGE_NAME: string;
  /**
   * Service-account JSON for a Play Console account with "View financial
   * data". Usually NOT the Firebase one. See `play.ts`.
   */
  PLAY_SERVICE_ACCOUNT: string;
  /** App Store Connect → App Information → App-Specific Shared Secret. */
  APPLE_SHARED_SECRET: string;
  /**
   * Set to "1" to accept purchases without checking them with the store.
   *
   * For development against a build with no store products, which is the state
   * this app is in. **Unset in production**: with it on, anyone who can call
   * `activateSubscription` has premium. Absent means off, so the safe value is
   * the default rather than something to remember.
   */
  ALLOW_UNVERIFIED_PURCHASES?: string;
  /**
   * Set to "1" to refuse requests that do not carry a valid App Check token.
   *
   * **Leave unset until the App Check metrics in the Firebase console show what
   * share of real devices attest successfully.** Some genuinely cannot — no
   * Play Services, a rooted phone, a beta OS — and turning this on before
   * measuring locks those people out with no way to tell it happened. See
   * `appcheck.ts`.
   */
  APP_CHECK_ENFORCED?: string;
  /**
   * Shared secret in the store notification URLs, so only the stores can post
   * to them. Play's Pub/Sub push and Apple's notification endpoint both accept
   * an arbitrary URL, so the secret rides in the path.
   */
  STORE_NOTIFY_KEY: string;

  // ---- bindings ----
  /// Optional: absent until R2 is enabled on the account and the binding is
  /// uncommented in wrangler.toml. `/photos` reports that plainly rather than
  /// throwing, because a missing photo is not worth failing a logged meal over.
  PHOTOS?: R2Bucket;
}
