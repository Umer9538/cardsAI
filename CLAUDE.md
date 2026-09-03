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

**Ads stay, but they cannot be shipped carelessly.** The launch research argued for
deleting AdMob outright; that was overruled, and the four things that made ads a launch
blocker are fixed instead:

- **One scan per rewarded ad, not three.** A scan costs ~$0.0012. A rewarded impression is
  ~$0.016 at a US eCPM near $16 — thirteen scans — but ~$0.001 at the ~$1 CPM these markets
  see, which is 0.83 of one. At three scans an ad, **every rewarded view in Pakistan or India
  cost more than it earned.** `AdConfig.scansPerRewardedAd` and `rewards.ts` `RULES.scansPerAd`
  must stay in step. The Tier-2 figure is an unsourced proxy — watch real AdMob numbers before
  raising it.
- **App-open ads are pure upside** — no scan cost attached — so they are unconditional.
- **ATT is actually requested** (`app_tracking_transparency`). `Info.plist` had declared
  `NSUserTrackingUsageDescription` since ads were added and nothing ever prompted: a review
  flag, and every iOS impression served non-personalised at the low end of the eCPM range the
  whole ad case rests on. UMP first, then ATT — the consent form explains why before Apple's
  bare yes/no arrives.
- **`SKAdNetworkItems` is populated** with Google's published list (50 entries). Re-copy it
  from the AdMob quick-start when updating the SDK; it changes.
- **`AdRequest` is `const` and empty, and must stay that way.** It accepts `keywords` and
  `contentUrl`, and a nutrition app knows plenty about its user — but Apple 5.1.3(i) bars
  health data from ad targeting, and a diet, a weight or a goal is health data.

**`tool/build_release.sh` is how releases get built.** Ad ids fall back to Google's *test*
units when the defines are missing, so a release built by hand installs, runs, and earns
nothing, silently. `WORKER_URL` has no default and throws on the first scan. Neither is caught
by `analyze` or the test suite, so the script refuses to build without them — and refuses if
the ids still contain Google's test publisher, in the defines or in the manifest/plist.

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

**The same photo never gets two answers.** `ScanController._seen` caches a result
against the image path and the note. The model samples, so asking twice about one
photograph returns two numbers, and reviewers find that by accident — *"if you snap your food
twice it will give you two wildly different calorie counts"* — after which nothing the app
says is believed. This cannot make two *different* photographs of one plate agree; it
guarantees the same file never disagrees with itself, and stops a double tap spending a second
scan. Keyed on the note too, because editing the note is a request to think again.

**Rewarded ads pay in scans.** Watching one calls `grantBonusScans`, which writes
`bonus` on the quota document the scan pipeline already reads. The offer appears in
the scan-result error overlay when the quota runs out and retries the failed scan
automatically after granting — but **"Go Premium" is the primary action and the ad is the
alternative**, not the other way round. Leading with the ad puts a video between someone and
the thing they opened the app for, which is the shape reviewers of Lose It! and Cronometer
call extortion rather than a fair exchange. Running out of scans is the paywall arriving, so
the paywall is the honest first offer.

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

### Metric and imperial

`'cm'` and `'kg'` were hardcoded inside the quiz — the app's highest drop-off surface — and
roughly half the paying audience for a calorie tracker measures in pounds. Being asked your
weight in a unit you do not think in is a reason to close the app.

**Storage is always metric.** `UserProfile.heightCm`, `weightKg` and everything
`TargetCalculator` does stay in metric; `UnitSystem` only decides how a number is *shown*.
Storing whatever the user preferred would put a unit on every arithmetic site in the app and
guarantee one of them eventually forgets to convert. The sliders keep their metric range,
divisions and value too — only the caption changes.

It **defaults from the device locale** (US, LR, MM) rather than asking, and the switch lives
on the height and weight steps themselves, because that is the moment someone notices the
wrong unit and sending them to Settings then is how the screen loses them.

`formatHeight` rounds to total inches *before* taking the feet, or 5 ft 11.6 in renders as
`5′ 12″`. The test sweeps every height in the slider's range to prove it never does.

