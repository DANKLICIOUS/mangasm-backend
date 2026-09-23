-- ============================================================================
-- Mangasm — Initial schema
-- LGBTQ+ social / dating platform: map feed, events, messaging, reputation.
--
-- Run against a Supabase project:
--   supabase db push                      (with the Supabase CLI), or
--   paste into the Supabase SQL Editor and Run.
--
-- This migration is idempotent where practical (IF NOT EXISTS / OR REPLACE)
-- so it can be re-applied during early development.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Extensions
-- ----------------------------------------------------------------------------
create extension if not exists "uuid-ossp";
create extension if not exists postgis;      -- geography type + radius queries

-- ----------------------------------------------------------------------------
-- Enums
-- ----------------------------------------------------------------------------
do $$ begin
  create type membership_tier as enum ('free', 'plus', 'plus_plus');
exception when duplicate_object then null; end $$;

do $$ begin
  create type presence_status as enum ('online', 'away', 'busy', 'invisible', 'offline');
exception when duplicate_object then null; end $$;

do $$ begin
  create type event_type as enum (
    'social', 'drag', 'open_mic', 'naked_yoga', 'leather',
    'cum_and_go', 'wellness', 'custom'
  );
exception when duplicate_object then null; end $$;

do $$ begin
  create type content_tag as enum ('sfw', 'adult', 'explicit');
exception when duplicate_object then null; end $$;

do $$ begin
  create type event_status as enum ('draft', 'live', 'cancelled', 'ended');
exception when duplicate_object then null; end $$;

do $$ begin
  create type rsvp_status as enum ('going', 'maybe', 'declined');
exception when duplicate_object then null; end $$;

do $$ begin
  create type report_status as enum ('open', 'reviewing', 'resolved', 'dismissed');
exception when duplicate_object then null; end $$;

do $$ begin
  create type disguise_type as enum ('hidden', 'drift', 'landmark');
exception when duplicate_object then null; end $$;

-- ----------------------------------------------------------------------------
-- profiles  (1:1 with auth.users)
-- ----------------------------------------------------------------------------
create table if not exists public.profiles (
  id              uuid primary key references auth.users (id) on delete cascade,
  handle          text unique not null,
  display_name    text,
  bio             text,
  date_of_birth   date,                       -- enforced >= 18 at signup (edge fn)
  tags            text[]      not null default '{}',
  avatar_url      text,
  membership      membership_tier not null default 'free',
  is_verified     boolean     not null default false,  -- AI selfie check passed
  is_banned       boolean     not null default false,
  status          presence_status not null default 'offline',
  away_message    text,
  location        geography(Point, 4326),      -- last known, privacy-adjusted
  last_active_at  timestamptz not null default now(),
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  constraint handle_format check (handle ~ '^[a-zA-Z0-9_]{3,20}$')
);

create index if not exists profiles_location_gix on public.profiles using gist (location);
create index if not exists profiles_status_idx    on public.profiles (status);
create index if not exists profiles_tags_gin       on public.profiles using gin (tags);

-- ----------------------------------------------------------------------------
-- privacy_zones  (home-location disguise — free for everyone, always)
-- ----------------------------------------------------------------------------
create table if not exists public.privacy_zones (
  user_id     uuid primary key references public.profiles (id) on delete cascade,
  center      geography(Point, 4326) not null,
  radius_m    integer not null default 500 check (radius_m between 100 and 2000),
  disguise    disguise_type not null default 'drift',
  enabled     boolean not null default true,
  updated_at  timestamptz not null default now()
);

-- ----------------------------------------------------------------------------
-- events
-- ----------------------------------------------------------------------------
create table if not exists public.events (
  id           uuid primary key default uuid_generate_v4(),
  host_id      uuid not null references public.profiles (id) on delete cascade,
  title        text not null,
  description  text,
  type         event_type   not null default 'social',
  content      content_tag  not null default 'sfw',
  status       event_status not null default 'live',
  starts_at    timestamptz  not null,
  ends_at      timestamptz,
  capacity     integer check (capacity is null or capacity > 0),
  location     geography(Point, 4326),
  -- street address is hidden until ~2h before start (enforced in API/edge fn)
  address      text,
  visibility   text not null default 'all' check (visibility in ('all','premium','connections')),
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  constraint ends_after_starts check (ends_at is null or ends_at >= starts_at)
);

create index if not exists events_location_gix on public.events using gist (location);
create index if not exists events_starts_idx     on public.events (starts_at);
create index if not exists events_host_idx        on public.events (host_id);

-- ----------------------------------------------------------------------------
-- event_rsvps
-- ----------------------------------------------------------------------------
create table if not exists public.event_rsvps (
  event_id    uuid not null references public.events (id) on delete cascade,
  user_id     uuid not null references public.profiles (id) on delete cascade,
  status      rsvp_status not null default 'going',
  created_at  timestamptz not null default now(),
  primary key (event_id, user_id)
);

create index if not exists rsvps_user_idx on public.event_rsvps (user_id);

-- ----------------------------------------------------------------------------
-- messages  (direct messages)
-- ----------------------------------------------------------------------------
create table if not exists public.messages (
  id            uuid primary key default uuid_generate_v4(),
  sender_id     uuid not null references public.profiles (id) on delete cascade,
  recipient_id  uuid not null references public.profiles (id) on delete cascade,
  body          text not null,
  created_at    timestamptz not null default now(),
  read_at       timestamptz,
  constraint no_self_message check (sender_id <> recipient_id)
);

create index if not exists messages_recipient_idx on public.messages (recipient_id, created_at desc);
create index if not exists messages_sender_idx     on public.messages (sender_id, created_at desc);

