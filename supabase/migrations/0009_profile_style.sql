-- ============================================================================
-- Mangasm — 0009 Reputation-gated ProfileStyle themes
--
-- Cosmetic profile chrome only. Never gates messaging, adult visibility, or
-- sexual features (App Store Guideline 1.2 / 4.3 framing).
--
-- Members pick a ProfileStyleId; the server unlocks the catalog from the
-- cached `reputation_scores.tier` written by `recalculate-score`. Clients
-- cannot cheat: an UPDATE of `profiles.selected_style_id` to a locked style
-- is rejected by BOTH a BEFORE UPDATE trigger (fires for every role,
-- including CI superuser) and the profiles UPDATE RLS WITH CHECK (live
-- PostgREST / authenticated JWT).
--
-- Style IDs match iOS `ProfileStyleId` raw values in DANKLICIOUS/Mangasm:
--   calmStudio, aspirational, precisionTech, digitalFlow, boldExpression
--
-- Unlock map (tier is the gate; score bands are what `recalculate-score`
-- writes into `reputation_scores.tier`):
--   new      (score <  40) → calmStudio
--   building (score >= 40) → + aspirational
--   reliable (score >= 65) → + precisionTech, digitalFlow
--   verified (score >= 85) → + boldExpression  (all five)
--
-- Idempotent where practical (IF NOT EXISTS / OR REPLACE / DROP IF EXISTS).
-- Additive: does not rewrite or drop reputation_scores data.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Enum — closed set matching iOS ProfileStyleId. Raw values are camelCase
-- on purpose so PostgREST returns the same strings the Swift client uses.
-- ----------------------------------------------------------------------------
do $$ begin
  create type public.profile_style_id as enum (
    'calmStudio',
    'aspirational',
    'precisionTech',
    'digitalFlow',
    'boldExpression'
  );
exception when duplicate_object then null; end $$;

comment on type public.profile_style_id is
  'Cosmetic ProfileStyle catalog; raw values match iOS ProfileStyleId.';

-- ----------------------------------------------------------------------------
-- profiles.selected_style_id — default is the always-unlocked new-member look.
-- ----------------------------------------------------------------------------
alter table public.profiles
  add column if not exists selected_style_id public.profile_style_id
    not null default 'calmStudio';

comment on column public.profiles.selected_style_id is
  'Member-chosen cosmetic theme. Server rejects values not unlocked by the current reputation_scores.tier.';

-- ----------------------------------------------------------------------------
-- unlocked_profile_styles(tier) — single source of truth for the unlock map.
-- Unknown / null tiers fail closed to the new-member catalog.
-- ----------------------------------------------------------------------------
create or replace function public.unlocked_profile_styles(p_tier text)
returns text[]
language sql
immutable
parallel safe
as $$
  select case p_tier
    when 'verified' then array[
      'calmStudio', 'aspirational', 'precisionTech', 'digitalFlow', 'boldExpression'
    ]
    when 'reliable' then array[
      'calmStudio', 'aspirational', 'precisionTech', 'digitalFlow'
    ]
    when 'building' then array[
      'calmStudio', 'aspirational'
    ]
    else array['calmStudio']
  end;
$$;

comment on function public.unlocked_profile_styles(text) is
  'Style IDs unlocked for a reputation_scores.tier value. Fail-closed to calmStudio.';

-- ----------------------------------------------------------------------------
-- Current cached tier for a member (missing row → 'new').
-- ----------------------------------------------------------------------------
create or replace function public.reputation_tier_for(p_user_id uuid)
returns text
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    (select rs.tier from public.reputation_scores rs where rs.user_id = p_user_id),
    'new'
  );
$$;

