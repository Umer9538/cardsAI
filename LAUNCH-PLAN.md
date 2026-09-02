# Ninety days to a listed, paid app

**Carbsai · pre-launch · 31 Aug → 29 Nov 2026**

A sequenced plan for shipping Carbsai to Play and the App Store — and the adversarial
critique that overturned nine of its own numbers before it reached you.

> Produced by a 27-agent research workflow: 10 market sweeps and 2 codebase audits, each
> adversarially fact-checked, then three independent strategies judged into one plan and
> attacked by a completeness critic. 1,187 tool calls.

**Evidence grades used throughout:**

| Grade | Meaning |
|---|---|
| `CONFIRMED` | corroborated independently |
| `CONTESTED` | direction right, magnitude disputed |
| `KILLED` | did not survive fact-checking — not used |
| `UNKNOWN` | no source exists — do not plan against it |

---

## 0. The verdict, with the optimism taken out

Yes, it can make money. **As a low-four-figure business in year one, not a job.**

Every figure here is worse than the first draft produced, because the critique pass caught
the draft benchmarking itself against a hard-paywall conversion rate while designing a
freemium product, and pricing a US install mix while planning a distribution strategy that
recruits in roman-Urdu.

| | Figure | Note |
|---|---|---|
| **Net per payer, year 1** | **~$24** | Not $31. US withholding on US-source income defaults to 30% absent a validated treaty claim, and the US–Pakistan treaty rate could not be confirmed. `CONTESTED` |
| **Install → paid, base case** | **2.1%** | RevenueCat's *freemium* median — the applicable one. The draft used 4.8%, benchmarked against hard paywalls. `CONFIRMED` |
| **5,000 installs →** | **~$2,500** | ≈105 payers. The draft said $7,440. Both terms — price and conversion — move against you in PK/IN storefronts. |
| **Category reality** | **5%** | Share of Health & Fitness apps reaching $10,000 in *total* revenue in their first two years. Median new subscription app: ~$72/month a year in. `CONFIRMED` |

### The single biggest reason it fails

**Nobody will find it, because right now it is indistinguishable from fifty other AI calorie
counters.** That is not a marketing problem you can outwork — it is also a rejection risk,
since Apple Guideline 4.3(b) bars apps "indistinguishable from what's already widely
available."

And the paid escape hatch is closed. Adapty's "Calorie & Weight Tracker" subcategory shows
**CPA $2.69** against a Health & Fitness 12-month install LTV of **$1.21** `CONFIRMED` —
negative before you start. The influencer channel is closed too, in the market leader's own
words: *"they want to be guaranteed a payment. And if we're not gonna do it, another brand
will."*

### Second risk, and it is binary: Apple may not be able to pay you

Apple publishes no supported-payout-bank-country list anywhere, and Pakistan/PKR is absent
from its minimum-payment-threshold table. iOS generates roughly 5.6× more subscription
revenue than Android. `UNKNOWN`

The critique corrected the draft here: emailing Apple Support is **not** a valid test — they
will not give a binding answer on bank eligibility. The only definitive test is to enrol
($99), sign the Paid Applications Agreement, complete tax and banking, and attempt to add the
account. That answer arrives in week 2–3, after the money is spent.

---

## 1. The wedge

> **Carbsai logs the composite, home-cooked food that photo-only scanners fail on — because
> you describe it instead of just shooting it, and the catalogue already knows biryani, daal
> and karahi.**

One sentence. It has to appear in the title, the subtitle, the keyword field, all three
screenshots and the food catalogue — not just in this document.

### Why this, and not accuracy

- **Photo-only collapses precisely on the target food.** ChatGPT-4o reached 93.3% agreement
  within ±10g on fruit and veg but **46.7% on composite meals** — and got *worse* (43.3%)
  when a size reference was added. `CONFIRMED` Biryani, karahi, daal chawal, a sandwich,
  leftovers. That is most meals, everywhere.
- **Adding text to the photo is the best-evidenced product intervention available.** One
  study: image-only 30.51% energy MAPE → image + ingredients **13.92%**. But a much larger
  sweep across 40 vision models called the same gain "slight," with per-model responses
  spanning **−19.1% to +3.4%**. `CONTESTED` — direction well-supported, magnitude disputed.
  You test it yourself in week 1.
- **It is structurally un-copyable by the leader.** Cal AI's store description ends verbatim:
  `*FOOD SCANNING ANALYSIS RESULTS REQUIRE A SUBSCRIPTION`. Their business *is* charging for
  the photo. They cannot lead with "you don't need a good photo."
- **It is nearly free.** `DescribeMealScreen` already exists and costs roughly a tenth of a
  photo scan. Text logging can be free forever, which means it can be the habit, which means
  the paywall never sits on the everyday action.
- **Photo-first logging does not sustain anyway.** The Eatery (189,770 downloaders):
  **86.39% took zero or one photo ever.** `CONFIRMED`

### Pre-register the week-1 test, or it will tell you what you want to hear

The draft said "if text + photo does not beat photo alone, the wedge is wrong" — with "beat"
undefined, unblinded, n=30 splitting to ~15 composite dishes, run by the person who needs the
answer to be yes.

Fix the criterion now: **MAPE on energy across the 15 composite dishes; text+photo must beat
photo-only by ≥10 percentage points absolute.** Below that, the wedge re-scopes from *"more
accurate"* to *"has names for food the others don't"* — which the catalogue alone supports,
needs no accuracy claim, and survives Guideline 1.4.1 untouched.

### The thing you may never say

Apple Guideline 1.4.1, verbatim: *"Apps must clearly disclose data and methodology to support
accuracy claims relating to health measurements, and if the level of accuracy or methodology
cannot be validated, we will reject your app."* You have no eval set. **No numeric accuracy
claim anywhere** — listing, screenshots, website, TikTok, support docs. Cal AI's own "about
80% accurate" lives buried in a support FAQ, not its store listing.

What you *can* say is behavioural, and it already ships: the per-item **"Check this"** chip
and the clarifying question. "We tell you which items we're unsure about" describes
behaviour, not accuracy.

One directive follows from the same literature: **protein estimation is far worse than every
other macro.** Stop rendering protein with the same visual confidence as calories.

**Strategic dividend.** If the text description is the record and the photo is confirmation,
parked R2 stops being on the critical path. The thing this backend was architected to avoid —
a payment method on Cloudflare — stays avoided.

