# Carbsai backend — Cloudflare Workers

The server leg of the app: meal analysis, email verification codes, subscription
entitlement, rewarded-ad payouts, and meal photos.

This replaces the Firebase Cloud Functions in `../functions/`. The reason is
narrow and concrete: **Spark blocks outbound calls to any non-Google host**, and
the whole point of the server leg is to call OpenAI. That made `analyzeMeal`
undeployable without upgrading to Blaze. A Worker has no such restriction, so
the project stays on the free Firebase plan.

**Firebase is still the system of record.** Auth still issues the tokens, and
Firestore still holds every document. This Worker reaches both over their REST
APIs with a service-account token — the same authority the Admin SDK had,
including bypassing security rules, which is what keeps `users/{uid}/private/**`
reachable here and nowhere else. `firestore.rules` is unchanged.

## Routes

| Route | Protocol | Replaces |
|---|---|---|
| `POST /analyzeMeal` | callable | `analyzeMeal` |
| `POST /sendEmailOtp` | callable | `sendEmailOtp` |
| `POST /verifyEmailOtp` | callable | `verifyEmailOtp` |
| `POST /activateSubscription` | callable | `activateSubscription` |
| `POST /cancelSubscription` | callable | `cancelSubscription` |
| `POST /grantBonusScans` | callable | `grantBonusScans` |
| `POST /photos`, `DELETE /photos` | plain HTTP | Cloud Storage |
| `GET /health` | plain HTTP | — |

"Callable" means the Firebase callable wire protocol — `{"data": ...}` in,
`{"result": ...}` out, `{"error": {"status", "message"}}` on failure. The app
still calls these through `cloud_functions`, using `httpsCallableFromUrl` to
point at this Worker. That is deliberate: the SDK keeps attaching the Firebase
ID token, and every error-message translation already written in the Dart
repositories keeps working unchanged.

`/photos` is plain HTTP because there is no callable shape for a binary body,
and base64-ing a photo through JSON would inflate it by a third for nothing.

## Setup

### 1. Create the R2 bucket

```bash
npm run r2:create
```

Optionally attach a custom domain to it in the Cloudflare dashboard, then set
`PHOTO_PUBLIC_BASE` in `wrangler.toml` to that origin. Until you do, uploads
still succeed but return no URL, and the diary keeps showing the local file —
the same degradation the Cloud Storage path had.

### 2. Generate a Firebase service account key

Firebase Console → Project settings → Service accounts → **Generate new private
key**. That JSON file is the Worker's entire authority over your project. Treat
it like the OpenAI key: never commit it.

### 3. Set the secrets

```bash
npm run secret FIREBASE_SERVICE_ACCOUNT   # paste the whole JSON file
npm run secret OPENAI_API_KEY
npm run secret OTP_PEPPER                 # any long random string
npm run secret EMAIL_API_KEY              # Brevo API key
npm run secret EMAIL_FROM                 # "Carbsai <no-reply@yourdomain>"
```

`OTP_PEPPER` must never change once codes are in flight — every stored HMAC is
keyed by it, so rotating it invalidates outstanding codes.

### 4. Deploy

```bash
npm install
npm run typecheck
npm run deploy
```

### 5. Point the app at it

```bash
flutter run --dart-define=WORKER_URL=https://carbsai-api.<subdomain>.workers.dev
```

Without it the app throws a `StateError` naming this exact fix, rather than
failing as a mysterious network error. `--dart-define=BACKEND=local` still runs
the whole app offline against the stub.

## What changed from the Cloud Functions version

Behaviour is otherwise identical — `prompt.ts` and `schema.ts` are copied
verbatim, and the quota, OTP and entitlement logic is a line-for-line port. Two
things genuinely differ:

**Email goes over HTTP, not SMTP.** The Cloud Function used nodemailer over
plain SMTP, chosen so any provider would work and switching would be a secret
change rather than a code change. Workers cannot open an SMTP connection. The
spirit is kept by putting the entire provider surface in one function in
`email.ts` — swapping Brevo for Resend, Postmark or Mailgun means editing one
`fetch`. Brevo is the default because it was already the suggested provider and
its free tier (300/day, no expiry) is the same over HTTP.

**The OpenAI SDK is gone.** The call is one POST, so it goes through `fetch`.
That keeps the bundle small, but it means `output_text` is assembled by hand —
that property is synthesised by the SDK, not returned by the API.

## Still not done

Both of these carried over from the Cloud Functions version unchanged:

1. **`validateReceipt` does not validate.** It grants on request. Do not ship as
   it stands — it hands premium to anyone who calls it. The Play and Apple API
   calls that replace it are named in `subscription.ts`, and a Worker *can* make
   them, which the Spark plan could not.
2. **No store server notifications.** A lapsed or refunded subscription stays
   active until `renewsAt` passes. Needs one more route per store.

## Why the npm scripts set `NODE_OPTIONS`

Every wrangler script here runs with
`NODE_OPTIONS=--no-network-family-autoselection`, and that is not decoration.

Without it, wrangler fails on this network with `ETIMEDOUT` while fetching its
auth token — a ~20-30 second hang, then `fetch failed`. It looks like an
outbound block, and is not: the browser reaches `dash.cloudflare.com` fine, and
so does `curl`. Cloudflare is dual-stack, and Node races the IPv6 and IPv4
addresses ("happy eyeballs"); when the IPv6 route does not actually work, that
race stalls rather than falling back. This flag disables the race.

`--dns-result-order=ipv4first` does **not** fix it — that reorders DNS results
but still lets Node race the families.

Use `npm run deploy` / `npm run tail` / `npm run secret NAME` rather than
calling `npx wrangler` directly, or the hang comes back.

## Watch for

**CPU time.** The free plan allows 10ms of CPU per request. Waiting on OpenAI is
not CPU time, so a 20-second analysis is fine, but parsing a ~400KB base64 body
is real work. If you see CPU-limit errors under load, the Workers Paid plan
($5/mo) raises it to 30s.
