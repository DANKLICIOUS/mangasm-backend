# ProfileStyle iOS contract

Cosmetic profile themes unlocked by Community Reputation. **Server is the
source of truth** — the iOS picker may preview, but writes go through this
schema and are rejected when the style is locked.

This is additive on `gothamgodzilla/mangasm-backend` (canonical migrations).
Do **not** `supabase db push` the iOS repo’s `supabase/` tree against the same
project (see Dual-tree hazard below).

## Round-trip RPC

```sql
select * from public.my_profile_style();
```

PostgREST:

```swift
struct MyProfileStyle: Decodable {
    let score: Int
    let tier: String                 // "new" | "building" | "reliable" | "verified"
    let unlocked_style_ids: [String] // ProfileStyleId raw values
    let selected_style_id: String
}

let state: MyProfileStyle = try await client
    .rpc("my_profile_style")
    .execute()
    .value
```

Requires an authenticated JWT (`auth.uid()`). Unauthenticated calls raise.

## Persist a choice

Column: `profiles.selected_style_id`  
Type: enum `profile_style_id`  
Default: `calmStudio` (always unlocked)

```swift
try await client
    .from("profiles")
    .update(["selected_style_id": styleId.rawValue])
    .eq("id", value: session.user.id.uuidString)
    .execute()
```

A locked style returns a check violation (`profile style {id} is not unlocked
for the current reputation tier`). Keep showing every style the RPC listed in
`unlocked_style_ids`; do not recompute unlocks from the local catalog when
online.

Other members can **read** `selected_style_id` on `profiles` (existing select
policy). They cannot write it.

## Style IDs (must match `ProfileStyleId`)

| `selected_style_id` | Swift `ProfileStyleId` | RN / legacy alias |
| ------------------- | ---------------------- | ----------------- |
| `calmStudio`        | `.calmStudio`          | `bobRoss`         |
| `aspirational`      | `.aspirational`        | `lambo`           |
| `precisionTech`     | `.precisionTech`       | `cyborg`          |
| `digitalFlow`       | `.digitalFlow`         | `matrix`          |
| `boldExpression`    | `.boldExpression`      | `gothGlam`        |

Server stores and returns the Swift raw values, not the RN aliases.

## Score, tier, unlocks

`recalculate-score` writes `reputation_scores.score` (0–100) and `tier`.
Unlocks are keyed off **tier** (not a parallel score ladder):

| Tier       | Score band (edge function) | Unlocked styles                                                      |
| ---------- | -------------------------- | -------------------------------------------------------------------- |
| `new`      | `< 40`                     | `calmStudio`                                                         |
| `building` | `>= 40`                    | + `aspirational`                                                     |
| `reliable` | `>= 65`                    | + `precisionTech`, `digitalFlow`                                     |
| `verified` | `>= 85`                    | + `boldExpression` (all five)                                        |

Read `score` / `tier` from this RPC (or `reputation_scores`). Do **not** write
those tables from the client — no INSERT/UPDATE RLS policy exists.

A later demotion does **not** auto-clear `selected_style_id`. The member keeps
the look they already picked; they just cannot switch to a newly locked style.
Unrelated profile edits still succeed.

## iOS catalog mismatch (read this)

`Sources/MangasmApp/Domain/Reputation/ProfileStyleCatalog.swift` currently
unlocks by **score** at 0 / 21 / 41 / 61 / 81 (five badge bands). That local
table predates this backend gate and **does not match** the server.

Until the iOS catalog is aligned, treat `my_profile_style().unlocked_style_ids`
as canonical whenever a session is live. The 2026-08-03 iOS spec also sketched
`profiles.preferred_style` and `profiles.rep_score`; this repo uses:

- `profiles.selected_style_id` (not `preferred_style`)
- `reputation_scores.score` (not a denormalized `profiles.rep_score`)

Cosmetic only: never hide messages, adult content, or matching behind a style.

## Scoring hooks (no new DB triggers)

There are **no** Postgres triggers that call `recalculate-score` after a
vouch, report, block, or event. Scores stay cached until:

1. Scheduled invoke of `recalculate-score` (no `userId` → sweep), or
2. On-demand invoke with `{ "userId": "<uuid>" }` after a relevant write.

`file-report` does not recompute scores. Do not add `pg_net` / webhook
triggers from this migration — they need project URL + service-role secrets
that do not belong in git. Invoke the existing edge function instead.

## Dual-tree hazard

Canonical migrations live **here**: `supabase/migrations/0001_*.sql` …
`0009_profile_style.sql`.

The iOS repo `DANKLICIOUS/Mangasm` has a **divergent** `supabase/migrations/`
tree (`0001_mangasm_init.sql`, `profiles.rep_score`, different RLS, no
`reputation_scores` table). Those files are not a copy of this repo.

Applying both trees to one Supabase project will drift or fail. Point
`supabase link` / `db push` at **this** backend repo only. Port iOS-only
columns across as additive migrations here if they are still needed.
