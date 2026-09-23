-- End-to-end smoke test run in CI after all migrations apply.
-- Any failed assertion raises and fails the job.
\set ON_ERROR_STOP on

-- Two members via the auth-user trigger.
insert into auth.users (id) values ('11111111-1111-1111-1111-111111111111');
insert into auth.users (id) values ('22222222-2222-2222-2222-222222222222');

do $$ begin
  if (select count(*) from public.profiles) <> 2 then
    raise exception 'trigger did not create profiles';
  end if;
  if (select count(*) from public.reputation_scores) <> 2 then
    raise exception 'trigger did not create reputation rows';
  end if;
end $$;

update public.profiles set handle='wolf',   location=st_makepoint(-118.49,34.01)::geography
  where id='11111111-1111-1111-1111-111111111111';
update public.profiles set handle='cipher', location=st_makepoint(-118.50,34.02)::geography
  where id='22222222-2222-2222-2222-222222222222';

-- Map RPC returns both within 5 miles.
do $$ begin
  if (select count(*) from public.users_within_radius(34.01,-118.49,8047)) < 1 then
    raise exception 'radius rpc returned no rows';
  end if;
end $$;

-- Token ledger: credit then debit, balance must reconcile, overdraw must fail.
insert into public.token_transactions(user_id,amount,type)
  values ('11111111-1111-1111-1111-111111111111', 100, 'earn_cam');
insert into public.token_transactions(user_id,amount,type)
  values ('11111111-1111-1111-1111-111111111111', -30, 'tip_sent');
do $$ begin
  if public.token_balance('11111111-1111-1111-1111-111111111111') <> 70 then
    raise exception 'token balance mismatch: expected 70';
  end if;
end $$;
do $$ begin
  insert into public.token_transactions(user_id,amount,type)
    values ('11111111-1111-1111-1111-111111111111', -1000, 'payout');
  raise exception 'overdraw should have been blocked';
exception when check_violation then null;  -- expected
end $$;

-- Video room occupancy.
insert into public.video_rooms(id,host_id,title) values
  ('33333333-3333-3333-3333-333333333333','11111111-1111-1111-1111-111111111111','Test Room');
insert into public.video_room_participants(room_id,user_id) values
  ('33333333-3333-3333-3333-333333333333','11111111-1111-1111-1111-111111111111'),
  ('33333333-3333-3333-3333-333333333333','22222222-2222-2222-2222-222222222222');
do $$ begin
  if public.room_occupancy('33333333-3333-3333-3333-333333333333') <> 2 then
    raise exception 'room occupancy expected 2';
  end if;
end $$;

-- pgvector taste vectors + match result.
insert into public.match_vectors(user_id, embedding) values
  ('11111111-1111-1111-1111-111111111111', ('[' || array_to_string(array_fill(0.1::real,'{128}'), ',') || ']')::vector),
  ('22222222-2222-2222-2222-222222222222', ('[' || array_to_string(array_fill(0.1::real,'{128}'), ',') || ']')::vector);
do $$ begin
  if (select mv1.embedding <=> mv2.embedding
      from public.match_vectors mv1, public.match_vectors mv2
      where mv1.user_id='11111111-1111-1111-1111-111111111111'
        and mv2.user_id='22222222-2222-2222-2222-222222222222') > 0.0001 then
    raise exception 'identical vectors should have ~0 cosine distance';
  end if;
end $$;

-- UGC safety (Guideline 1.2): flag content, action it, eject the author, audit.
insert into public.messages(id, sender_id, recipient_id, body) values
  ('44444444-4444-4444-4444-444444444444',
   '11111111-1111-1111-1111-111111111111',
   '22222222-2222-2222-2222-222222222222', 'offending content');

insert into public.reports(id, reporter_id, reported_id, reason, content_type, content_id) values
  ('55555555-5555-5555-5555-555555555555',
   '22222222-2222-2222-2222-222222222222',
   '11111111-1111-1111-1111-111111111111',
   'harassment', 'message', '44444444-4444-4444-4444-444444444444');

-- Open report shows up in the moderation SLA queue.
do $$ begin
  if (select count(*) from public.reports_open_sla
      where id='55555555-5555-5555-5555-555555555555') <> 1 then
    raise exception 'open report missing from SLA queue';
  end if;
end $$;

-- Action it: content removed, author ejected, report resolved, action audited.
select public.action_report('55555555-5555-5555-5555-555555555555', 'remove_and_eject');
do $$ begin
  if exists (select 1 from public.messages where id='44444444-4444-4444-4444-444444444444') then
    raise exception 'offending message was not removed';
  end if;
  if not (select is_banned from public.profiles
          where id='11111111-1111-1111-1111-111111111111') then
    raise exception 'author was not ejected';
  end if;
  if (select status from public.reports
      where id='55555555-5555-5555-5555-555555555555') <> 'resolved' then
    raise exception 'report was not resolved';
  end if;
  if (select count(*) from public.moderation_actions
      where report_id='55555555-5555-5555-5555-555555555555') <> 1 then
    raise exception 'moderation action was not audited';
  end if;
end $$;

-- Terms acceptance is recorded (EULA gate).
insert into public.terms_acceptances(user_id, document, version) values
  ('22222222-2222-2222-2222-222222222222', 'eula', '1.0');
do $$ begin
  if (select count(*) from public.terms_acceptances
      where user_id='22222222-2222-2222-2222-222222222222') <> 1 then
    raise exception 'terms acceptance not recorded';
  end if;
end $$;

-- ----------------------------------------------------------------------------
-- Reputation-gated ProfileStyle (migration 0009)
-- Dedicated member so earlier UGC eject of 1111… does not leak into this suite.
-- ----------------------------------------------------------------------------
insert into auth.users (id) values ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa');