---

## 2. What the critique overturned

A second pass was told to attack the plan. These are the findings that changed it. They are
here rather than folded in silently, because each one is a mistake worth not making twice.

### Trial length

- ~~21-day free trial, both stores~~
- **→ 1 month, both stores**

App Store Connect introductory free trials are *fixed durations*: 3 days, 1 week, 2 weeks,
1 month, 2, 3, 6 months, 1 year. There is no 21-day option. The whole case rests on the 17–32
day band converting at 42.5% vs 37.4% at 5–9 days — **1 month satisfies it, 2 weeks does
not.** As written you would have shipped 14 days on iOS believing you were in the 42.5%
bucket.

### Conversion benchmark

- ~~4.8% base case, "under half the hard-paywall median"~~
- **→ 2.1% freemium median**

The product designed here — unlimited text logging, barcode, search, diary, targets, weight,
free forever — *is* freemium. A hard paywall means no access without paying. The base case was
set 2.3× above the applicable median while the document warned that all vendor figures are
upper bounds.

### Refund hole

- ~~"Lazy expiry on `isPremium`. One line; do not wait for store notifications."~~
- **→ RevenueCat, specifically for its refund webhooks**

Lazy expiry does not touch the case that matters. On a refund or revocation, `renewsAtTs` is
still 365 days out, so comparing it grants premium for the full year. H&F refunds run 4.71%
category-wide. You need Play RTDN + App Store Server Notifications V2 `REFUND`/`REVOKE`, or a
provider that does it for you.

### Test integrity

- ~~Kill `freeScanLimit: 3` in Phase 2~~
- **→ Phase 0, same commit as the AdMob deletion**

Phase 0 deletes AdMob, which removes the "watch an ad for scans" escape. The paywall does not
exist until Phase 2. So every one of your 12 closed testers would hit *"You have used your 3
free scans"* for three weeks with no ad, no paywall and no purchase behind it — and Phase 2's
retention gate would then be measured on people walled out of the headline feature.

### Safety — removal category

- ~~Not mentioned~~
- **→ Clamp goal weight to BMI ≥ 18.5, Phase 0**

`onboarding_quiz_screen.dart:526` — `min: 35`. A 175 cm user can set a 35 kg goal (BMI 11.4),
and line `:962` then renders *"On track for 35 kg by 14 March 2027."* Google Play's
Inappropriate Content policy prohibits apps that promote eating disorders — a *removal*
category, not a rating one. Half a day, and it outranks most of Phase 2.

### Play audience

- ~~Age rating 9+ everywhere~~
- **→ Apple content 9+, Play target audience 13+**

These are different declarations. On Play, selecting any band under 13 triggers **Families
policy** — neutral age screen, no `AD_ID`, certified ad SDKs. Meanwhile the app's own age
slider floors at 13 and the Terms say 13+. Declaring 9+ manufactures an obligation you do not
need and creates a metadata inconsistency a reviewer can see.

### Firestore ceiling

- ~~Binds at 250–600 DAU; migrate to D1 in Phase 2~~
- **→ Binds nearer 100 DAU; D1 moves to Phase 1**

Search is client-direct and debounced at 450 ms, so typing "chicken biryani" fires 2–4 queries
at up to 120 reads each. A *session* is 120–480 reads, not 60–120, against 50,000 free daily.
Choosing text-first logging makes search the hot path and pulls the collision forward.
**The 5,000-install target is unreachable on Firestore.**

### Entity

- ~~"Enrol as an individual ($99)"~~
- **→ Costed entity-vs-individual decision, week 1**

Apple 5.1.1(ix) directs apps in *"highly regulated fields (such as… healthcare…)"* to be
submitted by a legal entity. This app collects age, sex, height, weight, goal weight, meal
photographs and a full food diary. Cal AI ships under an LLC. One decision resolves that, EU
DSA trader status (which otherwise publishes your **home address** on the listing), the Play
D-U-N-S requirement, and possibly the Apple payout question — all at once.

### Schedule

- ~~38.5 dev-days "leaving room for content and review rounds"~~
- **→ 38.5 ÷ 3/week = 12.8 weeks. There is no room.**

That consumes the entire 90 days with zero slack — while the same document assigns 250
TikToks, 15 nurtured Facebook groups, 30 cooked and weighed meals, 500 hand-entered dishes,
two store review cycles and a 14-day closed test. The 500 dishes alone are budgeted at one
dish every two minutes; realistically 5–10 days, not 2.

### Six more the critique caught in the code, that neither audit did

| Finding | Where | Consequence |
|---|---|---|
| iOS ships as **Universal** | `project.pbxproj:361,488,541` — `TARGETED_DEVICE_FAMILY = "1,2"` | Apple reviews on iPad, where a 428×926 canvas capped at 1.15× renders as a scaled phone column mid-screen. Routine 2.4.1 / 4.0 rejection. Set to `"1"` — free. |
| `ITSAppUsesNonExemptEncryption` absent | `ios/Runner/Info.plist` | Every TestFlight and App Store upload stalls on the export-compliance questionnaire. One key, and it blocks your *first* iOS build. |
| Dated weight projection is itself a health claim | `onboarding_quiz_screen.dart:962` | "On track for X kg by DATE" is the same class of claim 1.4.1 governs — and until Phase 2 there is no way to log a weight, so the app makes a falsifiable prediction and provides no means to falsify it. |
| Photo sent abroad, then discarded | `r2_photo_repository.dart` | The photo goes to OpenRouter in another jurisdiction and is then silently lost when the OS evicts the cache. The entire disclosure burden, no user-visible benefit. Persist to app-support, or stop promising an image in the diary. |
| Superseded backend still ships | `pubspec.yaml:48`, `functions/`, `storage.rules` | `firebase_storage` is still a dependency and `functions/` is still in the repo. Each is a line on an App Privacy questionnaire and a `firebase deploy` you can fire by accident. |
| One thing that is *right* — protect it | `AndroidManifest.xml` | Only `CAMERA` and `INTERNET` are declared; no `READ_MEDIA_IMAGES`. That is what keeps you compliant with Play's Photo/Video Permissions policy. If anyone adds a media permission to make gallery pick "work better," that is an app-removal violation. |

---

## 3. The plan

Five phases. Effort estimates are the corrected ones — and they do not fit in 90 days at three
coding days a week, which is a fact to plan around rather than argue with.

