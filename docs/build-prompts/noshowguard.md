# Grok Build Prompt — NoShowGuard (vertical config)

Build `docs/build-prompts/sms-core-engine.md` first. This prompt adds only
what's specific to NoShowGuard — config data, not new architecture. Full
business spec: `docs/launch-kits/noshowguard.md`.

## Trigger

`trigger_type = 'reminder_due'`. Source: a scheduled job (Vercel Cron, same
pattern as `ganesh-engine/vercel.json`), not a live webhook — this is the
one vertical whose trigger is time-based rather than event-based. Cron runs
hourly, queries each business's connected calendar for appointments
starting in `lead_time_hours` (default 24, per-business configurable), and
creates one thread per appointment not already sent (idempotent on
`trigger_ref` = the calendar system's appointment ID).

**This is the one piece of real engineering risk in this vertical** — it's
the only trigger that depends on an external calendar integration rather
than a webhook the business already has. Build against exactly ONE calendar
provider for MVP (recommend Calendly's API — best-documented, most common
among small appointment-based businesses) and hard-fail loudly (log to
`sms_engine.ai_usage`-style audit table, no — log to a
`sms_engine.integration_errors` table, one column: `business_id`,
`error`, `created_at`) rather than silently skipping a business's reminders
if the calendar call fails. Do not attempt broad calendar-system
compatibility in this pass; that scope was explicitly flagged TBD in the
launch kit and multi-provider support is a v2 expansion once the first
integration is proven live with a real pilot.

## Keyword vocabulary (`config/verticals.ts` entry)

| Inbound keyword | Status transition |
| --- | --- |
| `C` / `CONFIRM` / `YES` | `confirmed` |
| `R` / `RESCHEDULE` / `NO` | `declined` (dashboard label below reframes this as "needs reschedule," not a dead end) |
| `STOP` | opt-out (carrier-required) |

## Outbound template

```
Reminder: your appointment with {{business_name}} is {{appointment_time}}.
Reply C to confirm or R to reschedule.
```

Same-day nudge (optional second send at `lead_time_hours = 2`, only if the
first reminder never got a reply — check `messages` for zero inbound rows on
the thread before sending):

```
Quick reminder — your appointment with {{business_name}} is today at
{{appointment_time}}. Reply C to confirm or R to reschedule.
```

## Dashboard label overrides

"Thread" → "Appointment". "confirmed" → "Confirmed". "declined" → "Needs
reschedule" (surface at the top, same reasoning as SMSDispatch's
reassignment queue — this is the money-losing state if ignored).

## Flagged but explicitly deferred (do not build in this pass)

Self-serve reschedule booking link and deposit/payment collection are both
marked "not required for MVP" in the launch kit's Integration table.
TCPA-adjacent SMS-consent legal review flagged in the launch kit's Risks
section is a real open item — do not connect a pilot business's real
customer phone numbers until that review happens; build and test this
vertical against synthetic/test calendar data first.