### Nothing on Home, Analysis or Diets is invented

Home and Analysis were already computed — Home off the diary, Analysis off real
`mealsBetween` ranges with real buckets. Diets was not, in two ways, and both made the
honest screens look invented by association:

- **Three plans shipped with `isMine` and `isFavorite` already true.** A brand-new account
  opened onto a My Diets tab and a Favourites tab full of choices nobody had made. An app that
  pretends you did something is the clearest signal its numbers are decoration. The catalogue
  now ships owned by no one.
- **Plan figures were absolute and unrelated to the user.** The app computed a personal target
  of 2,413 kcal and then offered a "2,000 kcal" plan beside it. `DietPlan.scaledTo` keeps the
  pattern's macro *proportions* — keto is a fat ratio, Mediterranean is a fat-to-carb ratio —
  and puts the user's own energy through it. It is applied in `providers.dart`, on all three
  plan streams, so there is exactly one path from repository to screen and no way to render an
  unscaled plan by forgetting.

**`targetsProvider` derives a missing fibre goal rather than trusting storage.** Targets are
persisted on the profile, so every account created before the fibre goal existed carried
`fiber: 0` and showed "Fibre 0g" on Home with no goal beside it, permanently. A figure the app
knows how to compute should not be absent because of when the account was made.

**The trend chart's y-axis is 52 wide, not 40.** A four-digit calorie caption did not fit the
32pt that left, and `TextPainter` answers that by *wrapping* — so "4000" drew as "400" above
"0" and the axis became a stack of half-numbers that read as extra gridlines. `_label` pins
`maxLines: 1` now, so a caption that does not fit clips where it is obvious rather than
wrapping into the row below where it looks like another caption.

### The backend seam

Screens depend only on the interfaces in `core/repositories/`. `core/providers/providers.dart`
picks the implementation from `backendProvider`. To add a backend, write the classes and
extend that switch — no screen changes. `main()` falls back to `local` if Firebase fails
to start, so a missing config file degrades instead of crashing — **in debug and profile
only.** A release build shows `_MisconfiguredApp` instead, because there the fallback is not a
degraded experience but a wrong one: `LocalScanRepository` returns the same three foods
whatever you photograph, so a shipped build that quietly landed there would invent nutrition
figures and write them to a real diary.

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

### The goal weight has a floor, and it is not negotiable

`TargetCalculator.healthyGoalFloorKg` is BMI 18.5 for the entered height, rounded up to the
next half kilo so rounding can never cross it. The goal-weight slider starts there and says so
on screen; `goalDate` returns null below it, so nothing puts a date on an underweight target.

The slider previously ran from 35 kg for **everyone**. At 175 cm that is a BMI of 11.4, and
the plan screen would then affirm it — *"On track for 35 kg by 14 March 2027."* Google Play's
Inappropriate Content policy names apps that promote eating disorders as a **removal**
category, not a rating one. The floor is checked on render as well as on input, because a
profile saved before it existed can still carry a lower number.

Like the 1200/1500 kcal calorie floors, it is presented as **this app's own guardrail, never
as clinical advice** — a silent floor is a number nobody can audit, and a cited one we cannot
source becomes its own unverifiable health claim.

### The calorie target, and the quiz that produces it

`TargetCalculator` (`core/nutrition/`) is the app's central number: the ring on Home,
the macro cards and every "remaining" figure count against it. It is the one piece of
this codebase that is a **pure function** — no providers, no clock, no I/O — which is
why it is the one piece with exact unit tests rather than a render diff.

```
Mifflin-St Jeor BMR  ->  x activity multiplier  ->  +/- goal  ->  macro split
```

Mifflin-St Jeor rather than Harris-Benedict, because it is more accurate on modern
populations and is what MyFitnessPal, Lose It and Cal AI all use. Sex enters only
through the constant (+5 male, -161 female); `other` and `unspecified` take the
midpoint, which is the honest answer to an unknown rather than a silent assumption.

Two guards are not optional, and both are tested:

- **The deficit is capped at 25% of maintenance**, not at a fixed number — 500 kcal
  off a small person is a far harsher cut than off a large one.
- **Floors of 1200 (female) / 1500 (male) kcal**, whatever the arithmetic says.

Protein and fat are set from **bodyweight** (1.8 g/kg, 0.9 g/kg) and carbohydrate
takes the remaining energy. Fixed macro percentages would give a very light person
too little protein and a heavy one more than they can use.

`OnboardingQuizScreen` collects the five inputs, and eight more besides. Five feed
the arithmetic; the rest are context, and **each one changes something the person
sees** — the plan Home features (`dietPreference` -> `_featuredPlan`), the tip the plan
screen closes on (`obstacle`), whether meal reminders are on (`wantsReminders` ->
the `mealReminders` preference). There are deliberately no questions whose answers go
nowhere: that is drop-off bought for nothing.

The engagement is in three places and all of it is cheap. The **running estimate**
appears the moment there is enough to compute one and moves as later answers land, so
the plan assembles out of the person's own answers rather than arriving at the end as
an assertion. **Selection is animated and haptic**, because a tick and a colour change
over a beat is most of what makes answering feel responsive. And the **build step** shows its
working: a sweep ring, and four lines that resolve to the real intermediate values —
`basalRate`, then `maintenance`, then the target after the goal is applied, then the
split. Those are the four things `TargetCalculator` actually does, in order, with its
own numbers. It is still theatre, since all four are arithmetic and take no time, but
theatre that is true: a number that appears instantly reads as a lookup, while one you
watch being derived reads as a plan.

**It is not in the Figma file** — the design has three marketing onboarding pages and
no quiz — but without it every account gets `UserProfile.defaultTargets`, so a
22-year-old athlete and a sedentary 55-year-old see the same 2000 kcal ring.

It is drawn **the way the artwork is**: cream ground, flat colour, a 2.5pt black
outline, and a hard offset shadow with no blur. Choosing an option presses it into the
page — the shadow collapses and the card translates by exactly the shadow's offset,
which is the whole reason the shadow is hard rather than soft. `QuizPalette` holds the
set, and the accent **changes per question**, cycling the design's own four colours, so
moving through the quiz is visibly moving rather than the same screen with new words.
The mascot appears on the plan screen and nowhere else, which is the only way a mascot
stays likeable.

This screen has been three things, and the first two are worth remembering as
mistakes. White-on-lilac borrowed from frames 02-04 read as a marketing page bolted to
the front of a black app. The app's own dark surfaces were coherent and completely
characterless. Neither used the voice the app already has — the onboarding
illustrations are 1930s rubber-hose cartoons with heavy uniform linework, pie-cut eyes
and sparkles, and the icon is a gloved avocado. **Do not "unify" this back into the
dark app palette.** It is deliberately not that.

`QuizOptions` **measures its own cards**, and tightens the gap before the cards.
Fixed heights are how the five-option activity step ended up 10pt over its box; then
clamping card height to a minimum without also tightening the gap put the six-option
diet step 20pt over the shorter box the running estimate leaves. Cards below about
50pt stop fitting two lines of text; spacing has no such floor, so spacing is what
yields.

Every step is skippable, and skipping leaves the default targets — which is exactly
what the app showed before the quiz existed. `StoreKeys.quizSeen` records that it was
dealt with either way, so a skip is not re-asked on every launch.

### Corrections are the product, not a nicety

Mining ~40,000 reviews across this category produced one finding that outranks the rest:
**correction friction, not error rate, decides a one-star review.** The same inaccuracy earns
four stars or one depending only on whether fixing it is fast and free. So:

- **`ItemEditSheet`** (`scan/presentation/widgets/`) edits a food's name, weight and all four
  macros. Reached from the scan result *and* from a meal already in the diary, because a
  correction that only works before you log is half a feature. **Never paywall it.**
- Typing a weight rescales the macros from the per-gram baseline — "it was more like 180 g" is
  a claim about the portion, not about protein — but typing into a macro field pins it, so a
  manual correction is never undone by a later weight change.
