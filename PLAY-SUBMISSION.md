# Carbsai — Play Console submission

Every answer here is derived from what the code actually does: the shipped APK's
manifest, `pubspec.yaml`, the repository layer and `legal_content.dart` — not
from what the app is supposed to do.

Source: `com.carbsai.app` at commit `d8937cc`.

**8 ready to paste · 3 your call · 0 blocked**

---

## Operator — settled

`LegalOperator` is filled: **Lumy Labs**, `lumylabsco@gmail.com`, governed by
**Pakistan** law. The documents are live.

To change any of it: edit `legal_content.dart`, then

```
dart run tool/emit_legal.dart
cd site && npx wrangler pages deploy . --project-name=carbsai
```

The script exits non-zero if a placeholder ever comes back.

---

## Set privacy policy — **LIVE**

The pages are built and rendered from the app's own `legal_content.dart`, so the
words on the web and the words under Settings cannot disagree. Hosted on
Cloudflare Pages rather than the Worker, because the Worker's address carries
another product's name and that URL is printed on your listing.

```
https://carbsai.pages.dev/privacy
```

Terms are at `/terms`, account deletion at `/delete-account`, on the same host.

All three return 200. The Worker's old `/privacy`, `/terms` and `/delete-account`
redirect here, so anything already pointing at it still resolves.

---

## Sign-in details — **READY**

The app requires an account, so Play needs working credentials or the review
fails on the login screen. This account exists and is seeded with a complete
profile, so targets are personalised and the plan builder works rather than
refusing.

| Field | Value |
|---|---|
| Sign-in required | Yes |
| Username | `play.review@carbsai.app` |
| Password | `CarbsaiReview2026!` |

**Instructions field:**

```
Sign in with the credentials above on the "Log In" screen. The account already
has a profile, so Home shows a personalised calorie target.

To test the AI scan: tap the sparkle icon in the bottom bar, accept the one-time
data disclosure, then press the shutter. Analysis takes about 8-12 seconds.

Free accounts include 3 AI scans. Barcode scanning, food search and typing a
meal in by hand are unlimited and need no AI.

Subscriptions are not purchasable in this build; store products are not yet
live.
```

> Before you submit, consider granting this account premium, so a reviewer who
> uses up the 3 free scans does not hit the paywall mid-review.

---

## Ads — **READY**

The APK ships the Google Mobile Ads SDK and declares
`com.google.android.gms.permission.AD_ID`. Answering "no" here is a policy
violation.

| Field | Answer |
|---|---|
| Contains ads | **Yes** — AdMob rewarded video and app-open. No banners, no interstitials. |

---

## Content rating — **READY**

An IARC questionnaire. The wording shifts between regions, but the substance for
this app is consistent.

| Question | Answer | Why |
|---|---|---|
| Category | Utility, productivity, communication or other | Non-game app |
| Violence, blood, horror | No | — |
| Sexuality, nudity | No | — |
| Crude humour, profanity | No | — |
| Controlled substances | No | Food and nutrition only |
| Gambling / simulated gambling | No | — |
| Users interact / share content | No | No social layer, no user-to-user anything |
| Shares user location | No | No location permission in the manifest |
| Allows purchase of digital goods | **Yes** | Monthly and annual subscriptions |
| Contains ads | **Yes** | AdMob |
| Shares personal info with third parties | **Yes** | Meal photos and profile figures go to the AI provider |

Expected outcome: rated for everyone in most territories.

---

## Target audience — **YOUR CALL**

My recommendation is **18 and over, only**.

- Ticking any group under 18 pulls the app into Play's *Families* policy:
  stricter ad rules, a second content review, and a ban on collecting the
  advertising ID from children — which the AdMob SDK does.
- The app sets calorie targets and a goal weight. Play's Inappropriate Content
  policy treats apps promoting disordered eating as a **removal** category. The
  code already guards this with a BMI 18.5 goal-weight floor and 1,200/1,500 kcal
  calorie floors, but an 18+ audience removes the question entirely.
- Appeals to children: **No**. Do not let the cartoon mascot tempt you otherwise
  — the answer is about the product, not the art.

> **One inconsistency to settle.** Your Terms currently say users must be at
> least 13. If you declare 18+ here, consider raising the Terms to match, or be
> ready to explain the difference.

---

