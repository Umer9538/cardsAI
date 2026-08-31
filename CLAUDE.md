# Carbsai

Flutter app: AI-powered nutrition tracking from a food photo. iOS + Android.
Firebase project `carbsai-8cca8`, bundle id `com.carbsai.app`.

The UI is a 1:1 build of a 47-frame Figma design (channel `jisthivv`). **The design
file is the source of truth for the UI.** The product spec in `PRD-CARB-COUNTER.md`
describes a different, carb-first product and is currently a *v2 document* — do not
implement from it without asking.

## Commands

```bash
flutter analyze                          # must stay at "No issues found"
flutter test                             # render + navigation + overflow
flutter test test/foo_test.dart          # single file
flutter run --dart-define=WORKER_URL=https://carbsai-api.<sub>.workers.dev
flutter run --dart-define=BACKEND=local  # on-device only, no network

cd workers && npm run typecheck          # typecheck the backend
cd workers && npx wrangler deploy        # deploy it
cd workers && npx wrangler tail          # per-scan cost and latency land here
firebase deploy --only firestore:rules
```

## Architecture

```
lib/
├── main.dart                 splash → onboarding → auth → MainShell, off authStateProvider
├── app/main_shell.dart       IndexedStack of 4 tabs; Scan pushes a route, it is not a tab
├── core/
│   ├── app_config.dart       AppBackend.local | .firebase
│   ├── design/               DesignCanvas, DesignImage  ← read before writing any screen
│   ├── models/               Nutrition, FoodItem, Meal, DailyLog, DietPlan, UserProfile, …
│   ├── providers/            all Riverpod wiring, and the backend switch
│   ├── repositories/         abstract contracts — the only thing screens see
│   └── theme/                AppColors, AppTypography
├── data/
│   ├── local/                JsonStore-backed repositories + SeedData
│   ├── firebase/             Firebase Auth and Firestore
│   └── worker/               Worker endpoints + the R2 photo client
└── features/<feature>/
    ├── data/                 feature-specific services (e.g. ImageCapture)
    └── presentation/         screens, controllers, widgets

workers/src/                  the backend, on Cloudflare Workers (TypeScript)
├── index.ts                  router; every failure leaves as a callable error
├── auth.ts                   verifies the Firebase ID token — the trust boundary
├── google.ts                 service-account OAuth token (what the Admin SDK did)
├── firestore.ts              Firestore over REST: values, transforms, transactions
├── identity.ts               Identity Toolkit admin — read email, set verified
├── scan.ts                   analyzeMeal — quota, OpenAI call, cost log
├── otp.ts / subscription.ts / rewards.ts / photos.ts
├── prompt.ts                 the system prompt, versioned
└── schema.ts                 the strict JSON schema + sanitizer

functions/                    SUPERSEDED by workers/. Kept for reference only —
                              nothing builds or deploys from it.
```

### The scan pipeline

`app → analyzeMeal (Cloudflare Worker) → OpenAI → strict JSON → app`

The app never holds an API key; that is the entire reason the server leg exists. The
key lives in a Worker secret (`wrangler secret put OPENAI_API_KEY`).

**Why Cloudflare and not Cloud Functions.** Spark blocks outbound calls to any
non-Google host, and OpenAI is one — so `analyzeMeal` could not be deployed without
upgrading to Blaze. Moving the server leg to a Worker removes that requirement
entirely. Firebase is still the system of record: Auth issues the tokens the Worker
verifies, Firestore holds every document, and the Worker reaches both over REST with a
service-account token — the same authority the Admin SDK had, including bypassing
security rules. `firestore.rules` is unchanged. See `workers/README.md`.

The client still calls these through `cloud_functions`, using `httpsCallableFromUri`
(`workerCallable` in `data/worker/worker_endpoints.dart`), so the SDK keeps attaching
the ID token and every error-message translation in the repositories keeps working.
The Worker's half of that bargain is speaking the callable wire protocol exactly.

