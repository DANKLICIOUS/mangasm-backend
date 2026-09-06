# Grok Build Prompt — RezText (vertical config)

Build `docs/build-prompts/sms-core-engine.md` first. This prompt adds only
what's specific to RezText — config data and one schema migration, not new
architecture. Full business spec: `docs/launch-kits/reztext.md`.

## Schema migration required before adding this vertical

The `sms_engine.businesses.vertical` check constraint in the core engine
currently allows only `'textback_local'`, `'smsdispatch'`, `'noshowguard'`.
Run this migration before wiring up RezText (same migration as CleanText —
run once, covers both):

```sql
alter table sms_engine.businesses
  drop constraint businesses_vertical_check;

alter table sms_engine.businesses
  add constraint businesses_vertical_check
  check (vertical in ('textback_local','smsdispatch','noshowguard','cleantext','reztext'));
```

If CleanText was already added in the same session, skip this — the constraint
is already updated.

## Triggers

RezText is a **dual-trigger vertical** — same shape as CleanText, different
timing and template. The restaurant context makes both triggers
structurally important: missed-call text-back recovers the 67% of
reservation calls that come in by phone; the reminder sequence recovers the
revenue lost to no-shows on booked covers.

**Trigger 1 — missed-call text-back:**
`trigger_type = 'missed_call'`. Source: business's phone-forwarding webhook
fires on an unanswered call after N rings (N configurable per business,
default 4). `trigger_ref` = telephony provider's call SID (naturally unique,
idempotency for free). Identical in shape to TextBack Local's trigger.

**Trigger 2 — reservation reminder:**
`trigger_type = 'reminder_due'`. Source: a scheduled cron job (Vercel Cron,
same pattern as `ganesh-engine/vercel.json`) runs hourly, queries each
RezText business's reservation list for bookings starting in `lead_time_hours`
from now (default 24 hours), and creates one thread per reservation not yet
sent (idempotent on `trigger_ref` = the reservation system's booking ID). A
second send is queued at `lead_time_hours = 2` (2-hour same-day nudge) but
only fires if the 24-hour thread has zero inbound messages — check
`sms_engine.messages` for zero rows with `direction = 'inbound'` on the
parent thread before creating the nudge thread.

MVP ships with manual reservation entry: restaurant staff enter upcoming
reservations directly in the dashboard (no OpenTable/Resy API in this pass).
The `trigger_ref` for manually entered reservations is a UUID the app
generates at entry time — still idempotent. Document the OpenTable and Resy
API integration paths in the README as v2 items.

The reservation list needs two extra fields not required by the generic
engine's `threads` table: `party_size` (integer) and `reservation_time`
(timestamptz). Store these as metadata on the thread:

```sql
alter table sms_engine.threads
  add column if not exists metadata jsonb;
```

RezText populates `metadata = {"party_size": 4, "reservation_time":
"2026-08-22T19:00:00-07:00"}` at thread creation; the template renderer reads
from this column to interpolate `{{party_size}}` and `{{reservation_time}}`
into the outbound message. Other verticals leave `metadata` null — no
migration needed on their side.

## Keyword vocabulary (`config/verticals.ts` entry)

| Inbound keyword | Status transition |
| --- | --- |
| `C` / `CONFIRM` / `YES` | `confirmed` |
| `R` / `CANCEL` / `NO` | `declined` |
| `STOP` | opt-out (carrier-required) |

For threads with `trigger_type = 'missed_call'`, treat any non-STOP inbound
as `replied_matched` and surface immediately in the inbox without requiring a
keyword — a prospect replying to a missed-call text-back is a lead, not a
reservation state to track. Only reminder threads (`trigger_type =
'reminder_due'`) drive confirmed/declined transitions.

## Outbound templates

**Missed-call text-back (trigger_type = 'missed_call'):**
```
Hi! We missed your call at {{business_name}} — would you like to make
a reservation? Just reply here and we'll take care of you.
Reply STOP to opt out.
```

**24-hour reservation reminder (trigger_type = 'reminder_due', lead_time_hours = 24):**
```
Reminder: your reservation at {{business_name}} is {{reservation_time}}
for {{party_size}}. Reply C to confirm or R to cancel.
```

**2-hour same-day nudge (trigger_type = 'reminder_due', lead_time_hours = 2,
only sent if 24h reminder received zero replies):**
```
Quick heads-up — your table at {{business_name}} is tonight at
{{reservation_time}}. See you soon! Reply R if plans changed.
```

`{{reservation_time}}` renders as a human-readable local time string (e.g.
"tomorrow at 7:00 PM" for the 24h send, "7:00 PM" for the 2h nudge). The
vertical config owns the formatting rule; the engine passes raw timestamps.

## Dashboard label overrides

"Thread" → "Reservation" (for reminder threads) or "Lead" (for missed-call
threads).

"replied_matched" → "Lead responded" (missed-call threads) or "Confirmed"
(reminder threads after a C/YES reply).

"declined" → "Canceled" — surface these prominently at the top of the
reservation list so the host can immediately rebook the table, not scroll
past it. A canceled reservation is a recoverable revenue slot if caught
early.

"stale" → "No reply — probable no-show" on reminder threads; "Lead lost" on
missed-call threads (no reply after 24 hours).

## Party size in the dashboard

Surface `party_size` from `threads.metadata` in the reservation list view.
A host managing a dinner service needs to see "4 guests at 7pm — confirmed"
not just "thread ID abc123 — confirmed." This is a UI concern, not an engine
change — the engine stores the data, the dashboard reads it.

## Nothing else to build in this pass

No OpenTable or Resy API integration — manual reservation entry ships in MVP.
No Stripe deposit link for large-party reservations — v2 upsell (worth
adding: a party of 12 that cancels last-minute is a significant loss; a
deposit link in the confirmation thread could have real retention value, but
it is explicitly out of scope for Week 1).
No self-serve reschedule booking flow inside the SMS — v2.
No catering/private-event booking flow (RezText Catering scored 6.35 and did
not clear the build gate; do not expand the product to cover it in this
pass).
No TCPA consent beyond STOP opt-out — same legal review note as CleanText:
document that pilot restaurants must collect SMS consent at reservation time
before enabling RezText on real guest phone numbers.