### PHASE 0 — Cannot submit · Weeks 1–2 · ~10 d

*Nothing here is growth. All of it blocks growth.*

| Item | Effort | Why |
|---|---|---|
| **Decide entity vs individual.** Enrol accordingly. Small Business Program *before* your first sale (15%, not 30%). | 1 d | Resolves Apple 5.1.1(ix), EU DSA trader address, Play D-U-N-S and possibly the payout question at once. Do not default silently to "individual, $99." |
| **Clamp goal weight to BMI ≥ 18.5** against entered height; refuse to render the projection below it. | 0.5 d | Play removal category. Highest-priority single line in the document. |
| **Kill `freeScanLimit: 3`** — `scan.ts:65`, the bucket that never resets. | 0.1 d | Same commit as AdMob. Otherwise the closed test measures a crippled product. |
| **Generate an upload keystore.** Back it up twice. | 0.5 d | `build.gradle.kts:36-42` signs release with the debug key; Play refuses the bundle. Losing it later is unrecoverable. |
| **Delete the Google and Apple sign-in buttons** — `login_screen.dart:199-220` → methods that unconditionally throw. | 0.25 d | Reviewers tap every button. Guaranteed 2.1 rejection. Do not *build* the providers either — adding Google forces Sign in with Apple under 4.8. |
| **Delete AdMob entirely** — SDK, manifest id, plist id, `NSUserTrackingUsageDescription`. | 0.5 d | Live builds currently ship Google's test unit ids silently. See §4 for the arithmetic. |
| **Delete the superseded backend** — `firebase_storage`, `storage.rules`, `functions/`. | 0.25 d | Privacy-questionnaire surface and an accidental deploy target. |
| **Set `TARGETED_DEVICE_FAMILY = "1"`** and add `ITSAppUsesNonExemptEncryption`. | 0.1 d | Two lines that between them prevent an iPad rejection and an upload stall. |
| **Restore Purchases** on the paywall and in Settings, and fix `restore()`. | 0.5 d | `store_subscription_repository.dart:160-165` reads entitlement without awaiting the purchase stream, returning the stale value. Guideline 3.1.1. |
| **Fail visibly on Firebase init failure in release.** | 0.25 d | `main.dart:49-66` degrades a signed release into `LocalScanRepository`, which returns the same three foods whatever you photograph. A bad config file ships an app that *invents nutrition data*. |
| **AI-disclosure consent screen before the first scan.** Name the recipients inside the consent, not only the policy. | 1 d | Apple 5.1.2(i) and Play Prominent Disclosure. The pipeline has no consent step today, and the photo leaving the country is the disclosure most likely to be challenged. |
| **Server-side account deletion** as a Worker route, with reauthentication and an actual `await`. | 2 d | `firestore.rules` denies client writes to `scans`, `quota`, `subscription` — so deletion is *structurally incapable* of removing the scan log, which stores the model's observations about a person's meals with no TTL. And `main_shell.dart:247` calls `deleteAccount()` without `await`. |
| **Rewrite the privacy policy, host it, and add the separate Play web deletion URL.** | 1.5 d | `legal_content.dart` is dated 2024, names the operator as the literal string "us.", and *promises Google Fit / Apple Health integrations that do not exist* (`:52`). Name every processor. Two artefacts, not one. |
| **Appoint a GDPR Art. 27 EU representative** (and UK equivalent). | 0.5 d | ~€100–500/yr. Their name and address must appear in the policy you are writing this week, so it is a dependency, not an afterthought. You are pricing in €/£ and launching in GB. |
| **Store forms.** Apple content 9+; **Play target audience 13+**. Health + Fitness both declared. Play disclaimer verbatim in the description. | 1 d | Under-declaring health data is a common cause of listing takedown. |
| **Target API 36** (Android 16). | 0.5 d | Due now for new apps. |
| **Analytics + Crashlytics.** Neither is in `pubspec.yaml`. | 1 d | Today you have `wrangler tail` and nothing else. Eight events, §6. |
| **Run the pre-registered 30-meal test.** Kitchen scale, three ways. | 1 d | ≥10pp absolute MAPE improvement or the wedge re-scopes. Week 1, not week 12. |

**Exit:** a signed release installs from Play internal testing; a fresh account completes
signup → quiz → text log → barcode → search → delete account with no uncaught throw; the
privacy policy resolves at a public URL; the falsification test has a verdict against its
pre-registered criterion.

---

### PHASE 1 — Cannot take money · Weeks 1–4 · ~11 d

*Console work moves to week 1 — the validator cannot be tested before the products exist.*

| Item | Effort | Why |
|---|---|---|
| **Open the Play closed test in week 1. Recruit 12 testers immediately.** | — | 12 opted-in testers, continuously, for 14 days — *then* you apply, and Google reviews the application. Budget a week for that review. This is a wall-clock gate and it is the long pole of the launch. Do not register as an organisation to dodge it. |
| **Create `annual` and `monthly` in both consoles**, with the §4 ladder and a **1-month** trial on annual only. | 1 d | Gated on the payout/agreement question. Must precede the validator work, which the draft had backwards. |
| **Adopt RevenueCat** rather than hand-building entitlement. | 3–4 d | $0 until $2,500 monthly tracked revenue, then 1%. Not a drop-in — it replaces both the `in_app_purchase` client seam and the Worker's entitlement source. Same cost either way, but **only this path gives you refund and revocation webhooks**, which is the hole lazy expiry does not close. |
| **Delete `FirestoreSubscriptionRepository.purchase`** (`:56-57`). | 0.1 d | A live receipt-free grant path, one wiring change from being the client-side exploit. |
| **`purchaseTokens/{token} → uid`** with a transactional create. | 0.5 d | Otherwise one real receipt entitles unlimited accounts. |
| **Fix `_validate`'s catch; complete the purchase in a `finally`;** persist unvalidated receipts and retry on next launch. | 1 d | `store_subscription_repository.dart:214-239` catches only `FirebaseFunctionsException`, so a network failure charges the user and skips `completePurchase` — Play auto-refunds unacknowledged purchases after 3 days. The mirror case takes money and delivers nothing. |
| **Migrate `foods` to Cloudflare D1.** | 3 d | Moved up from Phase 2. Free tier binds nearer 100 DAU, and text-first logging makes search the hot path. FTS5 also fixes whole-words-only search. **Budget a local SQLite mirror of the top N dishes** — D1 is not client-reachable, so a naive migration deletes the offline cache and lands the regression on exactly the users with the worst connectivity. |
| **Firebase App Check** (Play Integrity / DeviceCheck) enforced in `requireAuth`. | 2 d | Nothing today binds an ID token to your binary. Verifying an App Check JWT means a *different* JWKS path from the ID-token flow in `auth.ts`. One day was optimistic. |
| **Global daily spend ceiling that fails closed** ($20/day). Clamp `description` and `hint` server-side to 400 chars. Rate-limit `searchFoods` per uid. | 1 d | `scan.ts:176-190` bounds only `imageBase64`; `prompt.ts:130-157` interpolates text raw — a 1MB description is ~250k input tokens on one quota unit, a ~40× cost multiplier. `foods.ts` is unmetered and retries 5× into a shared 1000/hr USDA key. |
| **Validate `loadConfig`'s `baseUrl`** against an allowlist. | 0.1 d | An edited `config/scan` currently sends `OPENAI_API_KEY` to an arbitrary host. Operator footgun, one hour. |