The provider is **OpenRouter** by default, over **Chat Completions**. The Cloud
Function used OpenAI's Responses API; OpenRouter exposes Chat Completions only, and
nothing the pipeline depends on is lost by moving — strict `json_schema` structured
outputs, reasoning effort and image input are all on it, including the ordering
property that makes `observations` work. It is also the more portable of the two:
Chat Completions reaches OpenAI directly as well, so switching provider is a
`config/scan.baseUrl` change rather than a rewrite.

Two parameters differ between the two providers and are commented at their use site:
OpenRouter takes `reasoning: {effort}` where OpenAI direct takes a top-level
`reasoning_effort`, and model ids need the organisation prefix (`openai/gpt-5.6-luna`)
on OpenRouter but not on OpenAI. These are reasoning models either way, so they
**reject `temperature`** and none is sent. Reasoning tokens are billed as output and
count against `max_tokens`, so it has to cover both the thinking and the answer.

`provider: {require_parameters: true}` is sent so OpenRouter only routes to endpoints
that actually honour strict structured outputs. Without it a request can fall through
to a provider that treats the schema as a suggestion, which then fails as unparseable
JSON rather than as a clear error.

**Strict** structured outputs mean the response cannot come back unparseable. Three
rules, each a 400 rather than a silent degradation if broken: every key in
`properties` must also be in `required`; `additionalProperties: false` on every
object; optionality is a nullable type, never omission. That is why
`clarifying_question` is `["string", "null"]` *and* required. Strict mode also
enforces `minimum`/`maximum`, so the physical bounds live in the schema and a
decimal-place slip is rejected at generation.

Base URL, model, reasoning effort, prices, quota and image detail come from the
`config/scan` Firestore document, falling back per-field to `DEFAULTS` in `scan.ts` —
the model and now the provider are switchable without an app release, which the PRD
requires.

Cost in the scan log prefers **the provider's own reported figure**: OpenRouter
returns `usage.cost` on every response, and that is what was actually charged. The
per-MTok constants are only a fallback for a provider that reports nothing, and
`costReported` on each scan record says which of the two produced the number — so a
stale price table can no longer quietly corrupt the cost history.

### What the prompt is built on

Published evaluations, not intuition. Best-in-class vision models on food photos, as
of 2026 (MAPE): **weight ~36%, energy ~36%, fat 42–52%, carbs 48–73%, protein ~61%.**
Calories — the number this UI leads with — are among the most reliable; protein is the
worst. Four findings shape `prompt.ts`, and each is commented at its use site:

1. **Model choice dominates.** One study attributed ~99.6% of accuracy variance to
   architecture, with prompt effects not significant after correction. **If results
   disappoint, change `config/scan.model` before rewriting the prompt.**
   `openai/gpt-5.6-luna` is the default; `openai/gpt-5.6-terra` is the accuracy
   upgrade. (Drop the `openai/` prefix when pointing `baseUrl` at OpenAI directly.)
2. **Systematic underestimation that worsens with portion size** — measured bias
   slopes of −0.23 to −0.50. The prompt pushes back explicitly on large portions.
3. **Weight first, then composition.** Deriving macros from an estimated weight
   against per-100g values beats guessing them off the picture, which is where
   protein and carbs lose most of their accuracy.
4. **Scale references work** — models demonstrably use surrounding objects, so the
   prompt names plate rims, forks, mugs and cans with dimensions.

`observations` is the **first** field in the schema on purpose. Strict mode emits
fields in schema order, so a free-text field at the top is chain-of-thought inside a
structured output — the model reasons before it commits to a number. **Reordering it
is a silent accuracy regression.** It is logged to each scan record, which is the
fastest way to see why a bad estimate went wrong.

`sanitize()` is defence in depth behind the schema bounds: it fixes what a schema
cannot express (fibre ≤ carbs) and flags gross energy-vs-macro mismatches by the
Atwater factors. Anything it corrects drops to `low` confidence rather than being
silently "fixed".

Quota is reserved *before* the model call and refunded on failure. Checking after
would let ten concurrent scans all pass against the same stale count.

**No eval set exists yet.** None of the above has been measured on this app's own
prompt. The scan log records model, prompt version, tokens, cost and the model's
own observations per call, so the plumbing is there — the labelled photos are not.

State is **Riverpod 3**. Note `AsyncValue.value` — `valueOrNull` was removed in 3.x.

