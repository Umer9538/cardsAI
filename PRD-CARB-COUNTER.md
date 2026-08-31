# PRD — CarbLens (working name)
## AI Food-Photo Carb Counter for Diabetics & Low-Carb Eaters

**Version:** 1.0 · **Date:** 2026-08-21 · **Status:** Ready for development
**Platforms:** iOS first (SwiftUI), Android port after validation · **Target build time:** 3–5 months to MVP

---

## 1. Product Overview

CarbLens answers one question in one photo: **"How many carbs are in this?"**

Cal AI proved the photo→nutrition mechanic at $30M ARR — but it, and its clone wave, chase *calories* for dieters. Nobody owns **carbs** for the people who need them most: people with type 2 diabetes, prediabetes, and keto/low-carb eaters, who count carbs (not calories) at every single meal, forever. Incumbent diabetes apps (MySugr, Glucose Buddy) are aging, logging-heavy, and have no modern vision AI. Diabetes management app market: $2.1B → $4.8B.

The user points their camera at a plate; CarbLens identifies the foods, estimates portions, and returns **total carbs, net carbs, and a glycemic-impact rating** — logged in 10 seconds instead of 3 minutes of database searching.

**Hard product line (compliance):** CarbLens estimates and logs. It **never** gives insulin dosing advice, never predicts blood glucose, never diagnoses. It is a nutrition logging and education tool.

---

## 2. USP (Unique Selling Proposition)

> **"Point. Shoot. Know your carbs."** — the first carb-native AI food scanner, built for people who count carbs because they have to.

1. **Carb-first, not calorie-first.** Every result leads with total carbs / net carbs / glycemic load. Calories, protein, fat are secondary. The entire UX speaks the language of diabetes educators and keto coaches ("carb budget," "net carbs," "GI"), which generic calorie apps don't.
2. **Glucose context (the moat).** Users can log glucose readings (manual, or auto-read from Apple Health where their CGM already writes) and see their *own* meal→glucose response history: "Last 3 times you ate pizza, your 2-hour rise averaged +58 mg/dL." No calorie app can offer this; it compounds into a personal dataset that makes leaving costly. *(Insight display only — never predictive, never dosing.)*
3. **Built for every-meal speed.** Hard 10-second target from camera to logged meal. Diabetics log 3–6×/day for life — speed is retention.

**Positioning statement:** For people with diabetes, prediabetes, or on keto who must count carbs at every meal, CarbLens is the AI food scanner that reads carbs from a photo — unlike calorie counters built for dieters and legacy diabetes apps built for spreadsheets.

---

## 3. Target Users & Personas

**P1 — Newly diagnosed T2D.** Linda, 58, told to "watch her carbs" three weeks ago. Overwhelmed, doesn't know what a carb is in real food. Needs: instant answers, gentle education, a daily budget. Highest willingness to pay; searches "diabetes food tracker," "carb counter."
**P2 — Keto/low-carb lifestyle.** Jake, 34, tracks net carbs to stay under 25g. Needs: net-carb math (fiber/sugar-alcohol subtraction), keto-friendliness verdicts. Searches "carb tracker keto," "net carb counter."
**P3 — Established T1D/T2D carb-counter.** Maria, 45, counts carbs for insulin ratios she manages with her doctor. Needs: fast accurate carb totals and portion editing. *(We show carbs; she applies her own medical plan — we never touch dosing.)*
**P4 — Caregiver logging for a spouse/parent** (natural cross-promo with CareCircle later).

---

## 4. Goals & Success Metrics

| Metric | Target (month 6) |
|---|---|
| Activation: ≥1 successful scan | ≥70% of installs |
| Scan satisfaction ("looks right" tap) | ≥75% of scans |
| Camera→logged median time | ≤10s |
| Trial → paid | ≥40% (health category avg 62% is top-end) |
| Download → paid (hard paywall benchmark) | ≥8% |
| D30 retention (payers) | ≥25% |
| AI cost per scan | ≤$0.02 blended |
| Rating | ≥4.6★ |

North star: **meals logged per active user per week** (target ≥10).

---

## 5. Core Features — MVP (v1.0)