## Data safety — **YOUR CALL**

The longest form and the one that gets apps suspended. Every row below is what
the code does — checked against the dependency list, the shipped manifest and
each repository.

### Data collected

| Play category → type | Collected | Shared | Purpose | Required |
|---|---|---|---|---|
| Personal info → Name | Yes | No | Account management | Required |
| Personal info → Email address | Yes | No | Account management | Required |
| Personal info → User IDs | Yes | No | Account management, App functionality | Required |
| Health & fitness → Health info | Yes | *see below* | App functionality, Personalisation | Optional |
| Photos & videos → Photos | Yes | *see below* | App functionality | Optional |
| App activity → In-app search history | Yes | No | App functionality | Optional |
| Financial info → Purchase history | Yes | No | App functionality | Optional |
| Device or other IDs | Yes | **Yes** | Advertising or marketing | Required |
| App info → Crash logs, Diagnostics | **No** | No | — | — |
| Location (any) | **No** | No | — | — |
| Contacts, Messages, Calendar, Files | **No** | No | — | — |

"Health info" here means weight, height, date of birth, gender, activity level,
goal, and the food diary. "Device or other IDs" is the advertising ID, collected
by the AdMob SDK — not by app code.

### The one judgement call: is the AI provider "sharing"?

Meal photos and profile figures are sent to OpenRouter, which routes them to
OpenAI. Play's definition of *sharing* excludes transfers to a service provider
processing on your behalf — which is arguably what OpenRouter is.

> **I would declare it as shared anyway.** The app already tells users this
> transfer happens, before it happens, in its own words. A Data safety form that
> says "not shared" while the app's own disclosure says the photo goes to a third
> party is the kind of mismatch a reviewer notices — and under-declaring is what
> gets apps suspended, while over-declaring never does. This is a call worth
> putting to a lawyer if you have one.

### Security practices

| Field | Answer |
|---|---|
| Encrypted in transit | **Yes** — every call is HTTPS: Firebase, the Worker, USDA, Open Food Facts |
| Users can request deletion | **Yes** — Settings → Delete account. The Worker erases the profile, diary, scan log, quota and subscription, then the auth user |
| Independent security review | No |
| Committed to Families policy | Not applicable at 18+ |

**Delete account URL** (asked for under Data safety):

```
https://carbsai.pages.dev/delete-account
```

---

## Government apps · Financial features — **READY**

| Field | Answer |
|---|---|
| Government app | No |
| Financial features | None of the above — subscriptions are digital goods, not a financial feature. That section is for lending, banking, crypto and payments. |

---

## Health — **READY**

Play's health declaration. The app is general wellness, not clinical — and its
own copy is already careful to say so.

| Field | Answer |
|---|---|
| Is this a health app | Yes — general wellness / fitness |
| Medical device functionality | No |
| Clinical or diagnostic use | No |
| Health research on users | No |
| Drug or treatment information | No |

> Play requires health claims to be substantiated. The app's Terms already state
> it is "not a medical device, not a healthcare provider, and not a substitute
> for professional advice" — keep the store listing consistent with that. No
> "lose 10 kg", no "clinically proven".

---

## App category and contact details — **YOUR CALL**

| Field | Value |
|---|---|
| App or game | App |
| Category | Health & Fitness |
| Tags (up to 5) | Calorie Counting · Nutrition · Weight Management · Food & Diet · Meal Planning |
| Contact email | The `LegalOperator.email` you fill in — must match the one in the privacy policy, or the two documents disagree |
| Website | Optional. `https://carbsai.pages.dev/privacy` works until you have a landing page |

---

## Store listing — **READY**

### App name

```
Carbsai: AI Calorie Counter
```

27 / 30 characters.

### Short description

```
Snap your meal and get calories and macros in seconds. AI food scanner.
```

70 / 80 characters — the second-most-weighted field for search, after the title.

### Full description