### Email verification (our own OTP)

Firebase's built-in email verification is a **link**, which the artboard's six-box
screen cannot express. So the codes are ours: `sendEmailOtp` / `verifyEmailOtp` in
`workers/src/otp.ts` mint, email and check them, then set `emailVerified` on the
Firebase user — so that flag stays the single source of truth.

Mail goes out over an **HTTP email API**, Brevo by default (300/day free forever).
The Cloud Function version used plain SMTP via nodemailer, chosen so any provider
would work; Workers cannot open an SMTP connection, so that intent is preserved
instead by keeping the entire provider surface inside one function in
`workers/src/email.ts` — swapping to Resend, Postmark or Mailgun means editing one
`fetch` and nothing else.

Codes are generated with `crypto.getRandomValues` and **rejection sampling**, not
`% 1_000_000` — the modulo would make low codes very slightly likelier, which is the
kind of bias that makes a six-digit space smaller than it looks.

Security properties, none of which are optional:

- The code is stored as an **HMAC keyed by `OTP_PEPPER`** and bound to the uid. A
  bare hash would be pointless — there are only a million six-digit codes, so a
  database leak would be brute-forced instantly. The pepper is not in the database.
- Codes are `crypto.getRandomValues`, never `Math.random`.
- Compared with `timingSafeEqual`.
- 10-minute expiry, 5 attempts, then burned. Single-use — deleted on success.
- Resend is throttled to 1/minute and 5/hour, because the address being emailed is
  not necessarily the caller's.
- The plaintext code is never written to Firestore and never logged.
- `users/{uid}/private/**` has **no rules match on purpose** — being able to read the
  attempt counter, or delete the document to reset it, would defeat the brute-force
  limit. It falls through to the catch-all deny; only the Admin SDK reaches it.

`verifyCode` calls `user.reload()` afterwards, or the ID token keeps reporting
`emailVerified: false` for up to an hour.

### Monetisation

Two revenue paths, both gated on one flag: `isPremiumProvider`.

**Ads — AdMob, rewarded + app-open only.** No banners (the artboards reserve no
space) and no interstitials (they fight the ten-second logging loop the app is built
around). Premium accounts get `NoAdsService`, so the SDK is never initialised for them
— not merely hidden.

- Ad unit ids default to **Google's test units** and come from `--dart-define`
  (`ADMOB_REWARDED_ANDROID` etc). The **application** id is separate, lives in
  `AndroidManifest.xml` / `Info.plist`, and the app **crashes at start-up without
  it** — both currently hold the test application id.
- Never develop against live units. Tapping your own ads is invalid traffic and
  AdMob suspends accounts for it.
- UMP consent runs before any ad request, with an 8s timeout and non-fatal failure —
  no consent means non-personalised ads, which beats an app that will not start.
- App-open shows on resume only, never on first launch, with a 15-minute cooldown
  and a 4-hour ad TTL.

**Rewarded ads pay in scans.** Watching one calls `grantBonusScans`, which writes
`bonus` on the quota document the scan pipeline already reads. The offer appears in
the scan-result error overlay when the quota runs out, alongside "Go Premium", and
retries the failed scan automatically after granting.

> `grantBonusScans` trusts the client's claim that an ad was watched. That is
> acceptable only because the payout is **hard-capped** at 5 ads/day with a 30s
> cooldown, so the worst case is a few cents. The real fix is AdMob **Server-Side
> Verification**, which needs live ad units to configure. **Do not raise those caps
> before SSV exists.**

**Purchases — `in_app_purchase`, not RevenueCat.** `StoreSubscriptionRepository`
drives the store sheet; `FirestoreSubscriptionRepository` reads entitlement;
`StoreBackedSubscriptionRepository` composes them. The split is the point: the store
is the only thing that can take money, the server the only thing that can grant
entitlement, and neither does the other's job.

Two things are **not done** and are marked in the code:

1. **`validateReceipt` does not validate.** It grants on request. The Play and Apple
   API calls that replace it are named in `workers/src/subscription.ts`, and a
   Worker *can* make them — the Spark plan could not.
   **Do not ship as-is — it hands premium to anyone who calls it.**
