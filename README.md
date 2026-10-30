# Mangasm — Backend

The Supabase backend for **Mangasm**, an 18+ LGBTQ+ social / dating platform:
a Sniffies-style live map feed, member-hosted events with RSVPs, direct
messaging, and a behaviour-based reputation + safety system.

This repository is the **data + server layer**. The iOS app (SwiftUI) lives
separately. This layer is deliberately platform-agnostic so the same schema and
functions serve the iOS client today and any web client later.

> **Why this repo exists:** the database schema had been *designed* but never
> committed as a runnable migration, which is what caused the recurring
> `PGRST205 "Could not find table public.events"` error in the app. The
> migrations here are the real, version-controlled source of truth. Run them and
> that error goes away.

## Layout

```
supabase/
  migrations/
    0001_initial_schema.sql   # extensions, core tables, helper fns, map RPC, triggers
    0002_rls_policies.sql     # Row Level Security for the core tables
    0003_tokens.sql           # MGC wallets + ledger (balance synced by trigger)
    0004_video_rooms.sql      # 4-8 person rooms + participants (Daily.co)
    0005_matchmaking.sql      # Plus matchmaking: prefs, pgvector taste, results
    0006_purge_conversation.sql  # block/report DM purge RPC
    0007_billing.sql          # Mangasm+ billing tables + membership sync trigger
  functions/
    recalculate-score/        # reputation scoring
    file-report/              # report + spite-report shield
    generate-daily-matches/   # 5 daily matches per Plus member
    delete-account/           # GDPR / App Store account deletion
    stripe-checkout/          # member → Stripe-hosted Checkout session
    stripe-webhook/           # Stripe → billing_subscriptions (signature-verified)
    revenue-metrics/          # owner-only snapshot for /admin/revenue
    _shared/cors.ts
  tests/
    shim.sql                  # Supabase auth/uid/roles shim for testing
    ci_smoke.sql              # end-to-end assertions run in CI
  seed.sql                    # optional local dev seed
  config.toml                 # Supabase CLI config
.github/workflows/db-ci.yml   # applies all migrations + smoke test on every push
docs/
  ARCHITECTURE.md             # data model + how the iOS app connects
.env.example                  # template for local secrets (never commit real keys)
```

## Quick start

### Standalone WebGL character demo

`webgl-demo/` is an isolated, dependency-free **Astral Echoes / Masteroid**
character study, not a Mangasm client or a Ganesh dashboard. It uses an original
violet storm shader, drifting particles, and pointer-responsive parallax.
It does not connect to Supabase, load credentials, or deploy anything.

To preview locally (requires Node/npm and Python 3):

```bash
cd webgl-demo
npm start
```

Open http://127.0.0.1:8080. No install or build step is needed. The supplied
artwork is loaded from its GitHub attachment URL without a referrer; if the URL
is unavailable, a storm sigil is shown instead. That URL returned 404 during
implementation. To use a local copy, place the artwork in `webgl-demo/` and
change the image `src` in `webgl-demo/index.html`.

The demo starts still when reduced motion is requested, includes a keyboard-
accessible motion toggle, pauses in hidden tabs, caps render resolution, and
falls back to CSS when WebGL is unavailable. No audio or flashing lightning
is used. To check manually: toggle motion, resize to mobile, enable reduced
motion, and disable WebGL or block the image request to exercise the fallbacks.
The igloo.inc reference could not be reached during implementation; no code
or assets from that site are included.

### Option A — Supabase CLI (recommended)

```bash
# 1. Install the CLI: https://supabase.com/docs/guides/cli
# 2. Link to your project (or `supabase start` for a local stack)
supabase link --project-ref YOUR-PROJECT-REF

# 3. Apply the migrations
supabase db push

# 4. Deploy edge functions
supabase functions deploy recalculate-score
supabase functions deploy file-report
```

### Option B — SQL Editor (no CLI)

Open the Supabase dashboard → **SQL Editor** and run, in order:

1. `supabase/migrations/0001_initial_schema.sql`
2. `supabase/migrations/0002_rls_policies.sql`

Then, if the schema cache looks stale:

```sql
notify pgrst, 'reload schema';
```

## Core tables