- **An edit becomes the new baseline.** `applyEdit` rewrites `_asAnalysed` and resets the
  portion factor, so a later ½× halves what the user corrected rather than what the model
  guessed. Without it, typing 250 g then tapping 2× silently discards the 250.
- **`showMealSheet`** puts the same editing on a logged meal, plus **Log again** — which
  answers the other daily complaint, *"I end up having to photo my yogurt pot every day."*
  Log again builds a new `Meal` rather than `copyWith`, because `scanId` must be **cleared**:
  two meals pointing at one scan record would make the cost log overstate how many scans ran.
- Fibre and sugar are carried through every edit untouched. The sheet does not offer them, so
  it must not silently zero them.

### The scan result surfaces what the model actually said

The pipeline returns three things the UI used to discard or bury, and each one is the
difference between an estimate you can act on and a number you have to take on faith:

- **Per-item confidence.** `prompt.ts` tells the model to use `low` freely, because a
  flagged guess is more useful than a confident wrong number — but only if the flag
  reaches the screen. `FoodItem.needsReview` was computed, documented, and never
  rendered, so a guess and a certain reading looked identical. Low-confidence items now
  carry a quiet **Check this** chip, sitting directly above the portion row that fixes
  it. Outline rather than fill: a plate of five foods can easily carry two.
- **The clarifying question**, which was drawn *underneath* the pinned CTA and could not
  be read at any scroll position. `_ctaClearance` fixes that the same way
  `AppBottomNav.clearance` does.
- **The wait.** A scan is seven to twelve seconds. It was a spinner over "Reading your
  plate…", which says waiting. It now shows the capture with a band sweeping down it
  and names the stage that is running. **Deliberately no percentage and no progress
  bar** — nothing here knows how far along the model is, and a bar that fills on a
  timer is a lie that gets caught the first time a scan runs long. The last stage
  simply holds until the result lands.

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
- **A photo from anywhere on the phone.** Selecting AI Gallery opens a chooser —
  **Photos** (camera roll) or **Files** (`file_picker`, i.e. Android's Storage Access
  Framework). Two entries because no single Android picker covers both: the system
  photo picker is media-only, and the legacy `ACTION_GET_CONTENT` path is fired with
  `startActivityForResult` rather than through a chooser, so it lands in whichever app
  is the registered default — Google Photos on most phones, with no way out of it. A
  meal photo in Downloads or synced from another app was unreachable. The chooser opens
  on selecting the tile, not on a later shutter press: the shutter is a camera control,
  and a tile that opens nothing reads as dead.
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

Neither goes near the scan pipeline. A barcode identifies a product exactly and a
search is someone telling us what they ate — guessing at either would be worse *and*
billable.

They go to **different databases**, because they are different questions:

- **Search → USDA FoodData Central**, through the Worker's `searchFoods` route.
  FDC holds the lab-analysed reference foods, and it is already what `prompt.ts`
  tells the model to match its composition against — so a searched food and an
  estimated one now agree on what chicken breast is. It needs an API key, which is
  why it sits behind the Worker: a key in the binary is a key that has been
  published.
- **Barcode → Open Food Facts** (`OpenFoodFactsRepository`), straight from the
  client. It is the stronger database for packaged goods, which is exactly what a
  barcode identifies, and it needs no key so there is nothing to hide.

`searchFoods` filters to `Foundation, SR Legacy, Survey (FNDDS)` and **excludes
Branded**. That is not a detail: Branded is by far the largest FDC dataset and
dominates the ranking, so unfiltered, "grilled chicken breast" returns a frozen
dinner and a deli pack before it returns chicken. Packaged goods are reachable by
barcode instead. Entries with no energy figure are dropped — some Foundation records
genuinely have none, and a 0 kcal food in a diary is worse than no result.

Every FDC dataset here reports **per 100g**, so that is the portion offered; the
result screen's ½×–2× control takes it from there.

### The food catalogue is mirrored into Firestore