**Exit:** a sandbox purchase on both stores grants entitlement end to end; a refunded
subscription *loses* entitlement via webhook; Restore recovers a purchase on a fresh install;
a scripted account cannot exceed the daily ceiling; the 14-day closed test has completed *and*
production access has been granted.

---

### PHASE 2 — What makes it worth paying for · Weeks 3–7 · ~19 d

*Annual first-renewal is 25% median. Model LTV on one year and no renewals.*

| Item | Effort | Why |
|---|---|---|
| **The repeat-log loop.** `watchFavourites`, a recents list, one-tap re-log, and **meal edit from the diary**. | 3 d | **Highest-leverage change in the codebase.** `main_shell.dart:135-137` shows "saved to favourites" and *nothing in `lib/` ever reads `Meal.favourite`*. There is no recents, no copy-yesterday, no quick-add, and a logged meal cannot be edited — get a portion wrong and the only recourse is delete-and-rescan. The Spark pilot: simplified logging achieved a **median 97% of days tracked vs 49%** for detailed, with indistinguishable weight loss. `CONFIRMED` |
| **Weight logging + trend line.** | 2 d | The app's own broken promise: the quiz collects `goalWeightKg` and the plan screen renders "On track for X kg by…" — then gives no way to record a single weight. Calories are the input; weight is the outcome, and the outcome is the only thing that justifies a month-12 renewal. |
| **~500 South Asian dishes** hand-entered with `rank: 0`. | 5–10 d | The actual moat, and nobody funded will build it. `tokenize` exists *twice* — in `catalogue.ts` and `FirestoreFoodRepository` — and they must agree, or the food is permanently unfindable. The draft budgeted 2 days; that is one dish every two minutes including sourcing credible per-100g macros. |
| **Tailored local meal reminders** scheduled from the user's own `eatenAtTs` values. `flutter_local_notifications` only. | 2 d | The toggles at `notification_settings_screen.dart:20-24` write four booleans nothing reads. **The design matters more than the feature:** tailored prompts raised capture 2.8 → 4.6 images/day (p≤.001); generic fixed-time prompts produced +0.83 at p=.23 — *no effect*. Shipping 8am/1pm/7pm reminders is shipping a measured null result. `CONFIRMED` |
| **The paywall screen** at the end of the quiz, plus free-tier gating. | 2 d | Non-negotiable construction: the **billed amount must be the most prominent pricing element** (Cal AI was cited under 3.1.2(c) for the inverse); "1 month free, then $39.99/year, auto-renews" adjacent to the toggle; Terms and Privacy links on the paywall; Restore on the paywall; one-tap in-app cancel in Settings. **No second, different offer to someone who declined** — Cal AI was cited under 5.6 for exactly that. |
| **Offer the description field *with* the photo**, not buried. | 1 d | The best-evidenced product change available. Gate on the week-1 result. |
| **Imperial units toggle.** | 1 d | `'cm'` and `'kg'` are hardcoded at `onboarding_quiz_screen.dart:361,371,530` — inside your highest-drop-off surface. The paying half of your audience is imperial. Not i18n; must not wait for it. |
| **Text-scale cases in `responsive_overflow_test.dart`, and semantics labels.** | 1.5 d | The suite tests 10 viewports and *zero* text scales, on a canvas of fixed-position children — dynamic type is structurally guaranteed to overflow. Separately: 34 semantics-free `GestureDetector`s across 19 files. This matters more here than for a generic app, because you are marketing into diabetes communities — an older, higher-dynamic-type audience. |
| **Soften or methodise the weight projection.** | 0.5 d | State the energy-balance assumption inline, or give a range. And **make the 1,200/1,500 kcal floor visible** when `TargetCalculator` applies it — a silent floor is a number the user cannot audit; "we won't set a target below 1,200 kcal" is a trust asset. |

**Exit:** among the 12 closed testers, median days-with-≥2-eating-occasions ≥ 7 of the last
14. Below 4 → stop and go to §6's pivot rule before anything in Phase 3. Compute this with a
script over Firestore `users/{uid}/meals`, **not** GA4 — a per-user rolling median needs
BigQuery, has 24h latency, and thresholds at n=12.

---

### PHASE 3 — Launch · Weeks 6–9 · ~4 d

*Android first. Do not write iOS-specific code before the payout question resolves.*

- **Week 6 — silent Play production release** to US, GB, CA, AU, AE, SA, PK, IN. No
  announcement. Accumulate organic installs, shake out crash reports, get the listing indexed.
- **Week 8 — the community push**, once you have real day-7 retention from week 6's cohort.
- **Week 9 — iOS submission**, assuming the payout answer came back positive. Budget one
  rejection round.

**Launch-week channels — this is the whole list:**

1. **Desi Facebook groups — the primary channel, not Reddit.** The one $0 comparable in the
   whole corpus (Caddy, Philippines, self-reported) got 1,000+ downloads and 14 subscribers in
   two weeks from existing Facebook groups, using a personal story and native-language posts
   about local cuisine. **Join 15 groups in week 1 and post value only for four weeks** — a
   calorie chart for 40 common desi dishes, a plain explainer on why apps get roti wrong.
   Link nothing until week 8, then post once, as a member with history.