| Table                | What it holds                                                |
| -------------------- | ----------------------------------------------------------- |
| `profiles`           | 1:1 with `auth.users` — handle, bio, tags, membership, location, presence |
| `privacy_zones`      | Home-location disguise (free for everyone, always)          |
| `events`             | Member-hosted events (type, content tag, geo, RSVP capacity)|
| `event_rsvps`        | Going / maybe / declined per member                         |
| `messages`           | Direct messages                                             |
| `blocks`             | Block list (bidirectional content hiding)                   |
| `reports`            | Reports + `timing_flag` spite-report shield                 |
| `vouches`            | Positive-only "thumbs up" (one per ordered pair)            |
| `reputation_scores`  | Cached 0–100 score + tier (written by edge function only)   |
| `referrals`          | 5-char referral codes                                       |
| `token_wallets` / `token_transactions` | MGC balance + append-only ledger (balance synced by trigger) |
| `video_rooms` / `video_room_participants` | 4–8 person live rooms + occupancy |
| `match_preferences` / `match_vectors` / `match_results` | Plus matchmaking (pgvector taste vectors) |

## The map feed query

```sql
select * from public.users_within_radius(
  lat := 34.0100, lng := -118.4900, radius_m := 8047  -- ~5 miles
);
```

Returns nearby, non-blocked, non-banned profiles ordered by distance, using a
PostGIS GiST index. Locations are stored already privacy-adjusted.

## Security model

- **RLS on every table.** Visibility, the event-hosting gate (Plus + verified +
  30 days), the 14-day vouch gate, and block-based hiding are all enforced in
  `0002_rls_policies.sql` — not just in the app.
- **Reputation scores are read-only to clients.** Only the service-role edge
  function writes them, so members can't inflate their own score.
- **Service-role key never ships to the client.** It belongs in edge functions
  and server environments only. See `.env.example`.

See [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) for the full data model and
how the iOS app wires up to this layer.

## Status / honesty note

All five migrations were executed against a throwaway **PostgreSQL 16 + PostGIS
3.4 + pgvector** instance (with a minimal `auth.users` / `auth.uid()` shim to
stand in for Supabase) and applied cleanly on a fresh database. The smoke test
(`supabase/tests/ci_smoke.sql`, also run in CI) confirmed: the new-user trigger
auto-creates `profiles` + `reputation_scores`; `users_within_radius` returns
neighbours by distance; the token ledger trigger reconciles balances and blocks
overdraws; `room_occupancy` tracks joins/leaves; pgvector cosine distance works;
constraints reject bad input; and re-applying every migration is idempotent.

What was **not** validated here: Supabase-specific runtime behaviour — real
`auth.uid()` under a logged-in JWT, the actual RLS allow/deny decisions per role,
Realtime, and the Deno edge functions. Apply against a staging Supabase project
and exercise those before promoting to production.

## Go-live status (2026-07-31)

Everything below is **deployed and live** against project `hcpzbxplnkyythzwkovy`:

- Project restored from pause; all migrations applied through **`0007_billing.sql`**
  (billing tables + membership-sync trigger; `0006` purge RPC included).
- Edge functions **ACTIVE**: `stripe-checkout` (JWT-verified),
  `stripe-webhook` + `revenue-metrics` (deployed `--no-verify-jwt`; auth is the
  Stripe signature / `x-admin-token` respectively), plus the pre-existing
  `delete-account`.
- Web: `mangasm.app/plus` has the anon key wired in and calls `stripe-checkout`
  directly; `mangasm.app/admin/revenue` reads `revenue-metrics`.
- iOS build 1.1.0 (20) submitted to App Review (expedited review requested).

### Remaining before the first real charge

1. **Function secrets** (dashboard → Edge Functions → Secrets, or
   `supabase secrets set …`):
   `STRIPE_SECRET_KEY` (sk_live_…), `STRIPE_WEBHOOK_SECRET`,
   `STRIPE_PRICE_MONTHLY`, `STRIPE_PRICE_QUARTERLY`,
   `STRIPE_PAYMENT_METHOD_CONFIGURATION` (live pmc, see `docs/REVENUE.md`),
   `ADMIN_DASHBOARD_TOKEN` (any long random string; same value goes in the
   /admin/revenue settings panel).
2. **Stripe webhook endpoint** →
   `https://hcpzbxplnkyythzwkovy.supabase.co/functions/v1/stripe-webhook`
   with `customer.subscription.created/updated/deleted` +
   `invoice.payment_failed`.
3. **Live product + prices** — recreate the two sandbox prices in live mode and
   put their ids in the secrets above.

Full runbook with the dunning/retry settings: [`docs/REVENUE.md`](docs/REVENUE.md).