Searching FDC live was slow (1-5s) and unreliable, so the generic datasets are
**copied into a shared `foods` collection** and searched from there. The client
queries Firestore directly — one round trip instead of two, and Firestore's offline
cache answers a repeat search with no connection at all.

`workers/src/catalogue.ts` does the sync, driven by a **daily cron** (`17 4 * * *`)
and by `POST /syncFoods`, which is gated on a `SYNC_KEY` header rather than a user
session — it is an operator action, and a signed-in user triggering tens of thousands
of Firestore writes is not a feature. Progress lives in `config/foodSync`, so each
run takes a slice and resumes rather than restarting; FDC has no "changed since"
filter, so the walk wraps around and re-reads continuously.

Daily is deliberate and 20-second polling was rejected: Cloudflare's cron minimum is
one minute, FDC publishes a few times a year, and 20s would be 4,320 calls a day
against a 1000/hour key that real searches also draw on. Nothing is lost — search
reads Firestore, so a sync is visible to every client the moment it lands.

**Nutrients come back in two different shapes**, and this cost a full debugging pass:

```
search      { nutrientId: 1008, nutrientNumber: "208", value: 135 }
list/full   { number: "208", amount: 135 }            <- no id at all
```

The *number* is the only key present in both, so that is what both extractors key on.
Keying on the id worked against search and silently matched nothing against list —
storing zero foods out of 394 that every one of which had complete nutrition.

Search has **no full-text index**, because Firestore has none. Each food stores a
`tokens` array — its description as lowercase words over two characters — and the
client queries `array-contains-any`, then ranks the candidates itself in
`FirestoreFoodRepository._score`. Two consequences:

- **Whole words only, no prefixes.** Indexing prefixes would let "chick" find
  chicken, but a three-letter token matches thousands of documents and
  `array-contains-any` returns an arbitrary page of them rather than the best — so a
  partial word would make results actively worse.
- **The query is ordered by `rank`**, and that is what makes search usable rather
  than a nicety. `array-contains-any` returns an *arbitrary* page, so the first
  attempt at this ranked 60 random foods that happened to share a word: "olive oil"
  came back as OLIVE GARDEN lasagna and "banana" as banana split, because "Oil,
  olive" and "Bananas, raw" were never in the page for the ranker to see. `rank` is
  0 for Foundation, 1 for SR Legacy, 2 for Survey (FNDDS), so the generic reference
  foods are pulled in first and the text scoring chooses between them. It needs the
  composite index in `firestore.indexes.json`.
- Survey (FNDDS) is not junk — "Chicken breast, grilled without sauce" lives there —
  it simply also holds every restaurant dish, so it sorts last.
- `tokenize` exists **twice**, in `catalogue.ts` and `FirestoreFoodRepository`. They
  must agree: a token written by one and not produced by the other is a food that can
  never be found.

**Firestore's free-tier quotas are the binding constraint here**, and they were
discovered the hard way — a sync died mid-catalogue with
`429 RESOURCE_EXHAUSTED` on commit:

| | Free/day | This costs |
|---|---|---|
| Writes | 20,000 | a full sync is **~13,300** |
| Reads | 50,000 | a search is up to **60**, so ~800 searches/day |

Hence the **weekly** cron, not daily: a daily full walk would spend two thirds of
the write budget every day, competing with the writes real users make. And the read
figure is shared with the diary, plans and everything else, so `_candidates` is a
quota decision as much as a quality one.

If search volume ever makes that ceiling real, the collection is the one part of this
app that does not belong in Firestore — Cloudflare D1's free tier is 5M row-reads and
100k writes a day, and its FTS5 index would also fix the ranking problem below
outright.

Search falls through three layers, each only when the one before has nothing:
Firestore mirror → Worker/live USDA → Open Food Facts. Barcode skips straight to Open
Food Facts.