-- ----------------------------------------------------------------------------
-- profile_style_is_unlocked — used by the trigger, RLS, and tests.
-- ----------------------------------------------------------------------------
create or replace function public.profile_style_is_unlocked(
  p_user_id uuid,
  p_style_id text
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select p_style_id = any (
    public.unlocked_profile_styles(public.reputation_tier_for(p_user_id))
  );
$$;

comment on function public.profile_style_is_unlocked(uuid, text) is
  'True when p_style_id is in the catalog unlocked by the user''s current reputation tier.';

-- WITH CHECK cannot see OLD vs NEW. Allow a previously selected (now locked)
-- style to remain so a later score drop does not freeze unrelated profile
-- edits; the trigger still rejects *changes* to a locked style.
create or replace function public.profile_style_update_allowed(
  p_user_id uuid,
  p_new_style public.profile_style_id
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select
    public.profile_style_is_unlocked(p_user_id, p_new_style::text)
    or exists (
      select 1
      from public.profiles p
      where p.id = p_user_id
        and p.selected_style_id = p_new_style
    );
$$;

-- ----------------------------------------------------------------------------
-- Trigger — rejects a *change* of selected_style_id to a locked style.
-- Fires even for table-owners / CI (RLS does not). Matches the token-ledger
-- pattern of raising check_violation so smoke tests can catch it.
-- ----------------------------------------------------------------------------
create or replace function public.enforce_selected_style_unlock()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.selected_style_id is not distinct from old.selected_style_id then
    return new;
  end if;
  if not public.profile_style_is_unlocked(new.id, new.selected_style_id::text) then
    raise exception
      'profile style % is not unlocked for the current reputation tier',
      new.selected_style_id
      using errcode = 'check_violation';
  end if;
  return new;
end;
$$;

drop trigger if exists profiles_style_unlock on public.profiles;
create trigger profiles_style_unlock
  before update of selected_style_id on public.profiles
  for each row execute function public.enforce_selected_style_unlock();

-- ----------------------------------------------------------------------------
-- RLS: keep own-row updates, but WITH CHECK re-validates the chosen style.
-- ----------------------------------------------------------------------------
drop policy if exists profiles_update_own on public.profiles;
create policy profiles_update_own on public.profiles
  for update to authenticated
  using (id = auth.uid())
  with check (
    id = auth.uid()
    and public.profile_style_update_allowed(auth.uid(), selected_style_id)
  );

-- ----------------------------------------------------------------------------
-- my_profile_style — one round-trip for the iOS picker:
--   score, tier, unlocked_style_ids[], selected_style_id
-- ----------------------------------------------------------------------------
create or replace function public.my_profile_style()
returns table (
  score              integer,
  tier               text,
  unlocked_style_ids text[],
  selected_style_id  text
)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  me uuid := auth.uid();
  t  text;
begin
  if me is null then
    raise exception 'not authenticated';
  end if;

  t := public.reputation_tier_for(me);

  return query
  select
    coalesce(r.score, 0),
    t,
    public.unlocked_profile_styles(t),
    p.selected_style_id::text
  from public.profiles p
  left join public.reputation_scores r on r.user_id = p.id
  where p.id = me;
end;
$$;

comment on function public.my_profile_style() is
  'Authenticated caller: current reputation score/tier, unlocked ProfileStyleIds, and selected_style_id.';

revoke all on function public.unlocked_profile_styles(text) from public;
revoke all on function public.reputation_tier_for(uuid) from public;
revoke all on function public.profile_style_is_unlocked(uuid, text) from public;
revoke all on function public.profile_style_update_allowed(uuid, public.profile_style_id) from public;
revoke all on function public.my_profile_style() from public;

grant execute on function public.unlocked_profile_styles(text) to authenticated;
grant execute on function public.reputation_tier_for(uuid) to authenticated;
grant execute on function public.profile_style_is_unlocked(uuid, text) to authenticated;
grant execute on function public.profile_style_update_allowed(uuid, public.profile_style_id) to authenticated;
grant execute on function public.my_profile_style() to authenticated;

grant usage on type public.profile_style_id to authenticated, anon;