2. **No store server notifications.** A lapsed or refunded subscription stays active
   until `renewsAt` passes. Needs an HTTP endpoint per store.

Prices must come from the store once products exist — `_merge()` already does this.
Hardcoded "$4.99" shown to someone paying in another currency is a rejection.

### The backend seam

Screens depend only on the interfaces in `core/repositories/`. `core/providers/providers.dart`
picks the implementation from `backendProvider`. To add a backend, write the classes and
extend that switch — no screen changes. `main()` falls back to `local` if Firebase fails
to start, so a missing config file degrades instead of crashing.

Firestore layout — everything under `users/{uid}`, so the rules are one ownership check:

```
users/{uid}                    profile
users/{uid}/meals/{mealId}     the diary
users/{uid}/plans/{planId}     the catalogue, copied per user (see the note in the file)
users/{uid}/notifications/{id}
users/{uid}/prefs/notifications
```

`Meal.eatenAt` is stored twice — an ISO string in the model JSON, and an `eatenAtTs`
Timestamp beside it. Only the Timestamp is range-queryable; the string keeps
`Meal.fromJson` unchanged. Keep both in sync when writing.

## The DesignCanvas convention — read before touching any screen

Every screen is laid out on the design's own **428 × 926** artboard coordinate
system, as `Positioned` children of a `Stack`, using **raw Figma numbers**.
`DesignCanvas` maps that artboard onto the device with a single transform.

```dart
DesignCanvas(
  background: AppColors.background,
  height: contentHeight,        // > 926 when content runs past the artboard; canvas scrolls
  children: [
    Positioned(left: 20, top: 71, width: 388, height: 36, child: ...),
  ],
)
```

Rules:

- **Use the Figma number verbatim.** If a value here disagrees with the Figma
  inspector, that is a bug in the code. Do not "tidy", round, or convert to
  relative units — that severs the link to the design file.
- **`DesignFit.fit`** (default) scales by width, caps at 1.15× on tablets, and
  scrolls when taller than the viewport. Use for anything with a form field or a
  bottom-anchored button.
- **`DesignFit.cover`** crops the overflow. Only for bleed artwork with content
  safely mid-frame (splash, onboarding). Never with a bottom-anchored control —
  at 375×667 it pushes anything below y≈760 off-screen.
- **Content taller than 926**: set `height:` from the content and let it scroll.
  Pin the bottom nav / CTA to the *viewport* in a sibling `Stack`, not the canvas,
  so it does not scroll away. See `home_screen.dart` and `scan_result_screen.dart`.
- **Overlays and dialogs go *inside* the screen's own `DesignCanvas`**, so they
  share one transform. A separately-positioned overlay drifts out of register once
  the canvas is scaled. See `review_summary_screen.dart`.
- **`DesignImage` width/height = exported pixels ÷ 3**, not the node's bounding
  box. Figma clips exports at the frame edge and grows them to include drop
  shadows, so the two disagree often enough that using the bbox misplaces artwork.
- `DesignImage` returns a `Positioned` and must be a direct `Stack` child. Wrapping
  it in `Opacity` throws "Incorrect use of ParentDataWidget" — use its `opacity`
  parameter instead. That error still renders plausibly, so it survives a pixel diff.

### Screens the design does not have

Two things the app needs that no artboard covers. Both are built from components the
design does define, so they read as part of it rather than bolted on.

- **The day's meals, on Home** (`_MealsSection` + `MealCard`). Without it the diary is
  write-only: you could log a meal and never see it again, and tapping a day in the
  calendar changed nothing visible. It sits between the macro cards and Diet Plan, and
  everything below shifts down by its height — so `contentHeightFor(mealCount)` is a
  function now, not a constant. Long press removes a meal, behind a confirmation.
- **Portion controls on each scanned food** (½× ¾× 1× 1½× 2×). The PRD makes this part
  of the core loop, and it matters more than it looks: an AI estimate that cannot be
  corrected silently poisons the day's total. Factors apply to the **originally
  analysed** item, not the current value, so ½× then 2× returns to where it started
  rather than compounding. The row always renders, even in a preview with no
  controller behind it, so the card has one height everywhere and the list geometry
  cannot drift out of step with it.