### 5.1 Onboarding Quiz → Personalization → Paywall
Sequence (the Quittr/Noom pattern; quiz completers convert >10% vs 2.7% median):
1. "What brings you here?" → T2D / prediabetes / T1D / keto-low-carb / just curious → sets **mode** (Diabetes mode vs Keto mode) and disclaimer copy.
2. "Do you have a daily carb target from your doctor or plan?" → number entry or "help me pick a starting range" (educational presets with sources; clearly labeled general guidance, not medical advice).
3. "How do you currently count carbs?" (labels/guessing/app/don't) → tailors education cards.
4. Height/weight/age optional (skippable — not required for carb counting).
5. **Demo scan on a sample photo** (bundled image, no API call) — shows the magic before asking for money.
6. Personalized plan screen ("Your daily budget: 120g · Mode: Diabetes · Insights unlock after 10 meals") → **hard paywall with trial**.
7. Medical disclaimer interstitial (must acknowledge): *"CarbLens provides nutritional estimates for informational purposes. It does not provide medical advice or insulin dosing guidance. Consult your healthcare provider."*

**Acceptance criteria:** quiz completable in <90s; every step skippable except mode + disclaimer; free tier grants 3 real scans before paywall re-blocks (taste of value).

### 5.2 AI Food Scan (the product)
**Flow:** Camera (or gallery pick) → capture → optional 1-line hint field ("chicken burrito, no rice") → analyzing state (target p50 <4s) → results card.

**Results card:**
- Identified items list, each with: name, estimated portion (with household units — "1 cup ≈ fist"), carbs g, fiber g, sugar g, **net carbs g**, calories, protein, fat.
- Headline: **Total carbs** (Diabetes mode) or **Total net carbs** (Keto mode), plus glycemic-impact badge (Low/Med/High — derived from GI reference table for identified foods, labeled "estimate").
- Per-item edit: tap to adjust portion (slider: ½× ¾× 1× 1.5× 2× or grams), swap item (search fallback), remove item, add missed item.
- Confidence handling: items the model flags low-confidence render with a "check this" chip; if the whole scan is low confidence → "Help me out — what is this?" text prompt and re-analyze.
- "Looks right ✓" confirm → logged to diary. One-tap "Log again" for repeated meals.

**Non-photo fallbacks (must-have; photos fail in restaurants/low light):**
- **Barcode scan** → Open Food Facts database (free, no licensing cost) → same results card.
- **Describe it** → free-text ("two slices pepperoni pizza and a side salad with ranch") → same AI pipeline, text-only.
- **Search** → local bundled database of ~1,000 common foods (USDA FoodData Central extract, public domain) for offline/quick manual adds.

**Acceptance criteria:** end-to-end scan p50 <6s, p95 <12s on LTE; results editable before and after logging; every scan produces a result or an actionable error (never a dead end); works on iPhone 12+; all three fallbacks functional offline-degraded (barcode/search offline where cached; describe requires network).

### 5.3 AI Pipeline (technical spec)

- **Architecture:** the app NEVER calls the model API directly (no keys in the client). App → our backend (Supabase Edge Function) → Anthropic API → structured JSON → stored + returned. Backend enforces per-user quotas, strips EXIF/GPS, and logs cost per scan.
- **Model:** Anthropic Claude via Messages API, model `claude-opus-5` (vision, structured outputs). Evaluate `claude-haiku-4-5` ($1/$5 per MTok vs $5/$25) on the eval set during development as the cost-optimized option — ship whichever passes the accuracy bar; the model ID must be a server-side config value, switchable without app release.
- **Image handling:** client downsizes to ~1280px long edge, JPEG q80 (~150–300KB) before upload — keeps image cost ~1,100–1,600 tokens/scan; full-res unnecessary for plate recognition.
- **Structured outputs:** use `output_config.format` (JSON schema) so responses are guaranteed-parseable. Schema:

```json
{
  "type": "object",
  "properties": {
    "items": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "name": {"type": "string"},
          "portion_desc": {"type": "string"},
          "portion_grams": {"type": "number"},
          "carbs_g": {"type": "number"},
          "fiber_g": {"type": "number"},
          "sugar_g": {"type": "number"},
          "calories": {"type": "number"},
          "protein_g": {"type": "number"},
          "fat_g": {"type": "number"},
          "glycemic_index_band": {"type": "string", "enum": ["low", "medium", "high", "unknown"]},
          "confidence": {"type": "string", "enum": ["high", "medium", "low"]}
        },
        "required": ["name", "portion_desc", "portion_grams", "carbs_g", "fiber_g", "sugar_g",
                     "calories", "protein_g", "fat_g", "glycemic_index_band", "confidence"],
        "additionalProperties": false
      }
    },
    "overall_confidence": {"type": "string", "enum": ["high", "medium", "low"]},
    "clarifying_question": {"type": ["string", "null"]}
  },
  "required": ["items", "overall_confidence", "clarifying_question"],
  "additionalProperties": false
}
```

- **System prompt requirements (server-side, versioned):** identify foods and estimate portions from visual cues (plate size, utensils); prefer USDA-consistent nutrition values; when uncertain between similar foods choose the more common one and mark confidence; NEVER include medical advice, insulin, or dosing language in any field; respond only via the schema.
- **Server post-processing:** compute net carbs (carbs − fiber − sugar alcohols when detectable); clamp absurd values (single item >300g carbs → flag); attach GI band from our reference table when the model returns `unknown`.
- **Cost model (validate in week 1 of development):** ~1,600 image tokens + ~700 prompt tokens in, ~400 tokens out. At Opus 5 pricing ≈ $0.011 in + $0.010 out ≈ **~$0.02/scan**; at Haiku 4.5 ≈ **~$0.004/scan**. At 10 scans/user/day worst case: $0.20/day Opus vs $0.04 Haiku — this is why quotas (5.7) and the model-eval bar exist.
- **Eval set (built before UI polish):** ≥150 labeled food photos (weighed portions) across cuisines; accuracy bar for ship: total-carb estimate within ±25% on ≥80% of eval photos, item identification ≥90%. Re-run on every prompt/model change.

**Acceptance criteria:** zero API keys in the app binary; malformed model output (schema violation) auto-retries once then falls back to "describe it" flow; per-scan cost logged to analytics; prompt + model configurable server-side.

### 5.4 Daily Diary & Carb Budget
- Home screen = today: carb budget ring (consumed / remaining), meals list (photo thumbnails), quick-add buttons (Scan / Barcode / Describe / Search / Recent).
- Meal slots (breakfast/lunch/dinner/snack) auto-assigned by time, editable.
- Keto mode: ring counts **net carbs**; foods get keto verdict chips (✓ keto / caution / ✗).
- Streak counter: consecutive days with ≥2 logged meals (drives ratings prompt + retention).
- History: calendar view, per-day detail, 7/30-day averages.

**Acceptance criteria:** diary fully functional offline (scans queue); budget editable anytime; day rolls over on local midnight.

### 5.5 Glucose Log & Meal Insights (Diabetes mode; premium)
- Manual glucose entry (mg/dL or mmol/L, unit setting) with context tag: fasting / before meal / 1h after / 2h after / bedtime.
- **HealthKit read (iOS):** with permission, import glucose samples written by CGM apps (Dexcom, Libre write to Apple Health) — no direct CGM SDK integration in MVP. Android port: Health Connect equivalent.
- **Meal Insights:** for meals with a glucose reading within 30min before and 90–150min after, compute the delta and display it on the meal card. Aggregate view: "Your top 5 spike meals" / "Your 5 friendliest meals."
- **Hard compliance rules:** display of the user's own recorded history ONLY. No prediction ("this will spike you"), no recommendations tied to glucose ("eat less X"), no dosing. Copy reviewed against this rule before every release.

**Acceptance criteria:** HealthKit permission optional and app fully works without it; units handled correctly everywhere; insight cards show only with ≥1 valid before/after pair.

### 5.6 Education Cards (retention + SEO surface)
- 30 bundled micro-lessons (300–500 words): "What are net carbs?", "Reading labels for diabetes," "GI vs GL," "Eating out low-carb." One surfaced per day on the diary.
- Written/reviewed with a credentialed source (hire a registered dietitian for content review — ~$1–2K, also a marketing asset: "Reviewed by an RD").

### 5.7 Accounts, Quotas & Subscription Plumbing
- Auth: Sign in with Apple (primary), email fallback. Account required for scans (quota enforcement + sync).
- **Quota:** free = 3 lifetime scans; premium = 100 scans/month fair-use soft cap (covers 99% of users; heavy users get a friendly cap message and a booster pack). Barcode/search/describe-text: unlimited (negligible cost — text-only describe ~$0.003).
- **Consumable booster:** 100 extra scans $4.99 (covers API cost 5–10×; monetizes over-cap users without raising base price).
- RevenueCat: entitlement `premium`; Experiments for paywall tests; Superwall optional later.

### 5.8 Export & Doctor Report (premium)
- CSV export (meals, carbs, glucose) and a monthly PDF summary (avg daily carbs, adherence to budget, glucose-tagged meals) to bring to appointments. Generated on-device.

---

## 6. Monetization Spec

**Model:** hard paywall after onboarding value moment (demo scan + plan) — converts ~5x freemium per RevenueCat data; free tier is a 3-scan taste, not a usable product.

| SKU | Price (US) | Notes |
|---|---|---|
| Weekly | $7.99/wk | Anchor; 3-day intro option tested via experiment |
| **Annual** | **$49.99/yr** | Hero SKU, "≈$0.96/week"; 14-day trial |
| Lifetime | $129.99 | Sub-averse users (diabetes = decades-long need) |
| Scan booster (consumable) | $4.99/100 scans | Over-cap users |

Plan mix expectation (health category): ~68% annual. Paywall placements: onboarding (primary), scan #4 attempt, insights tab, export. Price localization via RevenueCat + store price tiers. Win-back: churned-user discount offer (40% off annual) after 30 days.

**Unit economics guardrail:** annual payer = $49.99 gross → ~$42.49 after 15% store cut → AI cost at 6 scans/day × 365 × $0.004–0.02 = $8.76–$43.80/yr. **This is why the Haiku-tier eval matters and why the scan cap exists** — at Haiku-tier costs margins are ~75%; at Opus-tier the cap + booster keeps worst-case users profitable. Track blended cost/user/month as a first-class metric from day one.

---

## 7. Screens (information architecture)

```
Tab bar: Today · History · Insights · Learn · Settings
Today     → budget ring, meals, quick-add row (Scan/Barcode/Describe/Search/Recent)
Scan flow → camera → hint → analyzing → results card → edit → confirm
History   → calendar, day detail, averages
Insights  → glucose log, meal-response cards, top/friendly meals (premium)
Learn     → education cards
Settings  → mode (Diabetes/Keto), carb target, units, HealthKit, account, subscription,
            export, disclaimers/about
Onboarding→ quiz (7 steps) → demo scan → plan → paywall → disclaimer
Widgets   → today's remaining carbs (small), streak (small)
```

---

## 8. Technical Requirements

### 8.1 Stack
- **iOS: SwiftUI**, min iOS 16. AVFoundation camera; VisionKit for barcode; HealthKit (glucose read only); WidgetKit; StoreKit 2 via RevenueCat SDK.
- **Backend: Supabase** — Auth, Postgres, Edge Functions (`/scan` endpoint wrapping Anthropic API via the official TypeScript SDK, `/describe`, `/quota`, RevenueCat webhook), Storage (meal photos; user-deletable; photos private per-user via RLS).
- **Anthropic API integration (Edge Function):** official `@anthropic-ai/sdk`; image passed as base64 block + text prompt; `output_config.format` with the schema in 5.3; `max_tokens` 2048; retries per SDK defaults; timeout 25s with client-side "still working" state at 8s. Handle `stop_reason` values other than `end_turn` (including `refusal`) by returning a structured error → app falls back to describe/search flow.
- **Local:** SwiftData/CoreData cache of diary + foods; scan queue for offline capture (upload when online).
- **Android port (post-validation, month 6+):** decision point — Kotlin/Compose native or Flutter rewrite of both; backend unchanged either way. Not in MVP scope.

### 8.2 Data model

```
users            id, auth_id, mode(diabetes|keto), carb_target_g, units(mgdl|mmol), created_at
scans            id, user_id, photo_path?, input_type(photo|barcode|text|search),
                 raw_model_json, model_id, tokens_in, tokens_out, cost_usd, latency_ms,
                 overall_confidence, created_at
meals            id, user_id, scan_id?, slot(breakfast|lunch|dinner|snack), eaten_at,
                 confirmed bool
meal_items       id, meal_id, name, portion_desc, portion_grams, carbs_g, fiber_g, sugar_g,
                 net_carbs_g, calories, protein_g, fat_g, gi_band, source(ai|barcode|db|manual),
                 user_edited bool
glucose_readings id, user_id, value, unit, context_tag, source(manual|healthkit), measured_at
quotas           user_id, period_start, scans_used, scans_limit, booster_balance
gi_reference     food_pattern, gi_band          -- server-side lookup table
edu_cards        id, title, body_md, mode_filter, order
```

### 8.3 Analytics events
`onboarding_step_x`, `quiz_completed{mode}`, `demo_scan_viewed`, `paywall_viewed{placement}`, `trial_started`, `purchase{sku}`, `scan_started{input_type}`, `scan_result{latency, confidence, item_count, cost}`, `scan_edited{field}`, `scan_confirmed`, `scan_failed{reason}`, `meal_logged`, `glucose_logged{source}`, `insight_viewed`, `streak_day{n}`, `booster_purchased`, `export_generated`. Dashboards: scan funnel, cost/user, accuracy proxy (edit rate — % of scans where user changed carb values >20%).

### 8.4 Ratings prompt triggers
Native prompt after: 7-day streak, or 25th confirmed scan, or first "friendliest meals" insight viewed. Never after a failed scan. iOS cap 3/yr respected; settings "Rate us" uses uncapped deep link.

---

## 9. Compliance, Privacy, Policy (hard requirements)

- **Never**: insulin/medication dosing advice, glucose prediction, diagnosis, treatment claims, "manage/treat/control your diabetes" language anywhere (app, store listing, paywall, notifications). Allowed framing: "track," "log," "understand," "estimate," "count carbs with confidence."
- **Google Play Health policy (Aug 2025 / Jan 2026):** health declaration in Console; disclaimer in first paragraph of store description; expect extended review (4–7 days) — plan release timelines accordingly.
- **Apple:** guideline 5.1.3 (health data may not be used for advertising; we don't); HealthKit data never leaves device except user-initiated export; App Privacy labels: Health & Fitness, Photos (camera), linked to user. New age-rating questionnaire: medical/wellness section answered "wellness/log," expect 12+/13+ tier.
- **Accuracy honesty:** results labeled "AI estimate"; onboarding + results footer: "Estimates can be off, especially for mixed dishes. Adjust portions when you know better." This is both legal cover and trust-building (review mining shows users punish overconfident AI).
- **Photos:** EXIF/GPS stripped server-side; user can disable photo storage (analysis-only mode); deletion cascades. GDPR/CCPA export + delete. Account deletion in-app + web (Play requirement).
- **AI content policy (Play):** in-app "report a wrong/inappropriate result" action on every results card (required for gen-AI apps; also feeds the eval set — dual purpose).

---

## 10. ASO Requirements (bake into the build)

- iOS title: `CarbLens: Carb Counter AI` · subtitle: `Diabetes & Keto Food Tracker` · keyword field: `carb,counter,diabetes,diabetic,keto,tracker,glucose,sugar,food,scanner,net,log`
- Play title: `CarbLens: AI Carb Counter`; short: `Snap a photo, get carbs instantly. Built for diabetes & keto tracking.`; long description clusters: *carb counter, carb tracker for diabetes, diabetic food tracker, net carb counter keto, food scanner, glycemic index, blood sugar diary* (+ first-paragraph disclaimer per health policy).
- Screenshots 1–3: 1) photo→carbs hero shot ("Carbs in 10 seconds"), 2) budget ring ("Stay in your carb budget"), 3) insights ("Learn how meals affect YOU"). Captions keyword-bearing (OCR-indexed on iOS since June 2025).
- CPPs: one per intent — "keto" CPP (net-carb visuals) keyword-assigned to keto terms; "diabetes" CPP to diabetes terms.
- In-app events for seasonal pushes (New Year, Diabetes Awareness Month — November).