2. **r/AlphaAndBetaUsers, r/TestFlight** — week 1, for the 12 testers.
3. **r/SideProject, r/iosapps** — with iOS. r/iosapps allows one disclosed post per developer
   per 30 days; spend it once.
4. **r/1200isplenty** — a recommendation surface where trackers get named unprompted. **The
   goal is to be recommended, not to post.**
5. **WhatsApp** — family, gym, university groups. Unglamorous, and in the diaspora it is where
   things move.

**Closed. Do not post, do not DM mods, do not test the boundary.** r/nutrition: *"ZERO
tolerance. NO exceptions."* r/Fitness bans self-promotion outright. r/loseit and r/xxfitness
are similar. One post gets you permanently banned from the largest audience in the category.
Re-read each sidebar yourself — this is a second-hand index.

**The diabetes angle, and its line.** Pakistan has the world's highest adult diabetes
prevalence — 31.4%, 34.5M people `CONFIRMED`. Those groups are the highest-intent surface
available. **But stay on the line the market has drawn.** SNAQ states *"under no circumstances
should the app be used to calculate insulin doses"*; mySugr gates its bolus calculator country
by country. **Never let a carb number be framed as a dosing input** — and put that sentence
wherever a carb number appears, not just in the policy. It is the one line that survives
contact with a journalist.

**Exit:** live on Play in 8 storefronts; ≥20 ratings at 4.3+; iOS submitted; no P0 crash in
Crashlytics.

---

### PHASE 4 — Growth · Weeks 3–13 · mostly non-dev

*The content engine starts week 3 — you need a back-catalogue the day the listing goes live.*

Three posts a day, one TikTok account, auto-crossposted. Four formats, English and roman-Urdu.

| Mix | Format | Why it works |
|---|---|---|
| 40% | **"Guess the calories"** — static plate, three-second beat, number counts up, reveal. Nihari with two naan; pulao at a shaadi; samosa chaat. | The exact shape of Cal AI's 11.3M-view winner. **No dialogue, text overlay only** — it travels without language, which matters for the Gulf. |
| 25% | **"Ammi's portions vs the app"** — POV of the plate you get served at home, scanned. | Native to the audience and impossible for a Silicon Valley app to make. |
| 20% | **Cooking POV, scan at the end.** | Cal AI's second-best format. Optimise for *saves*, not views. |
| 15% | **"Why your app says roti is 80 calories and it isn't."** | Education. This is the format that makes you *recommendable*, which is what converts in communities. |

**Never post an app demo as a standalone video.** A scrape of 40M+ views across 200+ Cal AI
creator videos found *not a single viral TikTok came from Cal AI's own account*, and the
winners were content first with the app as a beat.

**Be sceptical of every view benchmark.** One source reports ~10 installs per 1,000 views;
another claims ~1,000 views/video in week 1; a third claims a 200-view floor. **The two view
figures disagree by 5×, all three sources sell something, and none publishes methodology.**
`UNKNOWN` — measure your own.

**Decision gate, day 30 of posting.** Median views across the first 90 videos. Under 300 → the
*format* is wrong, not the cadence; kill the two weakest and put everything into the survivor.
Over 1,000 → double to 6/day.

**Creators: nothing until day 60, then 20 nano creators, barter only.** Desi food or fitness
creator, 1,000–15,000 followers, not yet monetised. *They get:* lifetime premium, a named code
giving their audience 3 months free, and 30% revenue share on what that code produces. *They
give:* two videos, in whatever format they already make. No script, no approval, no
exclusivity. Track redemptions against the code, not a link — you have no attribution SDK and
should not add one. **Do not offer CPI**; it is the model that attracts bot networks. *(The
claim that Cal AI's affiliate layer caused its revenue jump was downgraded to unproven
single-source causation.* `KILLED`*)*

**Referral loop — pay in scans, not months.**

- `referrals/{code} → uid`, redeemed once at signup, **server-side in a Worker route with a
  transactional single-use claim.** Never client-attested — `grantBonusScans` is exactly the
  mistake not to repeat: it takes the client's word, its payout sits *outside* the transaction
  (`rewards.ts:76-79`), and `today()` is UTC so a user near the boundary gets two days in one.
- **Payout fires only after the referred account completes 3 successful logs.** Self-referral
  farming is otherwise free.
- 1 referral = 30 free photo scans both sides · 5 = 3 months premium · 10 = lifetime. Hard cap
  at 10.
- Put code entry **inside the quiz at step 4 or 5** — the point of maximum investment, and it
  costs nothing.

**Win-back at month 11, not month 2.** Carrot Rewards (n=41,207): median time to resume after
a break was **12–32 weeks**. Firing win-back at 2–4 weeks is contradicted by the only real
data available. `CONTESTED` — that is a walking-rewards app, not a nutrition logger, but it is
what exists and it contradicts the reflex.

**Position for January, do not spend into it.** January H&F installs run **34% above the H1
average**, climbing 11% by 26 Dec and 46% by 1 Jan, then falling 20% by April. Have the
listing, the catalogue, 250+ videos and a working paywall build **ready to submit on 20
December** — which is three weeks *after* day 90, not before it.

**Exit, day 90:** live on Play, 4.3+ rating, ≥100 ratings, 250 videos posted, iOS submitted,
and median days-with-≥2-logs ≥ 7.

---

## 4. The monetisation design

| Plan | US price | Reasoning |
|---|---|---|
| **Annual** | **$39.99** | H&F median annual is $39.94 and $39.99 across two independent panels. Well under MyFitnessPal's $79.99. `CONFIRMED` |
| **Monthly** | **$9.99** | Decoy. Makes annual read "$3.33/mo, save 67%." |
| Weekly | none | Weekly 12-month retention is 3.4%, and H&F is the one category moving *toward* annual (51% → 61% of subscription revenue). Prominent weekly-equivalent pricing is also exactly what Apple cited Cal AI for under 3.1.2(c). |
| Lifetime | none | Caps LTV at one payment, creates a permanent support obligation. |
| Streak restore | none | Cal AI ships one at $0.99. Silverman et al. (*JCR* 2023) find paid streak repair **reduces** motivation to maintain the streak and that streak-breakers abandon the platform. Forgive lapses silently. |

**Two plans only** — 60% of H&F apps show exactly two. **No launch discount** — 9 in 10
subscriptions sell at full price.

### Trial: one month, annual only

