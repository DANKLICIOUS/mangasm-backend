-- ============================================================================
-- Ganesh Revenue Intelligence Engine — schema
-- Isolated `ganesh` schema: collectors write raw signals here; a reasoner
-- (Week 2) synthesizes them into briefs; actuators (Week 2) log downstream
-- actions. NOTHING in this file touches the `public` schema.
--
-- Run against a Supabase project with the Supabase CLI or the SQL Editor.
-- Idempotent where practical (IF NOT EXISTS / OR REPLACE) for safe re-runs.
-- ============================================================================

create schema if not exists ganesh;

-- ----------------------------------------------------------------------------
-- signals — raw, idempotent telemetry from collectors.
-- One row per (source, external_id): a collector re-running against the same
-- external event upserts in place rather than duplicating (constraint 3).
-- ----------------------------------------------------------------------------
do $$ begin
  create type ganesh.severity as enum ('INFO', 'WARNING', 'CRITICAL');
exception when duplicate_object then null; end $$;

create table if not exists ganesh.signals (
  id           uuid primary key default gen_random_uuid(),
  source       text not null,
  external_id  text not null,
  event_type   text not null,
  severity     ganesh.severity not null default 'INFO',
  payload      jsonb not null default '{}',
  created_at   timestamptz not null default now(),
  constraint signals_source_external_id_key unique (source, external_id)
);

create index if not exists signals_source_idx     on ganesh.signals (source);
create index if not exists signals_severity_idx   on ganesh.signals (severity);
create index if not exists signals_created_at_idx on ganesh.signals (created_at desc);
create index if not exists signals_payload_gin    on ganesh.signals using gin (payload);

-- ----------------------------------------------------------------------------
-- reasoner_runs — logs each Claude synthesis pass over recent signals.
-- Week 2 consumer; schema ships now so collectors and reasoner deploy
-- independently.
-- ----------------------------------------------------------------------------
create table if not exists ganesh.reasoner_runs (
  id            uuid primary key default gen_random_uuid(),
  model         text not null,
  tokens_in     integer,
  tokens_out    integer,
  health_status text,
  raw_json      jsonb,
  brief_text    text,
  created_at    timestamptz not null default now()
);

create index if not exists reasoner_runs_created_at_idx on ganesh.reasoner_runs (created_at desc);

-- ----------------------------------------------------------------------------
-- action_log — tracks execution of downstream actuators triggered by a
-- reasoner run (Week 2).
-- ----------------------------------------------------------------------------
create table if not exists ganesh.action_log (
  id                uuid primary key default gen_random_uuid(),
  reasoner_run_id   uuid references ganesh.reasoner_runs (id) on delete set null,
  actuator_name     text not null,
  status            text not null,
  output_payload    jsonb,
  executed_at       timestamptz not null default now()
);

create index if not exists action_log_reasoner_run_idx on ganesh.action_log (reasoner_run_id);
create index if not exists action_log_executed_at_idx  on ganesh.action_log (executed_at desc);

-- ----------------------------------------------------------------------------
-- alerts — human-facing alert / acknowledgment queue.
-- ----------------------------------------------------------------------------
create table if not exists ganesh.alerts (
  id               uuid primary key default gen_random_uuid(),
  severity         text not null,
  message          text not null,
  acknowledged_at  timestamptz,
  created_at       timestamptz not null default now()
);

create index if not exists alerts_unacked_idx on ganesh.alerts (created_at desc)
  where acknowledged_at is null;

-- ============================================================================
-- Security: schema isolation + RLS (constraints 1-2)
--
-- Supabase's `service_role` key bypasses Row Level Security at the database
-- level by design (it authenticates as a role with BYPASSRLS). Enabling RLS
-- with zero policies below is what blocks `anon` and `authenticated` — i.e.
-- every normal client request through PostgREST — it is NOT a restriction on
-- service_role, which always has full database access regardless of RLS.
-- If hard isolation from the rest of this database (not just from public API
-- traffic) is required, provision `ganesh` in its own Supabase project
-- instead of relying on RLS alone within a shared project.
-- ============================================================================

alter table ganesh.signals       enable row level security;
alter table ganesh.reasoner_runs enable row level security;
alter table ganesh.action_log    enable row level security;
alter table ganesh.alerts        enable row level security;

-- No policies are created for anon/authenticated -> default-deny for both.
-- Defense in depth: also revoke privileges outright so a future accidental
-- policy still can't leak data without an explicit GRANT too.
revoke all on schema ganesh from anon, authenticated;
revoke all on all tables in schema ganesh from anon, authenticated;
alter default privileges in schema ganesh revoke all on tables from anon, authenticated;

grant usage on schema ganesh to service_role;
grant all on all tables in schema ganesh to service_role;
alter default privileges in schema ganesh grant all on tables to service_role;

-- ============================================================================
-- Manual dashboard step (cannot be done via SQL):
-- If collectors call this schema through the Supabase REST API (supabase-js
-- with the service_role key, as this project's collectors do), add `ganesh`
-- to Project Settings -> API -> Exposed schemas. Direct postgres connections
-- do not need this step.
-- ============================================================================
