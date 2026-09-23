-- ============================================================================
-- Mangasm — 0004 Video rooms
-- 4–8 person live rooms (backed by Daily.co). The room's join URL is created
-- server-side by the create-video-room edge function; clients only read room
-- metadata and manage their own participant row.
-- ============================================================================

do $$ begin
  create type room_type as enum ('social', 'play', 'wellness', 'explicit');
exception when duplicate_object then null; end $$;

create table if not exists public.video_rooms (
  id            uuid primary key default uuid_generate_v4(),
  host_id       uuid not null references public.profiles (id) on delete cascade,
  title         text not null,
  type          room_type   not null default 'social',
  content       content_tag not null default 'adult',
  capacity      integer not null default 8 check (capacity between 2 and 8),
  is_live       boolean not null default true,
  daily_room_url text,                          -- set by create-video-room edge fn
  created_at    timestamptz not null default now(),
  ended_at      timestamptz
);

create index if not exists video_rooms_live_idx on public.video_rooms (is_live, created_at desc);

create table if not exists public.video_room_participants (
  room_id    uuid not null references public.video_rooms (id) on delete cascade,
  user_id    uuid not null references public.profiles (id) on delete cascade,
  joined_at  timestamptz not null default now(),
  left_at    timestamptz,
  primary key (room_id, user_id)
);

create index if not exists vrp_user_idx on public.video_room_participants (user_id);

-- Current occupancy of a room (participants who have not left).
create or replace function public.room_occupancy(room uuid)
returns integer language sql stable security definer set search_path = public as $$
  select count(*)::int from public.video_room_participants
  where room_id = room and left_at is null;
$$;

revoke all on function public.room_occupancy(uuid) from public;
grant execute on function public.room_occupancy(uuid) to authenticated;


-- ------------------------------------------------------------------- RLS -----
alter table public.video_rooms             enable row level security;
alter table public.video_room_participants enable row level security;

-- Live rooms are visible to verified, non-banned members.
drop policy if exists rooms_select on public.video_rooms;
create policy rooms_select on public.video_rooms
  for select to authenticated
  using (public.is_verified(auth.uid()) and not public.is_blocked_between(auth.uid(), host_id));

-- Hosting a room requires Plus + verified.
drop policy if exists rooms_insert on public.video_rooms;
create policy rooms_insert on public.video_rooms
  for insert to authenticated
  with check (
    host_id = auth.uid()
    and public.is_premium(auth.uid())
    and public.is_verified(auth.uid())
  );

drop policy if exists rooms_update_own on public.video_rooms;
create policy rooms_update_own on public.video_rooms
  for update to authenticated
  using (host_id = auth.uid())
  with check (host_id = auth.uid());

-- Participants manage only their own row; everyone in a room can see who's in it.
drop policy if exists vrp_select on public.video_room_participants;
create policy vrp_select on public.video_room_participants
  for select to authenticated
  using (
    user_id = auth.uid()
    or exists (
      select 1 from public.video_room_participants me
      where me.room_id = video_room_participants.room_id and me.user_id = auth.uid()
    )
  );

drop policy if exists vrp_write_own on public.video_room_participants;
create policy vrp_write_own on public.video_room_participants
  for all to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());