17–32 day trials convert at **42.5%**; 5–9 days at 37.4%; ≤4 days at **25.5%**. And 55.4% of
3-day-trial cancellations land on *Day 0* — short trials fail before the product has done
anything. One month is the only value in Apple's fixed set that lands in the winning band, and
it makes the two platforms comparable.

Cost to you: 30 days × 2 photo scans/day × $0.0012 ≈ **$0.07 per trial started**. At 40%
conversion that is under $0.20 of scan cost per payer. **Monthly gets no trial** — trials
belong on the plan you want sold.

*The cost, stated:* a one-month trial delays your first conversion signal by four weeks. Treat
**trial starts** as the launch metric.

### Regional ladder

Set by hand. Pakistan appears in **no published PPP reference table** `UNKNOWN`, so the anchor
is Lifesum's verified live PK annual price of Rs 3,900 — 71.9% below its US price.

| Storefront | Annual | Monthly | Index |
|---|---|---|---|
| US, CA, AU, NZ, Nordics | $39.99 | $9.99 | 1.0 |
| UK / EU | £34.99 / €44.99 | £8.99 / €10.99 | ~1.2 |
| Gulf (SA, AE, QA, KW) | SAR 149.99 | SAR 39.99 | ~1.0 |
| India | ₹1,499 | ₹399 | ~0.4 |
| Pakistan | PKR 3,900 | PKR 990 | ~0.35 |
| TR, ID, BR, EG, NG, BD, PH | −60% | proportional | ~0.4 |

**Do not discount the Gulf.** Kalee — a Saudi-built Arabic tracker released Aug 2025 — ranks
**#1 for "calorie counter" in the Saudi store, above MyFitnessPal and Cal AI** — on 3,275
ratings, charging roughly full US price. `CONFIRMED`

Note carefully what won there. **Arabic is already closed** — Cal AI ships 15 languages
including Arabic. Kalee won on the *local food database*, not the UI language. That is the
same bet you are making, and it is the best-evidenced localisation win in the entire corpus.

### The free / paid line

| | Free forever | Trial (1 mo) | Premium |
|---|---|---|---|
| **AI photo scan** | **0** | Unlimited | Unlimited (30/day abuse cap) |
| **Describe a meal (text)** | **Unlimited** | Unlimited | Unlimited |
| Barcode | Unlimited | Unlimited | Unlimited |
| Food search | Unlimited | Unlimited | Unlimited |
| Diary, targets, macros, streak | Full | Full | Full |
| **Weight log + trend** | **Full** | Full | Full |
| Analysis charts | Last 7 days | Full | Full |

**The trial *is* the free photo allowance.** One clean line: take the trial and photo-scan
freely for a month; decline and you get zero photo scans and unlimited everything else. A
decliner can start the same trial later with one tap from the camera — same offer,
re-presented at the natural gate, which is fine; a *second, different* offer is what Apple
cited Cal AI for.

**Text logging is never metered.** It costs ~$0.00012 — 8,333 logs per dollar. A 5/day cap
saves nothing and caps the north-star metric. **Premium is unlimited, not 100/month** — a
heavy user at 3 scans/day costs $1.30/year against ~$24 net. "Unlimited scans" is worth more
as a paywall line than the cap saves.

**Honest note:** the research claim that "every major app paywalls photo AI" was `KILLED` —
Cronometer advertises free photo logging and free barcode scanning on its own site. Gating the
photo is a *choice*, not a category norm. It is still the right choice, because it is the only
feature with real marginal cost and the only feature anyone downloads for.

### Ads: delete AdMob entirely

- A rewarded ad grants 3 scans = **$0.0036** of model spend.
- US Tier-1 rewarded eCPM ≈ $16, bracketed by two independent sources. One impression ≈
  $0.016 → funds ~13 scans. **Profitable.**
- At Pakistani/Indian ~$1 CPM, one impression ≈ $0.001 → funds **0.83 scans. You lose money
  every time a free user in your home market watches one.**
- **Pakistan appears in no country eCPM table across four ad sources; India is an unsourced
  proxy; no H&F ad eCPM benchmark exists anywhere.** `UNKNOWN`
- Generous scale check: 5,000 downloads → 5% D30 → 250 DAU × 0.5 impressions/DAU × $0.016 ×
  365 = **$730/year**, pure Tier-1.

Against that non-revenue, keeping ads costs you: real unit ids gated on AdMob approval; a
declared `NSUserTrackingUsageDescription` that nothing requests plus absent `SKAdNetworkItems`
(both review flags); the UMP flow; the forgeable `grantBonusScans` path; the advertising
identifier inside a *health* Data Safety declaration; and Apple 5.1.3(i), which bars health
data from ad targeting — so you carry the compliance surface without the targeting upside.

**Deleting AdMob removes three and a half launch blockers and one abuse vector in a single
commit.** *(The draft claimed five. It is three and a half — and the inflation matters,
because the real fix for the abuse vector is App Check plus a spend ceiling, which survives ad
deletion and is still 2–3 dev-days.)*

---

## 5. The store listing

60% of store visitors never scroll past the first impression, and 50% of installers decide on
it alone.

| Field | Value | Chars |
|---|---|---|
| Play title | `Carbsai: AI Calorie Counter` | 27/30 |
| Play short description | `Snap it or say it. Logs biryani, daal, roti — dishes most apps don't have names for.` | 79/80 |
| App Store title | `Carbsai: AI Calorie Counter` | 27/30 |
| App Store subtitle | `Desi Food & Macro Tracker` | 25/30 |
| iOS keywords | `biryani,roti,daal,curry,karahi,halal,pakistani,indian,photo,scan,protein,carbs,weight,loss,diet,log` | 99/100 |

No word repeats between title and subtitle — the pattern every leader follows. **Roman-Urdu
dish names *are* the keywords**; that is how the diaspora searches, in English storefronts.

*The short description was rewritten from "the dishes other apps miss."* That was a
comparative claim about unnamed competitors in the single most heavily indexed metadata field,
on a health app. Probably fine; needlessly risky for a phrase that adds nothing.

**Keep "AI" in the title.** AI keyword bidding in H&F rose from 19% of apps to 28%, and **Cal
AI bid ~35 AI keywords per quarter, driving 25% of its total search-based downloads.** It is
the one affordable channel Cal AI proved. `CONFIRMED`