-- ----------------------------------------------------------------------------
-- blocks
-- ----------------------------------------------------------------------------
create table if not exists public.blocks (
  blocker_id  uuid not null references public.profiles (id) on delete cascade,
  blocked_id  uuid not null references public.profiles (id) on delete cascade,
  created_at  timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  constraint no_self_block check (blocker_id <> blocked_id)
);

-- ----------------------------------------------------------------------------
-- reports  (spite-report shield: timing_flag set when filed soon after a
--           block/decline; deprioritised before human review)
-- ----------------------------------------------------------------------------
create table if not exists public.reports (
  id            uuid primary key default uuid_generate_v4(),
  reporter_id   uuid not null references public.profiles (id) on delete cascade,
  reported_id   uuid not null references public.profiles (id) on delete cascade,
  reason        text not null,
  details       text,
  timing_flag   boolean not null default false,
  status        report_status not null default 'open',
  created_at    timestamptz not null default now(),
  constraint no_self_report check (reporter_id <> reported_id)
);

create index if not exists reports_reported_idx on public.reports (reported_id);
create index if not exists reports_status_idx     on public.reports (status);

-- ----------------------------------------------------------------------------
-- vouches  (positive-only "thumbs up"; one per ordered pair)
-- ----------------------------------------------------------------------------
create table if not exists public.vouches (
  voucher_id  uuid not null references public.profiles (id) on delete cascade,
  vouchee_id  uuid not null references public.profiles (id) on delete cascade,
  created_at  timestamptz not null default now(),
  primary key (voucher_id, vouchee_id),
  constraint no_self_vouch check (voucher_id <> vouchee_id)
);

create index if not exists vouches_vouchee_idx on public.vouches (vouchee_id);

-- ----------------------------------------------------------------------------
-- reputation_scores  (computed by an edge function; cached here)
-- ----------------------------------------------------------------------------
create table if not exists public.reputation_scores (
  user_id            uuid primary key references public.profiles (id) on delete cascade,
  score              integer not null default 0 check (score between 0 and 100),
  tier               text    not null default 'new',
  follow_through     numeric not null default 0,
  vouch_count        integer not null default 0,
  report_weight      numeric not null default 0,
  updated_at         timestamptz not null default now()
);

-- ----------------------------------------------------------------------------
-- referrals  (5-char code per account; tracks the referral economy)
-- ----------------------------------------------------------------------------
create table if not exists public.referrals (
  code         text primary key,
  owner_id     uuid not null references public.profiles (id) on delete cascade,
  referred_id  uuid references public.profiles (id) on delete set null,
  verified     boolean not null default false,
  created_at   timestamptz not null default now()
);

create index if not exists referrals_owner_idx on public.referrals (owner_id);

-- ============================================================================
-- Helper functions  (SECURITY DEFINER so RLS policies can call them cleanly)
-- ============================================================================

create or replace function public.account_age_days(uid uuid)
returns integer
language sql stable security definer set search_path = public as $$
  select coalesce(extract(day from (now() - created_at))::int, 0)
  from public.profiles where id = uid;
$$;

create or replace function public.is_premium(uid uuid)
returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.profiles
    where id = uid and membership in ('plus','plus_plus') and not is_banned
  );
$$;

create or replace function public.is_verified(uid uuid)
returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce((select is_verified from public.profiles where id = uid), false);
$$;

-- True when `target` has blocked `viewer` (either direction hides content).
create or replace function public.is_blocked_between(viewer uuid, target uuid)
returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.blocks
    where (blocker_id = viewer and blocked_id = target)
       or (blocker_id = target and blocked_id = viewer)
  );
$$;

-- ----------------------------------------------------------------------------
-- users_within_radius — the map feed query.
-- Returns nearby, non-blocked, non-banned profiles inside `radius_m`.
-- Location returned is already the privacy-adjusted point stored on the row.
-- ----------------------------------------------------------------------------
create or replace function public.users_within_radius(
  lat double precision,
  lng double precision,
  radius_m integer default 8047   -- ~5 miles
)
returns table (
  id           uuid,
  handle       text,
  display_name text,
  avatar_url   text,
  tags         text[],
  status       presence_status,
  membership   membership_tier,
  is_verified  boolean,
  distance_m   double precision
)
language sql stable security definer set search_path = public, extensions as $$
  select p.id, p.handle, p.display_name, p.avatar_url, p.tags,
         p.status, p.membership, p.is_verified,
         st_distance(p.location, st_makepoint(lng, lat)::geography) as distance_m
  from public.profiles p
  where p.location is not null
    and not p.is_banned
    and p.id <> auth.uid()
    and not public.is_blocked_between(auth.uid(), p.id)
    and st_dwithin(p.location, st_makepoint(lng, lat)::geography, radius_m)
  order by distance_m asc
  limit 200;
$$;

-- ----------------------------------------------------------------------------
-- updated_at trigger
-- ----------------------------------------------------------------------------
create or replace function public.touch_updated_at()
returns trigger language plpgsql as $$
begin new.updated_at = now(); return new; end $$;

drop trigger if exists profiles_touch on public.profiles;
create trigger profiles_touch before update on public.profiles
  for each row execute function public.touch_updated_at();

drop trigger if exists events_touch on public.events;
create trigger events_touch before update on public.events
  for each row execute function public.touch_updated_at();

-- ----------------------------------------------------------------------------
-- New auth user -> profile row.  Handle defaults to user_<short id>; the app
-- prompts the member to pick a real handle during onboarding.
-- ----------------------------------------------------------------------------
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, handle)
  values (new.id, 'user_' || left(replace(new.id::text, '-', ''), 12))
  on conflict (id) do nothing;
  insert into public.reputation_scores (user_id) values (new.id)
  on conflict (user_id) do nothing;
  return new;
end $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
  for each row execute function public.handle_new_user();
