# Grok Build Prompt — CleanText (vertical config)

Build `docs/build-prompts/sms-core-engine.md` first. This prompt adds only
what's specific to CleanText — config data and one schema migration, not new
architecture. Full business spec: `docs/launch-kits/cleantext.md`.

## Schema migration required before adding this vertical

The `sms_engine.businesses.vertical` check constraint in the core engine
currently allows only `'textback_local'`, `'smsdispatch'`, `'noshowguard'`.
Run this migration before wiring up CleanText:

```sql
alter table sms_engine.businesses
  drop constraint businesses_vertical_check;

alter table sms_engine.businesses
  add constraint businesses_vertical_check
  check (vertical in ('textback_local','smsdispatch','noshowguard','cleantext','reztext'));
```

Add both `cleantext` and `reztext` in one migration rather than two — they
are being built in the same pass, and the constraint is cheap to update.

## Triggers

CleanText is a **dual-trigger vertical** — the only other dual-trigger
vertical is RezText; both sit above the single-trigger TextBack Local and
SMSDispatch.

**Trigger 1 — missed-call text-back:**
`trigger_type = 'missed_call'`. Source: business's phone-forwarding webhook
fires on an unanswered call after N rings (N configurable per business,
default 4). `trigger_ref` = telephony provider's call SID (naturally unique,
idempotency for free). This trigger is identical in shape to TextBack Local's
trigger — the only difference is the outbound template.

**Trigger 2 — visit reminder:**
`trigger_type = 'reminder_due'`. Source: a scheduled cron job (Vercel Cron,
same pattern as `ganesh-engine/vercel.json`) runs hourly, queries each
CleanText business's visit list for appointments starting in `lead_time_hours`
from now (default 48 hours), and creates one thread per appointment not yet
sent (idempotent on `trigger_ref` = the scheduling system's visit/appointment
ID). A second send is queued at `lead_time_hours = 2` (2-hour same-day nudge)
but only fires if the 48-hour thread has zero inbound messages — check
`sms_engine.messages` for zero rows with `direction = 'inbound'` on the
parent thread before creating the nudge thread.

MVP ships with manual visit entry: cleaning company enters upcoming visit
dates and times directly in the dashboard (no scheduling API integration in
this pass). The `trigger_ref` for manually entered visits is a UUID the app
generates at entry time — still idempotent because the UUID is stable once
assigned. Document the ZenMaid and Jobber API integration paths in the
CleanText section of the README as v2 items.

## Keyword vocabulary (`config/verticals.ts` entry)

| Inbound keyword | Status transition |
| --- | --- |
| `C` / `CONFIRM` / `YES` | `confirmed` |
| `R` / `RESCHEDULE` / `NO` | `declined` |
| `STOP` | opt-out (carrier-required) |

The missed-call text-back thread uses a simplified vocabulary: any reply at
all from the customer is success (same reasoning as TextBack Local — the value
is "did the lead respond," not a specific state transition). For threads with
`trigger_type = 'missed_call'`, treat any non-STOP inbound as
`replied_matched` and surface it immediately in the inbox without requiring
the customer to type a keyword. Only the reminder threads (`trigger_type =
'reminder_due'`) require C/R/YES/NO to drive a state transition.

## Outbound templates

**Missed-call text-back (trigger_type = 'missed_call'):**
```
Sorry we missed your call! This is {{business_name}} — would you like
to schedule a cleaning? Just reply here and we'll get you set up.
Reply STOP to opt out.
```

**48-hour visit reminder (trigger_type = 'reminder_due', lead_time_hours = 48):**
```
Reminder: your cleaning with {{business_name}} is scheduled for
{{visit_time}}. Reply C to confirm or R to reschedule.
```

**2-hour same-day nudge (trigger_type = 'reminder_due', lead_time_hours = 2,
only sent if 48h reminder received zero replies):**
```
Quick reminder — your cleaning with {{business_name}} is today at
{{visit_time}}. Reply C to confirm or R to reschedule.
```

`{{visit_time}}` renders as a human-readable local time string (e.g. "Thursday
at 10:00 AM") — the vertical config owns this format, not the core engine.

## Dashboard label overrides

"Thread" → "Visit" (for reminder threads) or "Lead" (for missed-call threads)
— surface the thread type in the inbox header row so the staff member
immediately knows whether they're looking at a new inquiry or a visit
confirmation.

"replied_matched" → "Responded" (for missed-call threads) or "Confirmed" (for
reminder threads after a C/YES reply).

"declined" → "Needs reschedule" — surface these at the top of the visit list
in the same priority-above-normal style as SMSDispatch's reassignment queue.
A declined reminder means a revenue slot just opened up that needs to be
rebooked or offered to another customer.

"stale" → "No reply — at risk" on reminder threads (no response after 2-hour
nudge = probable no-show); "Lead lost" on missed-call threads (no reply after
24 hours).

## Nothing else to build in this pass

No ZenMaid or Jobber API integration — manual visit entry ships in MVP.
No Stripe deposit link — v2 upsell.
No self-serve reschedule link inside the SMS — v2.
No TCPA consent-at-booking flow beyond the STOP opt-out in the outbound
template — note in the README that pilot businesses must collect SMS consent
from customers at booking time before enabling CleanText on real customers,
and that this is a legal review item before scaling beyond the pilot.