```
Carbsai turns a photo of your plate into calories and macros.

Point your camera at a meal. Carbsai reads what is on the plate and estimates
calories, protein, carbs and fat in seconds — no weighing, no scrolling through a
database, no typing.

CORRECT ANYTHING, FREE, ALWAYS
An estimate you cannot fix is worse than no estimate. Tap any food to change its
name, its weight or any macro. Change the weight and the macros rescale from the
per-gram values; type a macro yourself and it stays exactly where you put it.
Correcting a meal is never behind a paywall.

FOUR WAYS TO LOG, BECAUSE PHOTOS DO NOT ALWAYS WORK
• Photograph it — fastest when the food is in front of you
• Scan the barcode — exact figures for packaged food
• Describe it in words — for restaurants, dim light, or something you already ate
• Search the database — USDA lab-analysed reference foods, no AI, no limit

A CALORIE TARGET BUILT FROM YOUR BODY
A short quiz works out your target from your height, weight, age, activity level
and goal using the Mifflin-St Jeor equation. Deficits are capped at a quarter of
your maintenance calories and never fall below 1,200 or 1,500 kcal, because a
target you cannot keep to is not a target.

A MEAL PLAN BUILT AROUND FOOD YOU ACTUALLY LIKE
Spend about fifty seconds tapping the dishes that look good, and Carbsai writes a
one-day plan that hits your numbers using food from the cuisines you chose. Tell
it what you avoid and it is treated as a rule, not a hint — the plan is checked
against your list before you ever see it.

SEE WHETHER IT IS WORKING
• Weight, shown as a seven-day trend, because body weight swings on water alone
• Calories by meal, so you can see where the day actually goes
• Days with a full picture — logging at least two meals, the habit that best
  predicts results

WHAT YOU SHOULD KNOW
• Carbsai is not medical advice, not a medical device, and not a substitute for a
  doctor or a registered dietitian.
• To estimate your food, the photo you take is sent to our AI provider. You are
  told before it happens, and nothing is used to train AI models.
• Free accounts include a limited number of AI scans. Barcode scanning, food
  search and typing a meal in by hand are unlimited and always free.
• Premium removes ads and lifts the scan limit.

Metric or imperial, whichever you think in. Your diary, your plans and your
history all work offline.
```

~2,300 / 4,000 characters. Play indexes this text, so the keyword repetition is
deliberate.

### Graphics you still need

| Asset | Spec | Status |
|---|---|---|
| App icon | 512 × 512 PNG, 32-bit | Export from `assets/images/brand/` |
| Feature graphic | 1024 × 500 PNG or JPEG | ✅ `build/feature_graphic_1024x500.png` — regenerate with `python3 tool/make_feature_graphic.py`. Verified 1024×500, RGB, **no alpha channel** (Play rejects alpha here) |
| Phone screenshots | 2–8, min 320 px, 16:9 or 9:16 | Capture from the release build |

> The feature graphic carries no text on many surfaces — put the mascot and the
> wordmark in it, not a sentence. For screenshots, lead with the scan result: it
> is the only screen that shows what the app is for in one glance.

---

## Store compliance — verified against the shipped APK, 7 October 2026

Checked by reading the built artifact, not the source. These are the ones that
fail submissions quietly.

| Requirement | Status |
|---|---|
| **targetSdk 36 / compileSdk 36 / minSdk 24** | ✅ Play requires API 36 for new apps from 31 Aug 2026 |
| **16 KB page size** (Play, from 1 Nov 2025) | ✅ All 7 native libs aligned. `libapp.so` and `libflutter.so` at `0x10000`; the five plugin libs — including ML Kit's `libbarhopper_v3.so` — at `0x4000` |
| **APK zip alignment `-P 16`** | ✅ Pass |
| **64-bit** | ✅ arm64-v8a present |
| **Permissions minimal** | ✅ 4 declared in source. `RECORD_AUDIO` confirmed **stripped** from the merged manifest, so Play will not list "Microphone" |
| **No `READ_MEDIA_IMAGES` / `_VIDEO`** | ✅ Absent from the merged manifest, so Play's Photo and Video Permissions declaration form is **not** triggered |
| **In-app account deletion** | ✅ More → Delete Account. Confirmation sheet, then the Worker purge, then a wait that reports a real failure. Required by Play *and* App Store 5.1.1(v) |
| **Web account deletion route** | ✅ `carbsai.pages.dev/delete-account` |
| **Privacy policy reachable in-app** | ✅ More → Privacy Policy, and More → Terms and Conditions |
| **Crashlytics** | ✅ `FlutterError.onError` + `PlatformDispatcher.onError`, collection off in debug, no user identifier attached |
| **App Check** | ✅ Play Integrity + App Attest in release builds, debug providers in debug. **Enforcement deliberately off** — see below |
| **`ALLOW_UNVERIFIED_PURCHASES`** | ✅ `"0"`, so no caller can grant itself premium |
| **No placeholders left** | ✅ Nothing matching `REPLACE-WITH-*` anywhere in `lib/` or `workers/src/` |