**FDC's search endpoint is genuinely flaky**, and it is not our request: roughly half
of otherwise-identical calls return HTTP 400 carrying an *nginx* HTML error page, and
the same query succeeds on retry. An application-level rejection would be JSON, so
this is the edge dropping requests. `searchFoods` retries five times with a short
backoff, which measured ~50% → ~8% failure at 1.0-4.7s. Do not read a failing query
as a bug in the filter — it was noise both times it looked like a pattern.

`WorkerFoodRepository` falls back to Open Food Facts when the Worker cannot answer —
an unset key, FDC's 1000/hour rate limit, or an outage. Search is the path that is
meant to always work, and is what someone reaches for once their scans have run out,
so it degrades to a worse database rather than to a dead end. On `BACKEND=local`
Open Food Facts serves both, which keeps the app runnable offline with nothing
configured.

Two packages cannot hold the same camera at once, and **invalidating
`cameraSessionProvider` was not enough on its own** — that was why barcode scanning never
worked at all. `_Preview` *watches* that provider and was rendered unconditionally, so an
invalidated provider with a live watcher rebuilt immediately and re-acquired the photo camera
in the same frame it was released; `mobile_scanner` never got a device to open.

The release has to be a real one, which means two things. `_Preview` is not rendered in
barcode mode, so nothing is left watching. And because neither package releases synchronously
— `CameraController.dispose` and the scanner's teardown are both futures — `_switching` holds
a beat during which **neither** camera is on screen, in both directions. That is the "switching
modes takes a beat": deliberate, not latency to optimise away. The timer is cancellable and
cancelled in `dispose`, or it outlives the screen and fails every test that touches it.

The reader is drawn **full-bleed, under the blur**, exactly where `_Preview` goes — not inside
the window. `_WindowCutout` knocks the window out of the blur, so one texture gives a blurred
surround and a sharp window. Drawing it above the blur instead left the whole screen black
around the window, because the blur had nothing to blur. This is still one texture; it is not
the two-previews mistake that comment warns about.

**The viewfinder's motion is information, not decoration.** Three states on `_Viewfinder`,
each answering a question the screen could not answer before:

- **sweeping** — a green line travels the window while the barcode reader is live. Nothing
  said the reader was running: you pointed a still, silent rectangle at a packet and hoped.
  The line has a trailing gradient because the trail is what reads as *direction*, and it runs
  top-to-bottom and restarts rather than ping-ponging, because that is what a scanner does.
- **waking** — the brackets breathe through the camera handoff, so the beat where neither
  camera is mounted reads as the app working rather than as a dead black window.
- **confirmed** — the brackets snap in 6pt and turn green for 220ms on a read, with a haptic,
  before the result screen pushes. Every supermarket scanner beeps; ours changed screens and
  left you to infer that anything had happened.

All of it is suppressed under `MediaQuery.disableAnimationsOf` — a repeating sweep over most
of the screen is exactly what that setting exists to stop, and `scan_motion_test.dart` proves
it. **A screen with a repeating animation never settles, so `pumpAndSettle` on it hangs
until the timeout**; `navigation_flow_test` uses bounded pumps for the same reason the render
harness does.

The shutter answers the finger (`pressed`) as well as the capture (`busy`). It used to react
only to `busy`, which is set *after* the capture starts — so on a slow camera the press
produced nothing for a beat and read as a dead control.

**The reader restarts when it is uncovered.** `_openResult` *pushes* the result screen over
the scanning screen rather than replacing it, so the scanner stays mounted underneath — and it
stops itself the instant it reads a code, because a reader that keeps firing turns one product
into a dozen lookups. Coming back therefore landed on a live widget holding a stopped camera:
a black viewfinder nothing would ever restart. `BarcodeScannerView` is `RouteAware` against
`appRouteObserver` now, stopping on `didPushNext` and restarting on `didPopNext`. Anything
else that owns a camera under a pushed route wants the same.

Barcode has no shutter — detection is continuous, so there is nothing for a button to trigger
— which left the mode with no control at all and no way forward when a code will not read.
**"Type the number"** takes the digits printed under the bars, which is the path that always
works on a scuffed label, a curved tin, or through shrink wrap. It lives in
`widgets/barcode_entry_sheet.dart` so it can be tested without the scanner plugin, which has no
platform side in a widget test.

