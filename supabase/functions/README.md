# Edge Functions

Deno-based Supabase Edge Functions. Each folder is one deployable function.

| Function                 | Purpose                                                        | Trigger              |
| ------------------------ | -------------------------------------------------------------- | -------------------- |
| `recalculate-score`      | Recompute reputation from vouches/reports/blocks/events hosted | cron + on-demand (no DB triggers on vouch/report/block/event) |
| `file-report`            | File a report and apply the 2-hour spite-report `timing_flag`  | client (authed)      |
| `generate-daily-matches` | Up to 5 scored daily matches per Plus member                   | cron + on-demand     |
| `delete-account`         | GDPR / App Store account deletion (cascade purge)              | client (authed)      |
| `stripe-checkout`        | Create a Mangasm+ Checkout Session (see `docs/REVENUE.md`)     | client (authed)      |
| `stripe-webhook`         | Stripe subscription lifecycle → `billing_subscriptions`        | Stripe (signed)      |
| `revenue-metrics`        | MRR / failed-payments snapshot for `/admin/revenue`            | dashboard (token)    |

## Stubs to add as the product grows

These were part of the design and slot in here as new folders:

- `verify-selfie` — AI selfie/liveness check on signup; flips `profiles.is_verified`.
- `detect-spam-pattern` — DB webhook on message insert; flags blast/solicitation patterns.
- `send-accountability-email` — warm, specific accountability notices.
- `process-token-payout` — Stripe Connect / crypto payout from MGC balance.

## Local development

```bash
# start the local stack (Postgres + Auth + Studio + Edge Runtime)
supabase start

# serve a single function with hot reload
supabase functions serve recalculate-score --env-file ./supabase/.env.local
```

## Deploy

```bash
supabase functions deploy recalculate-score
supabase functions deploy file-report
```

## Secrets

Functions read these from the environment (never commit real values):

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `SUPABASE_SERVICE_ROLE_KEY` — **server-side only**, full DB access. Never ship to the iOS client.

Set them with `supabase secrets set --env-file ./supabase/.env.local`.
