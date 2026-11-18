# Capacity: what this app can carry today, and what "millions" would take

18 November 2026. Measured against the deployed configuration, not a plan.

**Short answer: the app supports roughly 1,000–1,500 daily active users today,
and it is three orders of magnitude away from millions.** The gap is not one
problem. It is a billing plan, one hard architectural bottleneck that money
cannot fix, and an inference bill that decides whether any of it is worth doing.

---

## The binding constraint is Firestore's free tier

Firebase is on **Spark**, deliberately — `wrangler.toml` and `workers/README.md`
both explain that the server leg moved to Cloudflare precisely so the project
would not need Blaze. That decision is sound for launch and is the ceiling now.

Spark gives **20,000 document writes and 50,000 reads a day.**

Counting the writes one engaged user actually makes in a day:

| Action | Writes |
|---|---|
| Scan a meal | 3 — quota reserve, scan log, spend counter |
| Log the result | 1 |
| Log a meal by hand / barcode / search | 1 each |
| A glass of water | 1 (people log several) |
| A weight reading | 1 |
| An activity bout | 1 |

Two scans, three meals, four glasses and a weigh-in is **about 14 writes**.

```
20,000 writes/day ÷ 14  ≈  1,430 daily active users
50,000 reads/day  ÷ ~45 ≈  1,100 sessions/day
```

So **~1,000 DAU**, and reads bind at almost the same point.

**What happens at the ceiling is the dangerous part.** Firestore starts
refusing, and the client SDK's offline cache *accepts the write and serves it
straight back*. The app looks like it is working. The diary shows the meal. The
data is gone on the next cold start. This is the exact failure mode CLAUDE.md
already documents for the catalogue reconcile — "the offline cache accepts the
write and serves it straight back… the app looks correct until the next cold
start" — and at the quota wall it applies to every user's food diary at once.

That is the downtime question, answered: the app does not go down. It silently
stops saving, which is worse, because nobody gets an error to report.

---

## One thing money cannot fix: the spend counter was a single document

**Fixed in this pass — the rest of this section is the reasoning, kept because
the constraint is permanent and someone will be tempted to undo it.**

`workers/src/spend.ts` keeps the day's total model spend in **one Firestore
document**, `config/spend-YYYY-MM-DD`, and `recordSpend` increments it on every
single model call — every scan and every plan generation.

Firestore's sustained write limit on a single document is about **one write per
second**. Beyond that, transactions contend and fail.

```
1,000,000 DAU × 2 scans      =  2,000,000 writes/day to ONE document
                             ≈  23 writes/second sustained, far more at peak
                             ≈  23x over the hard per-document limit
```

Upgrading to Blaze does not move this. It is a property of how Firestore shards
documents, and it would start failing long before a million users — the maths
says contention becomes visible in the **low tens of thousands of DAU**.

`assertUnderDailyCap` also *reads* that same hot document before every model
call, so it is a read-and-write hotspot on the critical path of the app's core
feature.

**The fix is a sharded counter**, and it is now in place: `recordSpend` writes
to one of **16** randomly chosen shards and `assertUnderDailyCap` sums all of
them through a new `Firestore.batchGet`, which is one round trip rather than
sixteen. That buys 16x the write ceiling — several hundred thousand daily users,
well past anything else in the system — for the cost of sixteen document reads
per model call instead of one.

Three properties worth keeping: the random shard is chosen per *call*, not per
uid, because spreading by uid would give one heavy account one shard and the
same ceiling back; the old single-document path is still summed in, so a deploy
landing mid-day cannot reset the fuse to zero and hand out a second $20; and
`batchGet` throws on a malformed response rather than returning nothing, because
"nothing found" would read as zero spent and open the fuse at exactly the moment
something is wrong.

Raising `SHARDS` later is safe and backwards compatible. **Lowering it is not** —
spend already sitting in a shard above the new count stops being counted.

Nothing else in the data model has this shape: quota, subscription, meals,
water and weights are all under `users/{uid}`, so they shard naturally by user
and scale without changes.

---

## What a million daily users would actually cost

Assuming Blaze and the sharded counter, per month:

| | Volume/day at 1M DAU | Cost/month |
|---|---|---|
| Firestore writes | 14M | ~$760 |
| Firestore reads | 45M | ~$810 |
| Cloudflare Workers | 10M requests | ~$90 |
| Firebase Auth (Identity Platform) | — | ~$0.0055/MAU over 50k |
| **Model inference** | **see below** | **the whole question** |