---

## 11. Out of Scope for MVP (v1.1+ roadmap)

Direct CGM SDK integrations (Dexcom/Libre APIs — HealthKit read covers MVP) · meal recommendations/planning · recipes · social/community · Android app · Apple Watch app · voice logging · restaurant-menu database · insulin-related features of any kind (permanently out, not just MVP) · web dashboard · additional languages (English-only MVP; es-MX metadata for ASO only).

## 12. Milestones

| Phase | Weeks | Deliverable |
|---|---|---|
| M1 | 1–2 | Backend `/scan` pipeline + structured outputs + **eval set & accuracy report** (go/no-go + model choice) |
| M2 | 3–6 | Camera flow, results card, editing, barcode/describe/search fallbacks |
| M3 | 7–9 | Diary, budget, streaks, offline queue, widgets |
| M4 | 10–11 | Onboarding quiz, paywall (RevenueCat), quotas, booster |
| M5 | 12–13 | Glucose log + HealthKit + insights, education cards, export |
| M6 | 14–16 | Polish, TestFlight beta (50+ users incl. real diabetics), store assets, health-policy review buffer, submission |

**Definition of done (MVP):** a new user goes quiz → trial → 10 logged meals across all four input types with p50 scan <6s and edit-rate <35%; AI cost per active user tracked and within model; crash-free ≥99.5%; zero dosing/medical-advice language verified by checklist review of every user-facing string.
