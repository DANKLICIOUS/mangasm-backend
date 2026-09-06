# Grok Build Prompt — SMS Core Engine (shared by all 3 verticals)

Paste this into the Grok build terminal first. It builds the reusable engine
that TextBack Local, SMSDispatch, and NoShowGuard all sit on top of — build
this once, then apply the three thin vertical-config prompts in this same
folder. Building one shared engine instead of three separate products is the
token-minimizing move: one codebase to review, test, and extend instead of
three near-duplicates.

---

## ROLE & CONTEXT

You are building the shared backend engine for three Mangasm Enterprises SMS
products (TextBack Local, SMSDispatch, NoShowGuard — see
`docs/launch-kits/*.md` for full specs). All three follow the identical
shape: **trigger event → outbound SMS → inbound keyword-parsed reply →
status update → dashboard**. Build the engine generic over that shape; the
three products differ only in trigger source, message templates, and the
keyword vocabulary — all of which are config, not code.

## HARD ARCHITECTURAL CONSTRAINT — token budget

**This is the primary constraint the entire design must optimize for: zero
or near-zero variable AI/LLM cost per message until a business has an active
paid subscription.**

- The core reply-parsing path is a **deterministic keyword/regex matcher**
  against a small, per-vertical vocabulary (e.g. `CONFIRM`, `C`, `YES`,
  `RESCHEDULE`, `R`, `STOP`). No LLM call happens on this path, ever, for any
  customer, paid or not. This is not a cost-saving shortcut — real SMS reply
  vocabularies for these use cases are genuinely small and closed-set, so a
  matcher is also just the correct tool.
- Free-trial and unpaid-pilot accounts get the **full deterministic feature
  set** (see below) — the goal is "most features" to actually be true during
  the exact period when you have no revenue to spend on inference. Do not
  gate core functionality behind payment; gate only the optional AI layer.
- Exactly one optional AI-enhanced path exists: **freeform-reply
  fallback**. If an inbound SMS doesn't match any keyword in the vocabulary
  (e.g. a customer types "can we do thursday instead" rather than "R"), the
  default behavior for ALL accounts is a template nudge back
  ("Reply C to confirm or R to reschedule — didn't catch that!"). Only for
  accounts with `subscription_status = 'active'` does a fallback path call a
  small/cheap model (see model choice below) to classify intent and draft a
  response for staff review. Never call an LLM automatically for a
  non-paying account, and never let an LLM auto-send without a human review
  step even for paying accounts in week 1 — see approval tiers below.
- When the paid AI fallback does fire, cap it hard: one call per unmatched
  message (no multi-turn chains, no re-tries with bigger models on failure),
  cache nothing since replies are one-off, and use the smallest/cheapest
  model that clears an accuracy bar you validate against 20 real transcripts
  before enabling it live. Log every AI call's token count to
  `engine.ai_usage` so cost per account is auditable and can be compared
  against that account's subscription revenue.
- No AI is used anywhere else in the engine: not for dashboard summaries,
  not for onboarding copy, not for template generation. Templates are
  authored once, by a human, per vertical, and stored as static config.

## FEATURE SET (all included in the free/trial tier — this is "most
features, least tokens")

1. Trigger ingestion (missed call, reminder-due, load-created — one handler
   per vertical, same event shape)
2. Templated outbound SMS send via Twilio
3. Inbound SMS webhook → deterministic keyword match → status transition
4. Shared team inbox (any staff login sees all threads for their business)
5. Status/funnel dashboard (per-thread state: sent, replied, confirmed,
   declined/rescheduled, stale)
6. Quick-reply template library (staff can send a canned reply in one click
   for anything outside the keyword flow — no AI needed, just a picklist)
7. Daily/weekly digest email to the business owner (counts only, no AI
   summarization — a templated number roll-up)
8. CSV export of thread history

None of the above requires an LLM call. This is deliberate: the entire
"most features" bar is cleared by good state-machine design and UI, not by
AI, because AI cost during the pre-revenue validation phase is exactly the
budget the business owner is trying to protect.

## SYSTEM SPECIFICATIONS & SCHEMA

Isolated Supabase schema `sms_engine` (same isolation pattern as
`ganesh-engine`'s `ganesh` schema — RLS default-deny, `service_role` only,
see `ganesh-engine/migrations/001_create_ganesh_schema.sql` for the pattern
to copy).