**Do not target "calorie counter" in year one** — 79/100 difficulty on US iOS. But correct the
record on how closed it is: the top nine includes apps at 16,927 and 22,459 reviews against a
*median* of 96,793. **Entry is ~17–26k reviews — a year-two target, not never.** Which is also
why you need free users leaving ratings more than you need 5× on a handful of payers.

### The three screenshots

1. **The dish nobody else recognises.** A real plate of chicken biryani in a phone frame,
   scan-result card overlaid with the item list and per-item grams.
   *Caption: "It knows what biryani is."* — not "accurate," no percentage, Guideline 1.4.1.
2. **The differentiator and the free tier in one image.** Split frame: a dim, unusable
   restaurant photo on the left; the describe field on the right reading *"chicken karahi, two
   rotis, one cup rice"*; the result below.
   *Caption: "Describe it in words — free, unlimited."* This is the thing Cal AI structurally
   will not say.
3. **The day, in the user's own food.** Home screen, ring at ~1,400/2,050, meals list showing
   paratha, daal chawal, chai.
   *Caption: "Your whole day. In your food."* Proves the diary exists *and* that the catalogue
   has the names.

Write captions for humans. A controlled test across 8 category-leading US iOS apps found 36 of
64 screenshot-derived phrases did not rank at all.

---

## 6. Metrics, and the number that says stop

Eight events. No more — you will not analyse more than eight.

| Event | Properties | Why |
|---|---|---|
| `quiz_step` | step index, completed / abandoned | Highest-drop-off surface in the app. |
| `paywall_view → trial_start / decline` | source, plan | The funnel. **86.1% of H&F trial starts happen on Day 0** — instrument Day 0 and Days 4–14 separately or you will see nothing. |
| `log_created` | method, latency | Method mix *is* the wedge test. If text < 30% of logs, the wedge is not landing. |
| `days_with_2plus_logs_last14` | rolling, per user | **The north star.** Compute with a script over Firestore, not GA4. |
| `weight_logged` | — | The renewal driver. |
| `search_no_results` | query string *(keep it server-side)* | Free product roadmap — it tells you exactly which desi dishes are missing. |
| `scan_result` | success/fail, reason, item count, cost | Cost tracking and failure triage. |
| `trial_convert / cancel / refund` | plan, day index | H&F leads every category on refunds at 4.71%. |

**Do not put food names, weights, or search query strings into GA4 parameters.** That is
health data leaving to a third party you would then have to declare on both privacy forms and
obtain consent for.

### The north star

**Days in the last 14 with at least two eating occasions logged.** Turner-McGrievy (two pooled
RCTs, n=124) found this exact definition the best adherence predictor of 6-month weight loss
(R²=0.27, P<0.001), beating every alternative tested. "Log Often, Lose More" (n=142) found
successful losers spent *no more time* — they just logged more often. **Frequency beats
richness. Optimise taps-per-log, not detail-per-log.** `CONFIRMED`

**Target: median ≥ 7 of 14 at D30.**

### Pivot triggers — and which are actually reachable in 90 days

| Trigger | n needed | Reachable by d90? | Action |
|---|---|---|---|
| Median days-with-≥2-logs below 4 of 14 | 100 quiz completers | **yes** | **Stop everything and rebuild the logging loop.** No paywall, content engine or price change survives a product nobody opens. Set the alarm at week 6–8, not week 2. |
| Text logs below 30% of all logs | 500 logs | **yes** | The wedge is not landing *in the UI*. Move the describe field earlier before concluding the wedge is wrong. |
| Fewer than 500 installs from 250 videos | day 90 | **yes** | Format is wrong; cadence will not fix it. Kill the engine, put everything into ASO and the Facebook groups. |
| `search_no_results` above 20% | 500 searches | maybe | The catalogue is the moat and it has holes. Spend a weekend filling them from the query log. |
| Trial-to-paid below 15% | 50 trials | **no — d180** | With a week-8 launch, a one-month trial and 5,000 installs *per year*, you will see roughly 10–40 trials by day 90. Mark it honestly as a day-180 gate. |

---

## 7. Do not do this

- **Do not make any numeric accuracy claim** — listing, screenshots, website, TikTok, support
  docs. Guideline 1.4.1 is the hardest rule in the book to argue past, and you have no eval set.
- **Do not buy a single ad.** CPA $2.69 against install LTV $1.21. Open an ad account only
  when your own measured revenue per install clears $3.00.
- **Do not ship ads.** See §4.
- **Do not build web / Stripe checkout.** Web is 3.2% of subscription revenue globally, 0.8%
  in IN/SEA. The only controlled test found was **net-negative even after full fee savings** —
  $0.93 per $1.00 of IAP, driven by trial starts collapsing 27.0% → 18.1%. And embedded Stripe
  checkout is literally what got Cal AI pulled under 3.1.1.
- **Do not serve a second, different offer to someone who declined the paywall.** Apple cited
  Cal AI under 5.6 for exactly this.
- **Do not sell a streak restore.** Paid streak repair reduces motivation to maintain the
  streak. *(All vendor-sourced streak benchmarks in the research were marketing with no
  methodology and did not survive verification* `KILLED` *— keep the hazard, drop the numbers.)*
- **Do not A/B test the paywall.** Cal AI ran 123 experiments and 424 variants to reach a 31%
  funnel. At 1,500 installs you cannot detect a 20% lift on a 5% base. Ship one paywall;
  revisit at 1,000 trials — and judge on D14/D60 revenue per install, never on conversion rate.
- **Do not run Product Hunt as a pillar.** ~10% of launches now get featured, down from
  60–98%. All of it traces to a single blog post and there is no empirical iOS install data for
  it at all. `UNKNOWN`
- **Do not ship Urdu, full i18n, home widgets, Health sync, exercise logging, water logging,
  CSV export, recipe creation, or a light theme** in these 90 days. All real gaps; all
  downstream of "does anyone open it on day 2." *Do* delete the false Health-sync line at
  `legal_content.dart:52` and the water-logging promises — those are disclosure defects, not
  missing features.
- **Do not un-park R2.** The wedge makes the photo optional, and enabling R2 requires the
  payment method this backend exists to avoid. But then *stop promising an image in the diary*,
  or persist to app-support rather than cache.
- **Do not add a media permission to make gallery pick "work better."** The manifest declaring
  only `CAMERA` and `INTERNET` is what keeps you compliant with Play's Photo/Video Permissions
  policy. Adding one is an app-removal violation, not a warning.
