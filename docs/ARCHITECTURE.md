# Architecture

## System shape

```
┌──────────────────────┐        ┌───────────────────────────────┐
│  iOS app (SwiftUI)    │        │  Supabase                      │
│                       │        │                                │
│  AuthManager  ───────────────► │  Auth (phone OTP + OAuth/PKCE) │
│  MapViewModel ───────────────► │  Postgres + PostGIS            │
│  ChatViewModel───────────────► │   - profiles, events, messages │
│  EventViewModel──────────────► │   - reputation, vouches, …     │
│                       │        │  Realtime  (presence, DMs)     │
│                       │        │  Edge Functions (Deno)         │
└──────────────────────┘        │   - recalculate-score          │
                                 │   - file-report                │
                                 └───────────────────────────────┘
```

The iOS client talks to Supabase with the **anon key** only. Privileged work
(scoring, report flagging, future selfie verification) runs in edge functions
with the **service-role key**, which never leaves the server.

## Data model (entities)

- **profiles** — one row per `auth.users` row, created automatically by the
  `handle_new_user` trigger. Holds handle, display name, bio, `tags[]`,
  membership tier, verification flag, presence status, and the
  privacy-adjusted `location` (a PostGIS `geography(Point)`).
- **privacy_zones** — per-user home disguise. The app computes a disguised point
  (hidden / drift / landmark) and stores *that* as `profiles.location`; the raw
  GPS is never persisted server-side.
- **events** + **event_rsvps** — member-hosted events with a type, content tag
  (sfw/adult/explicit), geo point, optional capacity, and visibility. The street
  `address` is withheld by the app until ~2h before `starts_at`.
- **messages** — direct messages; Realtime delivers them live.
- **blocks**, **reports**, **vouches** — the safety + reputation inputs.
- **reputation_scores** — cached output of the scoring edge function.

## Reputation flow

1. Members **vouch** (positive only) and **report**.
2. `file-report` sets `timing_flag` when a report follows a recent block
   (spite-report shield).
3. `recalculate-score` aggregates vouches, events hosted, valid (non-flagged)
   reports, and blocks into a 0–100 score + tier, and upserts
   `reputation_scores`. Clients can read scores but never write them (RLS).
   There is **no** database trigger that invokes the function after a
   vouch/report/block/event — run it on a schedule or on-demand.
4. Cached `tier` unlocks cosmetic `profiles.selected_style_id` values
   (`0009_profile_style.sql`). iOS should call `my_profile_style()` and
   treat `unlocked_style_ids` as canonical. See [`PROFILE_STYLE.md`](PROFILE_STYLE.md).

## Key RLS gates (enforced in DB, mirror these in the app's UI)

| Action          | Requirement                                         |
| --------------- | --------------------------------------------------- |
| Host an event   | Plus member **and** verified **and** account ≥ 30 days |
| Vouch           | Account ≥ 14 days, not blocked with the vouchee     |
| See a profile   | Not banned, not blocked in either direction         |
| Premium events  | `visibility='premium'` visible only to Plus members |
| Pick a ProfileStyle | `selected_style_id` must be unlocked by current `reputation_scores.tier` |

## iOS client wiring (reference)

```swift
let url = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as! String
let key = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as! String

let client = SupabaseClient(
    supabaseURL: URL(string: url)!,
    supabaseKey: key,
    options: .init(auth: .init(emitLocalSessionAsInitialSession: true))
)

// Map feed
let nearby: [NearbyUser] = try await client
    .rpc("users_within_radius", params: ["lat": lat, "lng": lng, "radius_m": 8047])
    .execute().value

// Events (this is the table that was missing before — it exists now)
let events: [Event] = try await client
    .from("events")
    .select()
    .eq("status", value: "live")
    .gte("starts_at", value: ISO8601DateFormatter().string(from: Date()))
    .order("starts_at", ascending: true)
    .execute().value

// Reputation-gated ProfileStyle (see docs/PROFILE_STYLE.md)
let style: MyProfileStyle = try await client.rpc("my_profile_style").execute().value
```

> Keys belong in a gitignored `Config.xcconfig` referenced from `Info.plist`
> (`SUPABASE_URL = $(SUPABASE_URL)`), not hardcoded in Swift.

## Extended modules (migrations 0003–0005)

- **Tokens** (`0003`) — `token_wallets` + an append-only `token_transactions`
  ledger. A trigger derives each wallet's balance from the ledger and rejects
  overdraws, so balance is never written directly and can't drift. Earning,
  tipping, purchases, and payouts all go through service-role edge functions.
- **Video rooms** (`0004`) — `video_rooms` (Daily.co-backed, the join URL is set
  server-side) + `video_room_participants`, with `room_occupancy()` for live
  counts. Hosting requires Plus + verified; rooms are visible to verified members.
- **Matchmaking** (`0005`) — `match_preferences`, a pgvector `match_vectors`
  taste embedding (cosine ANN index), and `match_results`. The
  `generate-daily-matches` edge function scores nearby candidates and writes up
  to 5 results per member per day.
- **ProfileStyle** (`0009`) — `profiles.selected_style_id` unlocked by
  `reputation_scores.tier`; `my_profile_style()` is the iOS one-round-trip
  contract. Canonical doc: [`PROFILE_STYLE.md`](PROFILE_STYLE.md).

## CI

`.github/workflows/db-ci.yml` spins up Postgres 16 + PostGIS + pgvector, applies
every migration against the `supabase/tests/shim.sql` Supabase shim, runs
`supabase/tests/ci_smoke.sql`, and re-applies the migrations to prove
idempotency — on every push that touches the schema.

Canonical migrations are **this** repo. The iOS app repo has a divergent
`supabase/` tree (`0001_mangasm_init.sql`, `profiles.rep_score`, …). Do not
`db push` both against one project. See [`PROFILE_STYLE.md`](PROFILE_STYLE.md).

## Still to layer on

Token payouts (Stripe Connect / crypto), selfie verification, spam-pattern
detection, and the accountability-email flow are stubbed or documented and slot
in as additional edge functions without further schema churn.