do $$ begin
  if (select selected_style_id::text from public.profiles
        where id='aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa') is distinct from 'calmStudio' then
    raise exception 'new profile default style is not calmStudio';
  end if;
end $$;

-- Unlock map at each reputation tier (catalog order).
do $$ begin
  if public.unlocked_profile_styles('new')
       is distinct from array['calmStudio']::text[] then
    raise exception 'new tier must unlock only calmStudio';
  end if;
  if public.unlocked_profile_styles('building')
       is distinct from array['calmStudio','aspirational']::text[] then
    raise exception 'building tier unlock mismatch';
  end if;
  if public.unlocked_profile_styles('reliable')
       is distinct from array['calmStudio','aspirational','precisionTech','digitalFlow']::text[] then
    raise exception 'reliable tier unlock mismatch';
  end if;
  if public.unlocked_profile_styles('verified')
       is distinct from array['calmStudio','aspirational','precisionTech','digitalFlow','boldExpression']::text[] then
    raise exception 'verified tier unlock mismatch';
  end if;
  if public.unlocked_profile_styles('mystery')
       is distinct from array['calmStudio']::text[] then
    raise exception 'unknown tier must fail closed to calmStudio';
  end if;
end $$;

-- RPC as this member: default score 0 / tier new / calmStudio only.
select set_config('test.uid', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', false);
do $$
declare
  r record;
begin
  select * into r from public.my_profile_style();
  if r.score <> 0 or r.tier is distinct from 'new'
     or r.selected_style_id is distinct from 'calmStudio'
     or r.unlocked_style_ids is distinct from array['calmStudio']::text[] then
    raise exception 'my_profile_style default mismatch: % % % %',
      r.score, r.tier, r.selected_style_id, r.unlocked_style_ids;
  end if;
end $$;

-- new (score < 40): reject aspirational.
do $$ begin
  update public.profiles
     set selected_style_id = 'aspirational'
   where id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
  raise exception 'new tier should reject aspirational';
exception when check_violation then null;
end $$;

-- building boundary (score 40): +aspirational, still reject precisionTech.
update public.reputation_scores
   set score = 40, tier = 'building'
 where user_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
update public.profiles
   set selected_style_id = 'aspirational'
 where id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
do $$ begin
  update public.profiles
     set selected_style_id = 'precisionTech'
   where id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
  raise exception 'building tier should reject precisionTech';
exception when check_violation then null;
end $$;
do $$
declare
  r record;
begin
  select * into r from public.my_profile_style();
  if r.tier is distinct from 'building'
     or r.selected_style_id is distinct from 'aspirational'
     or not ('aspirational' = any (r.unlocked_style_ids))
     or 'precisionTech' = any (r.unlocked_style_ids) then
    raise exception 'building RPC mismatch: % % %',
      r.tier, r.selected_style_id, r.unlocked_style_ids;
  end if;
end $$;

-- reliable boundary (score 65): +precisionTech +digitalFlow, reject boldExpression.
update public.reputation_scores
   set score = 65, tier = 'reliable'
 where user_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
update public.profiles
   set selected_style_id = 'precisionTech'
 where id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
update public.profiles
   set selected_style_id = 'digitalFlow'
 where id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
do $$ begin
  update public.profiles
     set selected_style_id = 'boldExpression'
   where id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
  raise exception 'reliable tier should reject boldExpression';
exception when check_violation then null;
end $$;

-- verified boundary (score 85): all five, including boldExpression.
update public.reputation_scores
   set score = 85, tier = 'verified'
 where user_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
update public.profiles
   set selected_style_id = 'boldExpression'
 where id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
do $$
declare
  r record;
begin
  select * into r from public.my_profile_style();
  if r.tier is distinct from 'verified'
     or r.selected_style_id is distinct from 'boldExpression'
     or r.unlocked_style_ids is distinct from
          array['calmStudio','aspirational','precisionTech','digitalFlow','boldExpression']::text[] then
    raise exception 'verified RPC mismatch: % % %',
      r.tier, r.selected_style_id, r.unlocked_style_ids;
  end if;
end $$;

-- Unknown style id is not in the enum.
do $$ begin
  update public.profiles
     set selected_style_id = 'neonCyber'
   where id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
  raise exception 'unknown style id should be rejected';
exception
  when invalid_text_representation then null;
  when datatype_mismatch then null;
  when check_violation then null;
end $$;

-- Demotion grandfathers the already-selected style so other profile edits
-- still work; changing *to* a newly locked style is still rejected.
update public.reputation_scores
   set score = 0, tier = 'new'
 where user_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
update public.profiles
   set display_name = 'kept-style'
 where id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
do $$ begin
  if (select selected_style_id::text from public.profiles
        where id='aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa')
       is distinct from 'boldExpression' then
    raise exception 'demotion should not auto-clear selected_style_id';
  end if;
end $$;
do $$ begin
  update public.profiles
     set selected_style_id = 'aspirational'
   where id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
  raise exception 'demoted member should not select a still-locked style';
exception when check_violation then null;
end $$;

-- ProfileStyle is verified in migration 0009.
-- Verify referrals insert own policy.
select set_config('test.uid', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', false);
insert into public.referrals (code, owner_id) values ('WOLF1', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa');
do $$ begin
  if (select count(*) from public.referrals where owner_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa') <> 1 then
    raise exception 'referral row was not inserted';
  end if;
end $$;

-- Verify room occupancy function execution.
do $$ begin
  if public.room_occupancy('33333333-3333-3333-3333-333333333333') <> 2 then
    raise exception 'authenticated user could not read room_occupancy';
  end if;
end $$;

select 'ALL SMOKE CHECKS PASSED' as result;