- **Describe a meal in words** (`DescribeMealScreen`). The PRD's must-have fallback:
  photos fail in restaurants, in bad light, and for anything already eaten. Same
  pipeline, text-only, roughly a tenth of the cost. Tappable examples, because an
  empty text box is the main reason this kind of input goes unused.
- **Search the food database** (`FoodSearchScreen`). The path that always works: no
  camera, no model, no quota, no cost — which makes it the honest option once someone
  has used up their scans.
- **Barcode scanning** (`BarcodeScannerView`, `mobile_scanner`). Restricted to the
  symbologies actually printed on packaging (EAN/UPC), which speeds detection and
  stops a QR code on a menu being read as a product.
- **Week navigation** — swipe the calendar card to move back a week. The only way into
  history; the diary does not go forward.
- **The streak**, beside the greeting, hidden below two days — "1 day streak" is a nag,
  not an achievement.

Reached from the scanning screen's empty strip below the shutter, which is the only
place the design leaves room for them.

### Barcode and search do not use the model

Both go to **Open Food Facts** (`OpenFoodFactsRepository`) rather than the scan
pipeline. A barcode identifies a product exactly and a search is someone telling us
what they ate — guessing at either would be worse *and* billable.

It needs no API key, so unlike the photo pipeline there is nothing to hide behind a
Cloud Function: the client calls it directly, and **both paths work on the free
Firebase plan and in both backends**. Coverage is crowd-sourced — excellent for
packaged goods, patchy for loose produce — so a missing product is a normal outcome,
not an error, and the UI says so.

Two packages cannot hold the same camera at once, so selecting barcode mode
invalidates `cameraSessionProvider` to release the photo camera before the reader
starts. That is why switching modes takes a beat.

Still missing: nothing from this list — but the streak is the only History surface, so
there is no calendar or per-day detail beyond swiping the week strip.

### Where fidelity was traded for usability

Each of these was found by running the app on a real device, and each is a place the
artboard is followed *less* closely on purpose. Do not "restore" them.

- **`resizeToAvoidBottomInset: true` on every screen with a text field.** The design
  pins the submit button near the bottom; with the viewport not shrinking, the
  keyboard covered it completely and there was no way to submit a form without first
  dismissing the keyboard. Letting the viewport shrink makes `DesignCanvas` taller
  than its space, which turns it into a scroll.
- **Diet card photos fill their card** (`BoxFit.cover` into the full 220pt) instead of
  drawing at the short height Figma's clipped export provides. `DietPlan.imageHeight`
  is now unused by the card. The honest rendering left a black void over most of the
  card.
- **Home's canvas is 72pt taller than the artboard's content**, so the last row is not
  flush against the screen edge under the system gesture bar.
- **Analysis scrolls** so its Macro Distribution card clears the floating tab bar —
  on the artboard the percentages sit behind it.
- **The "Payment Method" settings row is labelled "Subscription"**, matching the
  screen it opens.

### Known Figma-vs-Flutter divergences (documented in-file; do not "fix")

- **Borders**: Flutter draws a `Border` *outside* the padding box, Figma strokes
  *inside*. Card insets are therefore 19, not 20. Honouring 20 makes every card 2pt tall.
- **Blur**: Figma's `BACKGROUND_BLUR radius` is not a Skia sigma. The scan
  viewfinder uses sigma 15 against a reported radius of 91 — calibrated against the
  render, not derived.
- **Gradients**: a Figma fill can carry node-level opacity *on top of* its stops.
  The viewfinder wash is white 20%→100% at 50% node opacity = effective 0.1→0.5.
- **Character-level style runs**: Figma stores per-character overrides in
  `styleOverrideTable`, which a node's top-level `fills` does not reveal. Plan prices
  ("$4.99/Month") and footer links ("Don't have an account? **Sign Up**") both rely on
  this — the action run is `#FF5A16`, not the white the node reports.

### Artboard numbers that were mock data

Several exports had their values **baked into the raster** while the screen also drew
the same text on top — invisible in a pixel diff because they overlapped. Those are
now drawn widgets, and the rasters are unused:

- `calorie_gauge.png` → `CalorieGauge`. Geometry measured off the export's alpha
  channel: centre (326, 338), centreline radius 236, stroke 82, in its own 3x space.
- `bar_carbs.png` / `bar_protein.png` → `MacroBar`.
- `chart_calorie_trends.png` / `chart_summary.png` → `CalorieTrendsCard` /
  `MacroDistributionCard`.

The artboard's Home figures were also not self-consistent (1672 kcal left of a 2000
goal is 328 consumed, which cannot also be 140g carbs + 60g protein = 800 kcal). Home
now computes from the diary, **so a render diff against that artboard differs in the
numbers, and should.**

## Theme

- `AppColors` values are **exact sRGB conversions of Figma fills**. Do not adjust them.
- `AppTypography` — Space Grotesk, bundled as **static instances at 400/500/600/700**.
  The variable font's default instance is wght=300, which made the engine synthesise a
  fake bold for SemiBold (~20% too much ink vs the reference). Never swap back to the
  variable font.
- One design string specifies Satoshi (auth validation messages). Deliberately
  substituted with Space Grotesk rather than bundling a second family for two strings.

## Tests

`test/support/design_render.dart` renders a screen at 428×926 and writes a 3× PNG to
`build/<name>_actual.png` for diffing against a Figma export. `designScope()` supplies
a `ProviderScope` over empty preferences and pins `backendProvider` to `local`.

Two hard-won constraints in that harness — do not undo either:

- **`toImage`/`toByteData` must run inside `tester.runAsync`.** `toByteData` waits on
  the engine's raster thread; awaited in the test's fake-async zone it never completes
  and the file hangs until killed. `toImage` returns anyway, so it looks fine until the
  last line.
- **One render per file.** Two `runAsync`/`precacheImage` passes in one file deadlock
  the second. `flutter test` isolates files in separate processes. Do not consolidate.

Prefer bounded `pump()` calls over `pumpAndSettle()` in render tests — any screen with
a progress indicator never settles.

`navigation_flow_test.dart` walks the app as a user. `responsive_overflow_test.dart`
guards small/large viewports.

## Current state

Real: navigation, auth (Firebase email/password, with readable error mapping), the
diary and its totals, plans and favourites, notifications and preferences, profile,
the Analysis charts, camera capture, gallery pick, persistence, offline — and **the
scan pipeline**, deployed at `https://carbsai-api.quranai.workers.dev` and verified
from a device: photo capture → Worker → OpenRouter → 7 items in 8.6s for $0.0012.

That run exercised the whole stack: `httpsCallableFromUri` attaching the ID token,
JWKS verification of it, the service-account OAuth token, the Firestore REST client,
the transactional quota reserve, a strict `json_schema` response, and the scan-log
write.

**Not yet real:**

- **Meal photos are stored nowhere.** `/photos` returns "photo storage is not
  configured yet" until R2 is enabled and the binding uncommented — see
  `workers/README.md`. The upload failure is swallowed by design, so the meal logs
  and the diary renders from the local file. Enabling R2 asks for a payment method,
  which is the thing this backend exists to avoid, so it is deliberately parked.
- **Email verification codes** need `EMAIL_API_KEY` / `EMAIL_FROM` set on the Worker.
  Untested; the screens are unreachable in `main.dart` anyway.
- **`grantBonusScans` and the subscription routes are untested** against the live
  Worker. They share the auth and Firestore paths a scan already proved, so the
  remaining risk is in their own logic rather than the plumbing.
- On `BACKEND=local` you still get `LocalScanRepository`, which waits ~2.2s and
  returns the same three foods whatever you photograph.
- **No eval set yet.** The PRD wants ≥150 labelled photos with an accuracy bar before
  UI polish. Nothing has measured this prompt's accuracy.
- **In-app purchases fail** until subscription products with ids `monthly` and
  `annual` exist in Play Console and App Store Connect. Expected, not a bug.
- **Ads serve Google's test creatives** until real unit ids are supplied.
- **Email verification is parked.** Sign-up goes straight into the app, and forgot
  password just confirms that Firebase's reset *link* was sent. `VerificationScreen`
  and `ResetPasswordScreen` are built and tested but not reachable — both need the
  email-code function. Restoring them means restoring two pushes in `main.dart`.
