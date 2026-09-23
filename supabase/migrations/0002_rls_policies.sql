-- ============================================================================
-- Mangasm — Row Level Security
-- Enforces the rules designed for the platform at the database layer, so they
-- hold even if a client hits the REST/Realtime API directly.
-- ============================================================================

alter table public.profiles          enable row level security;
alter table public.privacy_zones     enable row level security;
alter table public.events            enable row level security;
alter table public.event_rsvps       enable row level security;
alter table public.messages          enable row level security;
alter table public.blocks            enable row level security;
alter table public.reports           enable row level security;
alter table public.vouches           enable row level security;
alter table public.reputation_scores enable row level security;
alter table public.referrals         enable row level security;

-- ---------------------------------------------------------------- profiles ---
drop policy if exists profiles_select on public.profiles;
create policy profiles_select on public.profiles
  for select to authenticated
  using (not is_banned and not public.is_blocked_between(auth.uid(), id));

drop policy if exists profiles_update_own on public.profiles;
create policy profiles_update_own on public.profiles
  for update to authenticated
  using (id = auth.uid())
  with check (id = auth.uid());

-- ------------------------------------------------------------ privacy_zones --
drop policy if exists pz_all_own on public.privacy_zones;
create policy pz_all_own on public.privacy_zones
  for all to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- ------------------------------------------------------------------ events ---
drop policy if exists events_select on public.events;
create policy events_select on public.events
  for select to authenticated
  using (
    status <> 'draft'
    and not public.is_blocked_between(auth.uid(), host_id)
    and (
      visibility = 'all'
      or host_id = auth.uid()
      or (visibility = 'premium' and public.is_premium(auth.uid()))
    )
  );

-- Hosting gate: Plus member, verified, and account >= 30 days old.
drop policy if exists events_insert on public.events;
create policy events_insert on public.events
  for insert to authenticated
  with check (
    host_id = auth.uid()
    and public.is_premium(auth.uid())
    and public.is_verified(auth.uid())
    and public.account_age_days(auth.uid()) >= 30
  );

drop policy if exists events_update_own on public.events;
create policy events_update_own on public.events
  for update to authenticated
  using (host_id = auth.uid())
  with check (host_id = auth.uid());

drop policy if exists events_delete_own on public.events;
create policy events_delete_own on public.events
  for delete to authenticated
  using (host_id = auth.uid());

-- ------------------------------------------------------------- event_rsvps ---
drop policy if exists rsvps_select on public.event_rsvps;
create policy rsvps_select on public.event_rsvps
  for select to authenticated
  using (
    user_id = auth.uid()
    or exists (select 1 from public.events e where e.id = event_id and e.host_id = auth.uid())
  );

drop policy if exists rsvps_write_own on public.event_rsvps;
create policy rsvps_write_own on public.event_rsvps
  for all to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- ---------------------------------------------------------------- messages ---
drop policy if exists messages_select on public.messages;
create policy messages_select on public.messages
  for select to authenticated
  using (sender_id = auth.uid() or recipient_id = auth.uid());

drop policy if exists messages_insert on public.messages;
create policy messages_insert on public.messages
  for insert to authenticated
  with check (
    sender_id = auth.uid()
    and not public.is_blocked_between(auth.uid(), recipient_id)
  );

-- Recipient may mark read (update read_at); sender may delete their message.
drop policy if exists messages_update_recipient on public.messages;
create policy messages_update_recipient on public.messages
  for update to authenticated
  using (recipient_id = auth.uid())
  with check (recipient_id = auth.uid());

drop policy if exists messages_delete_sender on public.messages;
create policy messages_delete_sender on public.messages
  for delete to authenticated
  using (sender_id = auth.uid());

-- ------------------------------------------------------------------ blocks ---
drop policy if exists blocks_all_own on public.blocks;
create policy blocks_all_own on public.blocks
  for all to authenticated
  using (blocker_id = auth.uid())
  with check (blocker_id = auth.uid());

-- ----------------------------------------------------------------- reports ---
-- A member can file reports and see the ones they filed; moderation tooling
-- uses the service role (which bypasses RLS) to review every report.
drop policy if exists reports_insert on public.reports;
create policy reports_insert on public.reports
  for insert to authenticated
  with check (reporter_id = auth.uid());

drop policy if exists reports_select_own on public.reports;
create policy reports_select_own on public.reports
  for select to authenticated
  using (reporter_id = auth.uid());

-- ----------------------------------------------------------------- vouches ---
-- Vouching opens after 14 days on the platform (anti-brigading).
drop policy if exists vouches_insert on public.vouches;
create policy vouches_insert on public.vouches
  for insert to authenticated
  with check (
    voucher_id = auth.uid()
    and public.account_age_days(auth.uid()) >= 14
    and not public.is_blocked_between(auth.uid(), vouchee_id)
  );

drop policy if exists vouches_select on public.vouches;
create policy vouches_select on public.vouches
  for select to authenticated
  using (true);

drop policy if exists vouches_delete_own on public.vouches;
create policy vouches_delete_own on public.vouches
  for delete to authenticated
  using (voucher_id = auth.uid());

-- ------------------------------------------------------- reputation_scores ---
-- Scores are world-readable (shown on profiles) but only the service role
-- (edge function) writes them — no client INSERT/UPDATE policy is granted.
drop policy if exists reputation_select on public.reputation_scores;
create policy reputation_select on public.reputation_scores
  for select to authenticated
  using (true);

-- --------------------------------------------------------------- referrals ---
drop policy if exists referrals_select_own on public.referrals;
create policy referrals_select_own on public.referrals
  for select to authenticated
  using (owner_id = auth.uid());

drop policy if exists referrals_insert_own on public.referrals;
create policy referrals_insert_own on public.referrals
  for insert to authenticated
  with check (owner_id = auth.uid());