```sql
create schema if not exists sms_engine;

create table sms_engine.businesses (
  id uuid primary key default gen_random_uuid(),
  vertical text not null check (vertical in ('textback_local','smsdispatch','noshowguard')),
  name text not null,
  phone_number text not null,               -- provisioned Twilio number
  subscription_status text not null default 'trial'
    check (subscription_status in ('trial','active','past_due','canceled')),
  created_at timestamptz not null default now()
);

create table sms_engine.contacts (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references sms_engine.businesses(id),
  phone_number text not null,
  created_at timestamptz not null default now(),
  unique (business_id, phone_number)
);

create table sms_engine.threads (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references sms_engine.businesses(id),
  contact_id uuid not null references sms_engine.contacts(id),
  trigger_type text not null,               -- 'missed_call' | 'reminder_due' | 'load_created'
  trigger_ref text,                          -- external id of the triggering event, idempotency key
  status text not null default 'sent'
    check (status in ('sent','replied_matched','replied_unmatched','confirmed','declined','stale')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (business_id, trigger_type, trigger_ref)
);

create table sms_engine.messages (
  id uuid primary key default gen_random_uuid(),
  thread_id uuid not null references sms_engine.threads(id),
  direction text not null check (direction in ('outbound','inbound')),
  body text not null,
  matched_keyword text,                      -- null if inbound and unmatched
  created_at timestamptz not null default now()
);

create table sms_engine.ai_usage (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references sms_engine.businesses(id),
  thread_id uuid references sms_engine.threads(id),
  model text not null,
  input_tokens int not null,
  output_tokens int not null,
  created_at timestamptz not null default now()
);

alter table sms_engine.businesses enable row level security;
alter table sms_engine.contacts enable row level security;
alter table sms_engine.threads enable row level security;
alter table sms_engine.messages enable row level security;
alter table sms_engine.ai_usage enable row level security;
-- zero policies for anon/authenticated = default-deny; service_role only.
revoke all on all tables in schema sms_engine from anon, authenticated;
```

## REQUIRED CODE MODULES

```
sms-engine/
  src/
    config/
      verticals.ts        # per-vertical template strings + keyword vocab, pure data
    lib/
      supabase-client.ts   # schema-scoped, copy the ganesh-engine generic-typing pattern
      twilio-client.ts
      keyword-match.ts     # deterministic matcher, one function, no dependencies
      ai-fallback.ts       # ONLY called when subscription_status='active' AND no keyword match
    handlers/
      trigger.ts           # generic trigger ingestion, idempotent on (business_id, trigger_type, trigger_ref)
      inbound-sms.ts        # Twilio webhook handler
  api/
    trigger/[vertical].ts   # Vercel Edge function per vertical, thin wrapper over handlers/trigger.ts
    sms/inbound.ts           # Twilio webhook endpoint
  README.md                  # document the token-budget constraint prominently, same as ganesh-engine's README did for the project-ID mismatch
```

## MODEL CHOICE FOR THE PAID FALLBACK (when it fires)

Use the smallest Claude model available (Haiku-class) for the freeform-reply
classification/draft step — this is a short single-turn classification task,
not a task needing frontier-model reasoning. Do not default to a larger
model "to be safe"; validate the small model against the 20-transcript test
set specified above before enabling it, and only escalate model size if that
test set shows real failures, with the failure examples documented.

## APPROVAL TIERS

Tier 1 (automatic, always on): keyword-matched replies, status updates,
dashboard, digest emails.
Tier 2 (automatic, paid-only): AI fallback draft is generated and shown to
staff in the inbox as a suggested reply — staff still clicks send.
Tier 3 (explicit owner approval, out of scope for this build): auto-sending
an AI-drafted reply without human review; any outbound marketing/outreach
using this engine's contact data.

## What NOT to build in this pass

No auto-send of AI replies. No multi-channel (voice/email) expansion — SMS
only, per the factory-run finding that SMS beats voice on cost and ease for
all three verticals. No calendar/ELD/CRM integrations beyond what each
vertical's launch kit marks "required for MVP" — those are v2 upsells,
documented as such in the launch kits, and building them now would be
spending build effort exactly where the "least tokens/least cost until
subscriptions start" principle says not to.
