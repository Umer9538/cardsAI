# Security review — attacker's view

20 October 2026. Against the shipped release APK (`com.carbsai.app`, versionCode 1,
signed `CN=Carbs AI, O=Lumy Labs`), `firestore.rules`, and `workers/src/`.

The question this asks is not "is the code tidy" but "what can someone do who has
the APK, a disassembler, and no account". Everything below was checked against the
real artefact, not the source alone.

---

## What held

These were attacked and did not give:

| Surface | Result |
|---|---|
| **Model API keys in the binary** | None. `strings` over `libapp.so` and the asset bundle finds no OpenAI/OpenRouter key. The Worker holds them — the entire reason the server leg exists, working as designed. |
| **Obfuscation** | `libapp.so` has zero `.debug_*` sections and zero readable Dart symbols (`package:carbsai`, `lib/features/`, class names). `--obfuscate --split-debug-info` is doing its job. |
| **Firestore rules** | `quota`, `subscription` and `scans` are `allow write: if false`. **Premium cannot be granted client-side, and the scan quota cannot be edited.** `users/{uid}/private/**` has no match block, so the OTP attempt counter and ad-payout counter fall through to the catch-all deny. Subcollections are enumerated rather than wildcarded, which is what stops a broad `match /{document=**}` from silently re-opening them. |
| **ID token verification** (`auth.ts`) | RS256 pinned, so `alg: none` and HS256 confusion are both rejected. `kid` matched against Google's JWKS, `aud` pinned to this project (a valid token from another Firebase project is refused), `iss` checked, expiry and not-issued-in-future checked, `sub` required. Malformed input returns `unauthenticated`, not a 500. |
| **Route dispatch** | The prototype-pollution hole is closed: `Object.prototype.hasOwnProperty.call` plus `typeof handler === "function"`. `POST /constructor`, `/toString`, `/__proto__` no longer reach anything. |
| **Receipt validation** | `ALLOW_UNVERIFIED_PURCHASES = "0"`. Plan and expiry come from the store's own answer, never from the request, so a caller cannot name their own entitlement. |
| **Backup / data extraction** | `backup_rules.xml` and `data_extraction_rules.xml` both exclude `com.google.firebase.auth.api.Store.xml`, the databases and the files directory, for cloud backup *and* device transfer. A restored backup does not carry a signed-in session onto a new device. |
| **Deep links** | `MainActivity` is exported with `MAIN`/`LAUNCHER` only — no `VIEW`, no `BROWSABLE`, no custom scheme. There is no intent surface to fuzz. |
| **Transport / debug** | Not `debuggable`. No `usesCleartextTraffic` (so false on API 28+). No network security config overriding CA pinning. |
| **Patching the APK for premium** | Gets you an ad-free app and nothing else. `isPremiumProvider` reads `users/{uid}/subscription/current`, which clients cannot write — and more importantly the **Worker never takes the client's word for it**: `quotaBucket()` calls `isPremium(db, uid)`, which reads that same document server-side under the uid from the verified token. So a patched client still gets `freeScanLimit: 3`. The only thing forcing the flag buys is suppressing ads for that one device, which is true of every client-side ad integration and is not fixable. |
| **Spend limiter** | Fails closed — refuses when it cannot read the counter, and `dailySpendCapUsd: 0` means stop rather than "unset". |

---

## Findings

### 1. Worker secrets were leaked and have never been rotated — CRITICAL

`PLAY-SUBMISSION.md:409` says it plainly: *"A route-table bug briefly served every
secret — including the Firebase service-account key — to any signed-in caller. It is
fixed; **the keys are still exposed.**"*

The dispatch bug is fixed. That does not un-leak a key. Anyone who called
`POST /constructor` against the deployed Worker while it was live holds:

- the **Firebase service-account private key** — which is Admin SDK authority, and
  the Admin SDK **bypasses `firestore.rules` entirely**. Every protection in the
  table above is void for whoever has it: they can read every user's diary, write
  anyone's `subscription` document to grant premium, zero any `quota`.
- the model provider key — billable against your account directly, with no spend cap
  in front of it because the cap lives in the Worker, not at the provider.
- `OTP_PEPPER` — the HMAC key that makes stored email codes non-brute-forceable.
  With it, a database leak becomes a million-guess offline attack on six-digit codes.
- `SYNC_KEY` and `STORE_NOTIFY_KEY`.

**Fix, and it is the first thing to do:** generate a new service-account key in the
Firebase console and **delete the old one**, re-issue the model key at the provider,
generate fresh `OTP_PEPPER` / `SYNC_KEY` / `STORE_NOTIFY_KEY`, then
`wrangler secret put` each and redeploy. Rotating without deleting the old
service-account key achieves nothing — the old one keeps working.