- **Google / Apple sign-in** throw `provider-unavailable`. Email/password works.
- **Email verification codes need `EMAIL_API_KEY` set and the Worker deployed.**
  On `BACKEND=local` any six digits pass, by design — there is no mail server.
- **Meal photos need an R2 public base URL.** They upload to R2 through the Worker as
  soon as it is deployed, but `PHOTO_PUBLIC_BASE` must name a custom domain on the
  bucket before a durable URL comes back. Until then the upload succeeds, the URL is
  null, and the diary keeps showing the local file.
- The splash logo `assets/images/splash/logo_nutriai.png` is still the **old NutriAI
  wordmark** and needs re-export under the Carbsai name.

## Firebase setup still needed

1. **Authentication → Sign-in method → enable Email/Password.** Until then sign-in
   fails with `operation-not-allowed`; the app surfaces that as a message saying so.
2. **Firestore → create the database** (production mode; the region is permanent).
3. `firebase deploy --only firestore:rules`
4. Nothing else on Firebase. **Blaze is not needed** — the server leg is on
   Cloudflare, and Cloud Storage is replaced by R2. `storage.rules` is now unused;
   what it enforced (own subtree, 5MB, `image/*`) is enforced in
   `workers/src/photos.ts`, because R2 has no rules layer.

## Backend setup (Cloudflare)

Full checklist in `workers/README.md`. In short: create the R2 bucket, generate a
Firebase service-account key, set five secrets, `wrangler deploy`, then run the app
with `--dart-define=WORKER_URL=...`. Without that define the app throws a `StateError`
naming the fix, rather than failing as a mysterious network error.

`.firebaserc` pins the project; `flutterfire configure` writes `firebase.json` but not
that file, which is why the CLI reported "no active project" before it existed.

## Conventions

- Screen doc comments name the Figma frame and node id, e.g.
  `/// Home — Figma frame \`23_Home\` (2002:1388).` Keep this up when adding screens.
- When a value deviates from the design, **say why in a comment**. The existing
  comments are the record of which deviations are intentional.
- Multiple Figma frames that are states of one screen (default/error/filled/with-dialog)
  are built as **one screen with state**, not as separate layouts.
- Screens take an optional override parameter (`plans`, `items`, `result`) that shadows
  the provider, so tests and previews can pin data. Null means "read the real one".
- Repositories throw `RepositoryException` with a sentence a person can act on.
  Screens never see a `FirebaseAuthException`.
- Private widgets are `_PascalCase` in the screen file; anything shared across screens
  moves to that feature's `presentation/widgets/`.

## Two bugs worth not reintroducing

**`DesignFit.cover` did not scale.** `FittedBox(BoxFit.cover)` sizes itself to its
child and then scales within what it was given, which left the canvas at its natural
428pt width on any wider viewport, pinned left, with a strip of bare background down
the right edge exactly `viewport - artboard` wide. Invisible on splash and onboarding,
whose background matches their artwork; glaring on the camera, where it read as the
preview failing to fill the frame. Now scaled explicitly, like the `fit` branch.

**Firestore writes were awaited.** `set()` resolves when the *server* acknowledges,
not when the local cache has it — so `ProfileRepository.save` put a server round trip
in front of the sign-up button, which sat spinning for ~40 seconds. The local write is
synchronous and the SDK guarantees delivery, so there is nothing to wait for. Do not
re-add the `await`.

## Android package name

`MainActivity` lives at `android/app/src/main/kotlin/com/carbsai/app/MainActivity.kt` and
must declare `package com.carbsai.app`, matching the Gradle `namespace`. The manifest
refers to it as `.MainActivity`, which resolves against that namespace.

Changing the namespace without moving the Kotlin source builds fine and then crashes on
launch with `ClassNotFoundException: Didn't find class "com.carbsai.app.MainActivity"` —
there is no compile-time link between the two.

## Housekeeping

- **No git repo.** Nothing is version-controlled. Worth fixing.
- macOS is registered in Firebase under the old `com.example.carbsai` id. Harmless
  while the targets are iOS and Android.
