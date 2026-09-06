# Ganesh Revenue Intelligence Engine — Week 1 Foundation Layer

Autonomous signal collection across the portfolio: Stripe, App Store Connect,
Vercel, and Supabase itself, landing in an isolated `ganesh` schema for a
future reasoner (Week 2) to synthesize into a health brief.

## ⚠️ Before you deploy this

**Target Supabase project ID mismatch.** The spec named project
`dvomzrvslwdabwcwtvrg`, but the only Supabase project this session's
connector can see is `hcpzbxplnkyythzwkovy` ("Unicorn Porn's Mangasm"). These
are different projects. I have **not** applied the migration anywhere — it's
a file, same as every other migration in this repo, for deliberate review and
apply. Confirm which project Ganesh actually targets before running it:
- If `dvomzrvslwdabwcwtvrg` is correct: link/add that project so it can be
  reached, then apply the migration there.
- If you meant the Mangasm project: say so and I'll point at it explicitly —
  but note Mangasm's `service_role` key would then have full access to
  Mangasm's `public` schema too (see the RLS note below), which may not be
  the isolation you want for a cross-portfolio revenue engine.

## What's here (Week 1 scope)

```
ganesh-engine/
  migrations/001_create_ganesh_schema.sql   # DDL — see below
  src/
    types.ts                                # Severity, SignalInput, CollectorResult
    lib/
      supabase-client.ts                    # schema-scoped service-role client
      ingest.ts                             # idempotent upsert on (source, external_id)
      health.ts                             # fail-soft wrapper + health/alert logging
      appstore-jwt.ts                       # ES256 JWT signer, node:crypto only
    collectors/
      stripe.ts        # last 24h of Stripe Events (evt_... = idempotency key)
      appstore.ts       # Customer Reviews (see scope note below)
      vercel.ts          # recent deployments, flags ERROR/CANCELED
      supabase-health.ts # DB round-trip latency probe
      system-health.ts   # staleness watchdog over the other 4 collectors
      index.ts            # runs all 5, fail-soft, aggregates CollectorResult[]
  api/collect/
    all.ts, stripe.ts, appstore.ts, vercel.ts, supabase.ts, system.ts
    (Vercel Edge functions, Bearer-auth via CRON_SECRET)
  vercel.json           # cron schedules
  .env.example
```

## Schema isolation & RLS — what it actually guarantees

`ganesh.*` has RLS enabled with **zero policies** for `anon`/`authenticated`,
plus explicit `REVOKE` statements — that's a hard default-deny for every
normal client request through PostgREST.

**What it does NOT do:** Supabase's `service_role` key bypasses RLS at the
database level by design (`BYPASSRLS`). A `service_role` key for a Supabase
project has full access to *every* schema in that project, `ganesh` or
otherwise — RLS can't scope a service-role key to one schema. If Ganesh must
be hard-isolated (not just isolated from public API traffic) from whatever
else lives in the same project, give it its own Supabase project instead of
relying on schema + RLS within a shared one. This is a fact about how
Supabase's service role works, not a gap in the migration.

**One manual step the SQL can't do:** if collectors reach `ganesh` through
the REST API (as they do here, via `supabase-js`), add `ganesh` to
**Project Settings → API → Exposed schemas** in the dashboard. Direct
Postgres connections don't need this.

## Idempotency

Every business-signal row is keyed on `(source, external_id)` with a unique
constraint; `ingestSignal`/`ingestSignals` upsert on that key. Stripe event
IDs, App Store review IDs, and Vercel deployment UIDs are all naturally
stable and unique, so a re-run updates in place rather than duplicating.
`created_at` is left untouched on conflict (first-observed, not
last-observed). Health-failure signals are the one intentional exception —
each failure gets its own timestamped row, since failures are discrete
events, not current-state records.

## Fail-soft

`runCollectorSafely()` wraps every collector: an external API error is
caught, logged as a `WARNING` signal (and a `ganesh.alerts` row if
`CRITICAL`), and returned as `{ ok: false, error }` — never an unhandled
rejection, never a 500 from one bad upstream API. `system-health` runs last
in `runAllCollectors()` (after, not concurrent with, the other four) so its
staleness check reflects what the same run just wrote.

## App Store Connect — scope note

Week 1 ships the **Customer Reviews** collector: synchronous JSON, real
working signal, low complexity. True **Sales/Financial Reports** (the actual
IAP revenue numbers) use Apple's async flow — request a report, poll until
ready, download a gzip'd TSV, parse it — which is meaningfully more scope
than a Week 1 foundation layer. Flagging this explicitly rather than
pretending revenue data is wired when it isn't: **Sales Reports is a Week 2
addition.**

## Setup

```bash
cd ganesh-engine
npm install
cp .env.example .env   # fill in real values; .env is gitignored
npm run typecheck
```

Apply the migration (against whichever project is confirmed correct):
```bash
psql "$DATABASE_URL" -f migrations/001_create_ganesh_schema.sql
```

Deploy to Vercel, set the same env vars (Project Settings → Environment
Variables) including `CRON_SECRET`, and the schedules in `vercel.json` take
over. **Note:** frequent (sub-daily) cron schedules require a Vercel Pro
plan — the Hobby plan allows one run per day per cron job. Adjust
`vercel.json` accordingly if still on Hobby.

## Manual test call

```bash
curl -H "Authorization: Bearer $CRON_SECRET" https://<your-deployment>/api/collect/all
```

## Week 2 (not in this layer)

- `reasoner_runs` / `action_log` tables exist now; the Claude synthesis pass
  that populates them ships next.
- App Store Sales/Financial Reports (see scope note above).
- Supabase Management API metrics (CPU, connections, replication lag) beyond
  the current latency probe.