Nothing else in this document matters as much as this does.

### 2. App Check is dead code, so the free tier is a scriptable DoS — HIGH

`workers/src/appcheck.ts` exports `requireAppCheck`. **Nothing imports it.** Grep the
whole of `workers/src/` and it is never called. So App Check is not enforced — and it
is not even *verifying and logging*, which means the rollout plan written in that
file's own header ("deploy this, watch the verified share, then enforce") cannot
begin, because no metrics are being produced.

The attack is cheap and needs no reverse engineering beyond one `unzip`:

1. Pull the Firebase Android API key out of `resources.arsc`. It took one command,
   and that is fine — Google documents these as public identifiers. The boundary is
   supposed to be App Check.
2. `POST identitytoolkit.googleapis.com/v1/accounts:signUp?key=…` in a loop. No App
   Check, no CAPTCHA by default. Each response is a real uid with a real ID token
   that `auth.ts` will verify correctly, because it *is* valid.
3. Each fresh account carries `freeScanLimit: 3`, plus up to `maxAdsPerDay: 5` more
   via `grantBonusScans` — 8 scans per account per day.

At `$0.0012` a scan against `dailySpendCapUsd: 20`:

```
16,666 scans exhausts the day's budget
16,666 / 8  ≈  2,100 throwaway accounts
```

**~2,100 scripted signups and the AI feature is off for every real user until
midnight.** The spend cap is doing its job — it bounds the money to $20 — but it
converts a billing attack into a denial-of-service one, and the core feature of the
app is what goes down.

The same accounts burn the Firestore free tier from the other side: 20,000 writes a
day, and every signup writes a profile document. That one breaks the whole app, not
just scanning.

**Fix:** import `requireAppCheck` and call it in `index.ts` before dispatch. Deploy
with `APP_CHECK_ENFORCED` unset first — it logs and lets requests through — register
Play Integrity and DeviceCheck in the Firebase console, watch the verified share
settle, then set `APP_CHECK_ENFORCED = "1"`. That rollout is already designed; it
just was never wired up.

### 3. Restrict the Firebase API key — MEDIUM

Defence in depth for #2, and independently worth doing. In Google Cloud Console →
Credentials, restrict the Android key to the `com.carbsai.app` package **and** the
release SHA-1 (`88:CD:B1:CA:96:7D:BC:CF:48:CD:67:CC:D0:B3:62:BE:F2:D6:80:35`, plus
Play App Signing's certificate once enrolled), and restrict it to the APIs this app
actually uses. An unrestricted key is usable from curl; a restricted one raises the
cost of the signup loop above considerably.

### 4. `grantBonusScans` trusts the client's word — MEDIUM, accepted

The client claims it watched an ad and the server believes it. This is documented and
deliberately bounded — `maxAdsPerDay: 5`, `cooldownSeconds: 30`, `scansPerAd: 1` — so
one account's worst case is five free scans, about $0.006.

It is listed here only because it **compounds finding #2**: it is what turns 3 scans
per fake account into 8, cutting the accounts needed for the DoS by roughly two
thirds. The real fix is AdMob Server-Side Verification, which needs live ad units. Do
not raise those caps before SSV exists.

### 5. Google's test AdMob publisher ships in the manifest — MEDIUM (revenue, not security)

`android/app/src/main/AndroidManifest.xml` still carries
`ca-app-pub-3940256099942544~3347511713`, and `tool/release.env` still has test unit
ids. `tool/build_release.sh` refuses to build a real release over this and has to be
run with `--dev` to get past it, which is the guard working — but it means any build
produced that way serves test creatives and earns nothing, silently and forever.

Correct for closed testing (serving real ads to your own testers is invalid traffic
and gets AdMob accounts suspended). It must change before production.

---

## What this review could not reach

- **Whether the leaked secrets have in fact been rotated.** The repository says they
  have not. If that is out of date, finding #1 is void — but it should be confirmed
  rather than assumed.
- **The live Worker's runtime behaviour.** Everything above is static analysis plus
  the shipped artefact. No request was sent to the deployed Worker as part of this
  review beyond the app's own normal use.
- **iOS.** The App Store build cannot be produced at all right now: the Apple
  Developer team's Program License Agreement is unsigned, so no provisioning profile
  can be issued. The iOS binary was therefore never built for a device, let alone
  examined.
- **Firebase console settings** — email-enumeration protection, quota alerts, App
  Check registration status, API key restrictions. All of these are configuration
  rather than code and none is visible from the repository.
- **No exploitation was performed.** No accounts were scripted, no secrets were
  pulled from the live Worker, no rate limit was tested by exceeding it. The numbers
  in finding #2 are arithmetic over the constants in `scan.ts` and `rewards.ts`, not
  a measured attack.