**The app is portrait-locked**, in `main()` and in both platform manifests. Not a preference:
the artboard is a fixed 428 × 926, so in landscape the canvas scales to the short edge and
scrolls, which lays the floating tab bar across the middle of the content. Framing a plate and
logging one-handed are both portrait actions.

**A barcode scan shows the product, not a stock plate.** Open Food Facts photographs packaging,
so `FoodItem.imageUrl` carries `image_front_url` through to `ScanResult.photoPath`.
**`fields` on that API is an allow-list** — a key not named in `_fields` is simply absent from
the response, which is how the parser spent a release reading `image_front_url` out of a
document that never contained it. `debugFields` is exposed so a test asserts it. The packshot
is drawn `contain` on the app's ground and inset below the header: it is a label on white, the
header glyphs are white, and edge-to-edge "Scan" vanished into the Nutella label. Open Food
Facts serves 400px at most, so cropping it to fill would be an upscaled crop of the one thing
you wanted to see whole and on into
`Meal.photoPath` — which already rendered a URL. The result screen's hero and the diary
thumbnail both show the jar the person is holding. Null for anything the model estimated:
there the user's own photo *is* the picture.

Still missing: nothing from this list — but the streak is the only History surface, so
there is no calendar or per-day detail beyond swiping the week strip.

### Back, on a tab

The four tabs are an `IndexedStack`, not navigator routes, so there is nothing
beneath Settings for the system back gesture to pop except `MainShell` itself — the
whole signed-in app. Pressing back on any tab but Home therefore closed it.

`MainShell` wraps the stack in a `PopScope` with `canPop: _tab == AppTab.home`: back
is "up one level", and Home is the level above a tab. **On Home the gesture passes
straight through and the app closes** — no confirmation dialog and no press-twice-to-
exit, both of which are worse than the thing they prevent.

### The floating tab bar needs clearance, and it is a constant

`AppBottomNav` is pinned to the **viewport**, not to the scrolling canvas, so the
bottom `designHeight - top` = 120 artboard units of every scroll sit underneath it. A
canvas that ends flush with its content therefore has a last row that cannot be read
however far you scroll — the bar simply sits on it.

Home, Diets and Analysis each add `AppBottomNav.clearance` (140: the 120 it covers,
plus 20 so the last row clears rather than touches). They previously used three
different ad-hoc numbers — 72+24, 96, and a round 1000 — all of them short, which is
why the bar looked like it was covering content on a device. **Any new screen with the
tab bar owes the same clearance.**

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
  render, not derived. The blur is applied through a `ClipPath` that knocks the
  viewfinder window out of the screen rect (`_WindowCutout`, `evenOdd`), so it blurs
  *around* the window. It must not go back to blurring everything and drawing a
  sharp copy of the preview on top: that is two `CameraPreview` widgets on one
  controller, therefore two `Texture` widgets on one texture id, and Android does not
  reliably draw both. Where the second came up empty the window fell through to the
  blurred layer and the whole screen looked out of focus.
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

## Accessibility, and what the artboard costs

**Text scaling is clamped, and that is a limitation rather than a design.** Every child of a
`DesignCanvas` is a `Positioned` at a fixed y with a fixed height, so text that grows overlaps
the next element instead of pushing it down. `DesignCanvas.maxTextScale` (1.15) is the ceiling
the layout provably survives — `responsive_overflow_test` now renders every screen at that
ceiling *and* at 3.0 (which clamps to it), so the number is tested rather than assumed. Fixing
it properly means letting screens reflow, which means giving up the artboard convention on
each one. **Do not raise it without re-running the overflow suite.**

Finding that ceiling turned up four places where the artboard's own numbers fitted *exactly*,
leaving zero slack for any font-metric variation:

- The week-strip day cells: fixed gaps replaced with `spaceBetween`.
- Three copies of the same 388 × 128 intro card — Analysis, Diets, Premium Plans — now one
  `HeroCard` where the body takes what the heading leaves and ellipsises.
