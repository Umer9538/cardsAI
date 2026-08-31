# Carbsai

AI-powered nutrition tracking from a food photo. Point the camera at a plate, get
calories and macros, log the meal.

Flutter — iOS and Android. Firebase project `carbsai-8cca8`.

## Status

The app runs end to end on real data: Firebase accounts, a Firestore-backed diary
with live totals, saved plans and favourites, notifications, profile, charts driven
by the diary, and real camera capture.

**The scan pipeline is live.** `workers/` holds the backend as a Cloudflare Worker:
it verifies the Firebase ID token, reserves quota transactionally, calls the model
with a strict JSON schema, and writes a per-scan cost record. It runs on Cloudflare
rather than Cloud Functions because Firebase's Spark plan blocks outbound calls to
any non-Google host, and the analysis calls one — so this stays on the free Firebase
plan. `--dart-define=BACKEND=local` still runs the whole flow offline against a stub.
See `CLAUDE.md` for what is and is not real.

## Getting started

```bash
flutter pub get
flutter run --dart-define=WORKER_URL=https://carbsai-api.<subdomain>.workers.dev
flutter run --dart-define=BACKEND=local  # on-device only, no network
```

Before Firebase sign-in works:

1. **Authentication → Sign-in method → enable Email/Password**
2. **Firestore → create the database**, then `firebase deploy --only firestore:rules`

And for the scan pipeline — no Blaze needed, see `workers/README.md`:

```bash
cd workers && npm install
npm run secret FIREBASE_SERVICE_ACCOUNT   # pipe the json file in, do not paste it
npm run secret OPENAI_API_KEY             # or OPENROUTER_API_KEY
npm run deploy
```

Until all that is done the app surfaces a message naming the exact fix, and
`--dart-define=BACKEND=local` runs the whole app offline in the meantime.

## Development

```bash
flutter analyze                  # must stay at "No issues found"
flutter test                     # 58 tests, ~25s
flutter test test/foo_test.dart  # single file
```

Render tests write a 3× PNG to `build/<name>_actual.png` for diffing against a Figma
export.

## Architecture

Screens are laid out on the Figma artboard's own 428 × 926 coordinate system using raw
design numbers, then mapped to the device by `DesignCanvas`. Data reaches them through
Riverpod providers that resolve to either the on-device or the Firebase implementation
of a repository interface.

**Read `CLAUDE.md` before touching any screen** — the DesignCanvas convention is
deliberate and easy to break by accident, and it records which apparent oddities in
the code are intentional.

```
lib/
├── main.dart          splash → onboarding → auth → MainShell
├── app/               the signed-in shell and its tabs
├── core/              design system, models, repository contracts, providers
├── data/local/        on-device repositories + seed data
├── data/firebase/     Firebase Auth, Firestore, Functions scan client
└── features/          analysis, app, auth, diets, favorites, onboarding,
                       premium, scan, settings, splash

functions/src/         analyzeMeal — the OpenAI scan pipeline (TypeScript)
```

## Documents

- `CLAUDE.md` — architecture, conventions, and current state. Start here.
- `PRD-CARB-COUNTER.md` — a spec for a **different**, carb-first diabetes/keto product.
  Not what is built. Treat as a v2 document.
