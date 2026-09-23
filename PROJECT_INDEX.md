# Project Index: mangasm-backend

Generated: 2026-07-19  
Path: `~/mangasm-backend` · remote: `gothamgodzilla/mangasm-backend`  
Role: **Supabase data + edge layer** (source of truth for DB)

## 📁 Project Structure

```
mangasm-backend/
├── supabase/
│   ├── migrations/
│   │   ├── 0001_initial_schema.sql
│   │   ├── 0002_rls_policies.sql
│   │   ├── 0003_tokens.sql
│   │   ├── 0004_video_rooms.sql
│   │   ├── 0005_matchmaking.sql
│   │   ├── 0006_purge_conversation.sql
│   │   ├── 0007_billing.sql
│   │   ├── 0008_ugc_safety.sql
│   │   └── 0009_profile_style.sql
│   ├── functions/
│   │   ├── recalculate-score/     # reputation
│   │   ├── file-report/           # report + spite-report shield
│   │   ├── generate-daily-matches/
│   │   ├── delete-account/        # GDPR / ASC account deletion
│   │   ├── stripe-checkout/       # Mangasm+ Checkout sessions
│   │   ├── stripe-webhook/        # Stripe subscription sync
│   │   ├── revenue-metrics/       # /admin/revenue dashboard snapshot
│   │   └── _shared/cors.ts
│   ├── tests/
│   │   ├── shim.sql
│   │   └── ci_smoke.sql
│   ├── seed.sql
│   └── config.toml
├── ganesh-engine/                 # Autonomous revenue intelligence engine
├── ecosystem-builder/             # B2B turnkey startup & demo pipeline
├── docs/
│   ├── ARCHITECTURE.md
│   ├── REVENUE.md
│   ├── PROFILE_STYLE.md
│   ├── APP_STORE_RESOLUTION.md
│   └── EMPIRE.md
├── MANGASM_MAP.md                 # accounts / repos / wiring map
├── SHIP_GAPS.md                   # Human launch checklist (secrets, prod migrations, deploy)
├── README.md
└── .github/workflows/db-ci.yml    # migrate + smoke on push
```

**Scale:** small (~20 tracked files) — index is nearly complete map.

## 🚀 Entry Points

| Entry | Path | Purpose |
|-------|------|---------|
| Schema | `supabase/migrations/0001_*` | Core tables, helpers, map RPC, triggers |
| RLS | `0002_rls_policies.sql` | Row-level security |
| Tokens | `0003_tokens.sql` | MGC wallet + ledger |
| Video | `0004_video_rooms.sql` | Rooms (Daily.co) |
| Matchmaking | `0005_matchmaking.sql` | Plus prefs + pgvector |
| Purge | `0006_purge_conversation.sql` | DM history purge RPC (block/report UX) |
| Billing | `0007_billing.sql` | Subscriptions + membership sync trigger |
| Safety | `0008_ugc_safety.sql` | EULA terms, content flags, moderation actions |
| ProfileStyle | `0009_profile_style.sql` | Reputation-gated ProfileStyle themes |
| Edge | `supabase/functions/*/index.ts` | Deno edge functions |
| Ganesh Engine | `ganesh-engine/` | Cross-portfolio revenue telemetry & health |
| CI | `.github/workflows/db-ci.yml` | Apply migrations + `ci_smoke.sql` |

**Quick start**

```bash
supabase link --project-ref <ref>
supabase db push
supabase functions deploy delete-account
supabase functions deploy file-report
# CI: push → db-ci.yml
```

## 📦 Core surface

### Entities (from ARCHITECTURE)
- `profiles` (+ privacy-adjusted PostGIS `location`, `selected_style_id`)
- `privacy_zones`, `events`, `event_rsvps`
- `messages` (+ Realtime)
- `blocks`, `reports` (+ `content_type`/`content_id`), `vouches`, `reputation_scores`
- `terms_acceptances`, `moderation_actions`
- `billing_customers`, `billing_subscriptions`
- `token_wallets`, `token_transactions`
- `video_rooms`, `video_room_participants`
- `match_preferences`, `match_vectors`, `match_results`

### Edge functions
| Function | Role |
|----------|------|
| `recalculate-score` | Vouches/reports/blocks → 0–100 + tier |
| `file-report` | Report + timing_flag spite shield + content-level flagging |
| `generate-daily-matches` | Plus daily matches |
| `delete-account` | Full account deletion (App Store) |
| `stripe-checkout` | Member → Stripe Checkout session |
| `stripe-webhook` | Stripe → billing_subscriptions sync |
| `revenue-metrics` | Owner dashboard metrics snapshot |

### Client contract
- iOS uses **anon key only** (`SUPABASE_URL` + publishable key in Info.plist / xcconfig)
- **Service role never in app** — edge only
- iOS repo: `~/dev/mangasm/Mangasm` — still **MockChatService** for DMs

## 🔧 Configuration

| File | Purpose |
|------|---------|
| `supabase/config.toml` | CLI / local stack |
| `db-ci.yml` | Migration + smoke CI |
| `.env.example` | Local secrets template (if present; never commit real keys) |

## 🧪 Tests

| File | Purpose |
|------|---------|
| `supabase/tests/ci_smoke.sql` | E2E assertions in CI |
| `supabase/tests/shim.sql` | auth.uid / roles for tests |

## 📚 Documentation

| Doc | Topic |
|-----|--------|
| `README.md` | Layout + deploy |
| `docs/ARCHITECTURE.md` | System shape, RLS gates, iOS wiring |
| `MANGASM_MAP.md` | Apple vs GitHub identities, repos, key placement |

## ⚠️ High-risk notes

1. **Canonical migrations live here** — iOS repo also has `supabase/migrations/*` with different names; reconcile before dual `db push`  
2. **delete-account** must match App Store “delete account” UX  
3. **file-report** timing_flag — safety product claim  
4. Chat/messages schema exists; **iOS live ChatService not wired**  
5. Identities: App Store Apple ID ≠ GitHub `gothamgodzilla` (see `MANGASM_MAP.md`)

## 🔗 Related

| Asset | Path |
|-------|------|
| iOS | `~/dev/mangasm/Mangasm` |
| Goals | `~/dev/mangasm/GOALS.md` |
| Supabase project URL (public) | in iOS `SupabaseConfig.defaultURL` / ASC secrets |

## 📝 Suggested next commands

```text
@backend-architect + /sc:analyze  → migrations vs iOS copy
/sc:implement delete-account E2E   → with iOS AccountDeletion tests
/sc:test                           → db-ci smoke locally if CLI linked
```