- **Do not register a Play organisation account to dodge the 12-tester gate.** Google never
  states an exemption; that is an inference, and an org account brings a D-U-N-S requirement.
- **Do not post in r/nutrition, r/Fitness, r/loseit or r/xxfitness.** One post, permanent ban,
  largest audience in the category.
- **Do not build the 150-photo eval set before month 4.** Do the pre-registered 30-meal test in
  week 1 instead.
- **Do not rewrite `prompt.ts` if results disappoint. Change `config/scan.model` first.** Model
  architecture explained 99.6% of accuracy variance across 40 vision models; prompt effects
  were not significant after correction. `openai/gpt-5.6-terra` is a Firestore config change,
  not a release.
- **Do not reorder `observations` in the schema.** Strict mode emits in schema order; a
  free-text field at the top is chain-of-thought inside a structured output. Reordering it is a
  silent accuracy regression.

---

## 8. What is unknown — stated, not invented

Everything below was searched for and not found, or found and contradicted. None of it is
planned against.

- **Whether Apple can pay a Pakistani bank.** No supported-payout-bank-country list is
  published anywhere; PKR is absent from the minimum-threshold table. iOS is ~5.6× Android on
  subscription revenue, so this is the largest unresolved variable in the plan — and the only
  definitive test costs $99 and takes until week 3. **Write the "no" branch now:** Android-only
  launch, ladder unchanged, all iOS dev-days redirected to the catalogue and the retention loop.
- **Tax.** Only the *existence* of a US–Pakistan treaty is established — a 1957-era instrument,
  no article, no rate confirmed. Absent a validated claim the default is 30% withholding on
  US-source income. Pakistan side: FBR NTN, PSEB registration to reach the IT-export regime, a
  foreign-currency account, and proceeds arriving through the banking channel to qualify at all.
  **Do not quote a rate — book an accountant in week 1.**
- **Payoneer is not a symmetric workaround.** Play payouts via Payoneer are an established
  pattern in Pakistan. Apple requires a bank account *in a supported country, in the payee's own
  name*. State the asymmetry so the fallback is not assumed to cover both stores.
- **`$0.0012 per scan` is n=1** — one observed run of 7 items in 8.6s. Every unit-economics
  ratio inherits it. The conclusion (model spend is not your constraint) survives a 5× error,
  but it is not a measured average.
- **Pakistan appears in no ad eCPM table, no PPP reference table, and no benchmark panel's
  geographic breakdown.** India is an unsourced proxy for all three.
- **The Urdu gap is plausible, not established.** It rests on Apple's declared-language
  metadata, which is demonstrably unreliable — Kalee is a wholly Arabic product declaring one
  language.
- **The "Cal AI is bad at desi food" review evidence is stale.** Those complaints run 2024-11
  to 2025-07, largely *before* it shipped Hindi. The composite-meal failure (46.7%) is the
  durable evidence; the review sentiment is not.
- **RevenueCat's own H&F year-1 realized LTV jumped 2.2× between its 2025 and 2026 reports**
  ($16.44 → $35.64) with no explanation in either. RevenueCat and Adapty also disagree with each
  other by 38% on install-to-trial. Both panels are self-selected users of paywall SDKs.
- **Cal AI's revenue has five mutually inconsistent public framings.** Its widely-quoted "25%
  annual net dollar retention" **has no source** — it is a misreading of a founder's
  forward-looking remark. `KILLED`
- **The 1,200 / 1,500 kcal floors in `TargetCalculator` are unsourced to any authority.**
  Present them as Carbsai's own guardrail, never as a cited clinical standard — otherwise the
  claim itself becomes an unverifiable health claim under 1.4.1.
- **No published benchmark links AI scan accuracy to subscription retention.** The adjacent
  signal — AI apps earn 41% more per payer while AI monthly plans retain 36% worse — is
  consistent with an expectation gap but is not evidence of one.
- **Two US privacy regimes were absent from the research entirely and are in scope:** the FTC
  Health Breach Notification Rule (amended 2024, explicitly covers health apps outside HIPAA —
  the GoodRx and BetterHelp actions turned on exactly this shape), and Washington's My Health My
  Data Act, which has a *private right of action* and requires a separate consumer-health-data
  privacy policy as its own link.

### The strongest argument this plan fails

> It spends the founder's scarcest asset — 90 days of solo attention — building a monetisation
> system that cannot produce a readable number inside its own horizon, to sell a differentiator
> it is legally forbidden to advertise, to an audience its distribution plan actively selects
> against.

And the deeper problem: **the wedge is 500 rows of public nutrition data.** MyFitnessPal has 20
million, and Cal AI now sits inside MyFitnessPal. The only genuinely defensible version is
*measured accuracy on composite South Asian dishes* — and 1.4.1 forbids you from stating a
number, while the eval set that would earn one is deferred past the window. So the plan builds
a differentiator it cannot advertise and defers the asset that would make it advertisable.

**That is survivable only if you take the re-scope seriously.** "Has names for food the others
don't" needs no accuracy claim, is provable in a screenshot, and is what the Saudi comparable
actually won on. Treat the accuracy story as upside you may never be allowed to sell.

---

## 9. Monday morning, in order

1. **Decide entity vs individual**, and start enrolment. It resolves Apple 5.1.1(ix), EU DSA
   trader address, Play D-U-N-S and possibly the payout question at once. Book an accountant the
   same day.
2. **Clamp the goal-weight slider to BMI ≥ 18.5** and suppress the projection below it. Half a
   day, and it is a Play removal category.
3. **Kill `freeScanLimit: 3` and delete AdMob** in one commit — otherwise the closed test
   measures a walled-off product.
4. **Generate the upload keystore.** Back it up in two places.
5. **Delete the Google and Apple sign-in buttons.**
6. **Add Analytics and Crashlytics** with the eight events.
7. **Push an internal build and post the 12-tester call.** The 14-day clock starts the moment
   you push — and Google still has to review the application afterwards.
8. **Join 15 desi weight-loss and diabetes Facebook groups. Post nothing.**
9. **Cook and weigh 30 meals.** Run them three ways, against the pre-registered ≥10pp criterion.

The only two assets that compound here are **the catalogue nobody funded will build**, and
**the people still logging in week six**. Everything above is subordinate to those two.

---

*Web version: https://claude.ai/code/artifact/b4218638-61c2-4d3c-b069-42ed0814c932*