- `PlanRow`'s title had a fixed 30pt box, which is its natural height and therefore its
  ceiling. It sizes itself now, and the review-summary card — the one place with no room at
  all — wraps it in `FittedBox(scaleDown)`. That is a deliberate, contained compromise on one
  card; capping the whole app to protect it would have been the wrong trade.

**Icon-only controls must carry a `Semantics` label.** The app had 39 tappable widgets and
zero. A bare glyph with no text near it is not merely unlabelled to a screen reader — the
control does not exist. `AppTab` carries a spoken `label`, `PrimaryButton` announces itself as
a button and says "working" while busy, and the back / crown / bell glyphs are labelled;
`_OutlineIconButton` takes `label` as **required** so the next one cannot ship silent.
`accessibility_test.dart` guards it. This matters more here than for a general app, because
the launch plan markets into diabetes communities, which skew older.

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
- **Google / Apple sign-in are gone from the UI.** The repository methods still throw
  `provider-unavailable` — the providers were never configured — and a reviewer taps every
  button on the first screen, so a control that only ever errors is an Apple 2.1 rejection.
  Restoring them is not just wiring the SDKs: offering Google obliges Sign in with Apple too,
  under Guideline 4.8. Both or neither, along with the `OrDivider` that separated them.
- **Email verification codes need `EMAIL_API_KEY` set and the Worker deployed.**
  On `BACKEND=local` any six digits pass, by design — there is no mail server.
- **Meal photos need an R2 public base URL.** They upload to R2 through the Worker as
  soon as it is deployed, but `PHOTO_PUBLIC_BASE` must name a custom domain on the
  bucket before a durable URL comes back. Until then the upload succeeds, the URL is
  null, and the diary keeps showing the local file.
- **The wordmark is generated, the mascot is not.** `logo_carbsai.png` is set in the
  app's own Space Grotesk Bold with the "ai" in orange — the same treatment the old
  NutriAI mark used. The app icon is a supplied avocado mascot in the same
  rubber-hose style as the onboarding illustrations, composited onto
  `AppColors.primary`. Masters live in `assets/images/brand/`: `mascot.png` is the
  artwork cropped to its ink, and every one of the 25 platform files is derived from
  it, so a new logo means replacing one file and re-running the generation rather
  than editing icons by hand.

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

**A fixed-height row needs slack, and a screen needs a way to render its full
state.** The search result row was 66 tall with 10pt padding, holding a 25pt line, a
2pt gap and a 19pt line — exactly 46 against exactly 46. The fraction a font's line box
rounds up by then put it 2px over on a device. Padding is what yields there; the 66 is
the pitch the list geometry is built on. It survived because `FoodSearchScreen` had no
`results` override, so the only state a test could reach was the empty one — which is
the convention existing precisely to prevent this.

## Two bugs worth not reintroducing

**A `FractionallySizedBox` in a `Stack` needs `heightFactor: 1`.** This has now
shipped twice: the Scan Result macro bars, and the quiz's progress bar. A
non-positioned `Stack` child gets *loose* vertical constraints, so a `ColoredBox`
inside a `FractionallySizedBox` takes the smallest height allowed, which is zero. The
track draws, the fill does not, and nothing throws — the screen looks plausible and
merely never appears to fill. Neither `analyze` nor the overflow suite sees it; both
were caught by eye, the second one by the user. If you write a proportional fill
inside a `Stack`, assert its rendered height in a test.

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

## iOS build settings that are decisions

- **`TARGETED_DEVICE_FAMILY = 1`** — iPhone only. The whole UI is a fixed 428 × 926 artboard
  capped at 1.15× on tablets, so on an iPad it renders as a scaled phone column adrift in the
  middle of the screen. Apple reviews on iPad if you claim it, and that is a routine 2.4.1
  rejection. Shipping iPad means designing for it, not declaring it.
- **`ITSAppUsesNonExemptEncryption = false`** — answered in the plist so uploads stop stalling
  on the export-compliance questionnaire. Correct while the only cryptography is HTTPS.

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