Infrastructure is a few thousand dollars a month and is not the problem.

**Inference is.** A scan costs about **$0.0012**. If a million daily users each
scanned twice:

```
2,000,000 scans/day × $0.0012  =  $2,400/day  =  ~$72,000/month
```

The `dailySpendCapUsd: 20` fuse would trip 120 times over before lunch. That
cap is correct as a fuse and is not a plan — at scale it has to become a real
budget backed by revenue.

### The free tier is what keeps that number down, and it has a hole

Free accounts get `freeScanLimit: 3` **which never renews**, so most users
cannot reach two scans a day. That bounds the bill far below the figure above —
good.

But `grantBonusScans` lets anyone earn **5 more per day** by watching rewarded
ads (`maxAdsPerDay: 5`, `scansPerAd: 1`), and CLAUDE.md already records the
economics: at the ~$1 CPM these markets see, a rewarded impression earns about
**$0.001** against a scan that costs **$0.0012**. Every ad-funded scan in a
Tier-2 market loses money. At a thousand users that is pocket change. At a
million it is a **structural loss of roughly $200/day** that grows with
engagement.

Two things follow, and they are product decisions rather than engineering ones:

1. **AdMob Server-Side Verification before any growth.** `grantBonusScans`
   trusts the client's word today; it is bounded to five a day, which is fine
   at this size and is not fine when uids are free and plentiful. CLAUDE.md
   already says not to raise those caps before SSV exists. The same note should
   now read: do not *grow* before SSV exists.
2. **The subscription has to carry inference.** At $5/month and $0.0012 a scan,
   one subscriber funds about 4,000 scans. That is a comfortable margin — the
   model works, but only if conversion is real. Roughly **1.5% conversion
   covers inference at a million users**; below that, scanning is subsidised by
   the founder.

---

## What stays up, and what does not

**Genuinely resilient.** Cloudflare Workers are stateless and edge-distributed
with no instance to fall over. Firestore is Google-managed. Firebase Auth is
Identity Platform. None of these is a single point of failure, and none needs
work to carry a million users.

**Single points of failure, in order of likelihood:**

1. **OpenRouter.** One provider in front of every scan and every plan. If it is
   down or rate-limits the account, the app's core feature is down. The
   `config/scan.baseUrl` switch means failover is a Firestore edit rather than
   a release, which is the right design — but it is **manual**, so the
   mean-time-to-recovery is however long it takes a person to notice. Automatic
   failover to a second provider is the obvious next step and is not built.
2. **The `config/scan` document.** Read on every scan. Firestore caches it, but
   it is a dependency on the critical path.
3. **FDC.** Already handled — `searchFoods` retries five times and
   `WorkerFoodRepository` falls back to Open Food Facts.

**Cold start:** the app has no server-side render path and `main()` falls back
to local only in debug; a release build with a broken config shows
`_MisconfiguredApp` rather than inventing nutrition figures. That is the right
trade and it means a bad deploy is visible rather than silent.

---

## The order to do this in

Nothing below is speculative; each is a known constraint hit in sequence.

1. ~~**Shard the spend counter.**~~ **Done.** It was the one ceiling money does
   not lift, and it bit in the low tens of thousands of daily users.
2. **Move to Blaze, and set a budget alert.** Spark's 20k writes is ~1,000 DAU.
   Blaze removes the wall; a budget alert is what stops it removing the floor
   from under your bank account too.
3. **AdMob SSV**, before any growth spend, per the note above.
4. **Watch conversion before scaling acquisition.** Inference is the dominant
   cost at every size above a few thousand users, and the subscription is the
   only thing that pays for it.
5. **A second model provider**, configured and tested, so the `baseUrl` switch
   is a drill rather than an experiment conducted during an outage.
6. **Move `foods` out of Firestore** when search volume makes the read quota
   bite — CLAUDE.md already names Cloudflare D1 and the reason (5M row-reads a
   day free, and FTS5 would fix the ranking problem outright).

---

## What this document does not cover

- **No load test has been run.** Every number here is arithmetic over the
  constants in `scan.ts`, `rewards.ts` and `wrangler.toml`, plus published
  Firestore quotas and prices. The spend-counter contention figure in
  particular is a calculation, not an observed failure.
- **Write-per-user is an estimate** from reading the code paths, not telemetry.
  The app records scan cost and latency per call but does not count Firestore
  operations, so the ~14 figure could be out by a few either way. It is not out
  by the 1,000× that separates this from "millions".
- **Firestore prices** are the us-central list rates at the time of writing and
  vary by region.