### Two permission findings, and what was done

**`READ_EXTERNAL_STORAGE` was uncapped.** `open_filex` declares it correctly with
`maxSdkVersion="32"`, but a transitive AAR declares it uncapped and the manifest
merger keeps the broader of two declarations — so the shipped APK requested it on
every API level, and Play would list broad storage access on the app's page.
Now overridden in `AndroidManifest.xml` with `maxSdkVersion="32"` and
`tools:node="replace"`. Android 13+ ignores the permission outright, so nothing
the app can do changed.

**`FOREGROUND_SERVICE` is declared and nothing in this app starts one.** It
arrives transitively with AndroidX WorkManager. It is **deliberately left in
place**: `play-services-ads` is a plausible WorkManager consumer, and removing a
permission a bundled library may use at runtime trades a cosmetic win for a
crash nobody would see until production. No typed `FOREGROUND_SERVICE_*`
permission is declared and no service declares a `foregroundServiceType`, so the
Android 14+ `MissingForegroundServiceTypeException` path is unreachable.

> If Play Console asks for a foreground-service declaration, the honest answer is
> that the app starts no foreground service; the permission is transitive.

### iOS — `PrivacyInfo.xcprivacy` contradicted itself

It declared `NSPrivacyTracking = false` while also declaring
`NSPrivacyCollectedDataTypeDeviceID` with `Tracking = true` and a
`ThirdPartyAdvertising` purpose — and `NSPrivacyTrackingDomains` was empty.

The Google Mobile Ads SDK's **own** manifest, bundled in the binary, declares
that same `DeviceID` / `Tracking = true` pair. And the app has shipped
`NSUserTrackingUsageDescription` since ads were added: requesting ATT is the
admission that the app tracks. So `false` was simply wrong.

Now `NSPrivacyTracking = true`, with one domain — `googleads.g.doubleclick.net`.
Two facts drove that:

- Apple requires **at least one** domain once `NSPrivacyTracking` is true.
- **Google publishes no official AdMob tracking-domain list.** Their own SDK team
  has said so on the developer forum, so every publisher picks their own.

A domain listed here is documented to make requests to it **fail when ATT is
denied**. Apple does not appear to enforce that blocking yet, but it may. So each
extra entry is non-personalised ad revenue wagered on a guess about Google's
infrastructure — which is why the list holds the primary ad-request endpoint and
nothing else. Add to it only with evidence the SDK uses the domain.

### One small inaccuracy, left alone deliberately

If the Worker still reports `done: false` after 20 passes, the client shows
*"Nothing has been removed from your account."* By then some documents **have**
been removed — the passes delete as they go. The sentence is wrong in that one
path.

It is left as-is because the alternative wording ("some of your data was
removed") is worse for the person reading it: the account still exists, the app
still works, and the honest instruction is still "please try again". Reaching
this path needs an account of roughly six thousand documents, which is years of
diary. Worth fixing if anyone ever hits it; not worth a vaguer message for
everyone who does not.

---

## Before you press publish

Not Play Console tasks, but each one is a live problem in the build you would
ship.

| What | Why it matters |
|---|---|
| **Rotate every Worker secret** | A route-table bug briefly served every secret — including the Firebase service-account key — to any signed-in caller. It is fixed; the keys are still exposed. |
| **Real AdMob ids** | The manifest and the defines still hold Google's test publisher. Every impression earns nothing, silently. |
| **Store products + credentials** | Create `monthly` and `annual`, then set `PLAY_SERVICE_ACCOUNT`. Until then every purchase is refused — after the customer is charged. |
| **App Check enforcement** | Register Play Integrity, watch the metrics until the verified share settles, then enforce. Enforcing first locks out real devices. |
| **Upload an App Bundle, not an APK** | `tool/build_release.sh appbundle`. Play splits it per device and serves roughly 25 MB instead of 79. |

---

Where a question needed judgement rather than a fact, it is marked *your call*
and the reasoning is given rather than hidden.
