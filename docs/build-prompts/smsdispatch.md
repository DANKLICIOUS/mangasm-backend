# Grok Build Prompt — SMSDispatch (vertical config)

Build `docs/build-prompts/sms-core-engine.md` first. This prompt adds only
what's specific to SMSDispatch — config data, not new architecture. Full
business spec: `docs/launch-kits/smsdispatch.md`.

## Trigger

`trigger_type = 'load_created'`. Source: dispatcher enters a load in the
console (build the console as a minimal form — pickup, delivery, time
window, notes — writing directly to `sms_engine.threads` with
`trigger_type='load_created'`; no separate "loads" table needed for MVP,
the thread row itself is the load record). `trigger_ref` = a
dispatcher-generated load number (e.g. `LOAD-{{business_id short}}-{{seq}}`,
generated server-side, unique per business).

## Keyword vocabulary (`config/verticals.ts` entry)

| Inbound keyword | Status transition |
| --- | --- |
| `CONFIRM` / `C` | `confirmed` |
| `DECLINE` / `D` | `declined` |
| `EN ROUTE` / `ENROUTE` | no status column change needed for MVP — log as a `messages` row only; full status-history tracking beyond confirm/declined is a v2 dashboard feature, not required to prove the core loop |
| `DELIVERED` | `confirmed` stays, but tag thread as complete via a boolean flag added to this vertical's dashboard view only (do not add a new engine-wide column for one vertical's extra state — keep the shared schema generic, handle vertical-specific extra states as a JSON `metadata` column read only by that vertical's dashboard) |
| `STOP` | opt-out (carrier-required) |

Add one generic `metadata jsonb` column to `sms_engine.threads` in the
engine migration (small addition, worth doing once now rather than
special-casing later) so SMSDispatch can stash `{"delivered": true}` without
forcing NoShowGuard or TextBack Local to carry unused columns.

## Outbound template

```
New load {{trigger_ref}}: pickup {{pickup_location}} at {{pickup_time}},
deliver to {{delivery_location}}. Reply C to confirm, D to decline. — {{business_name}} Dispatch
```

## Dashboard label overrides

"Thread" → "Load". "confirmed" → "Driver confirmed". "declined" → "Needs
reassignment" (surface these at the top of the dispatcher's console view —
this is the state that actually costs the business money if missed).

## Flagged but explicitly deferred (do not build in this pass)

ELD/GPS auto-confirm integration and accounting export are both marked "not
required for MVP" in the launch kit's Integration table — leave them out.
The in-transit-messaging legal review flagged in the launch kit's Risks
section is a real open item; do not scope any "live routing while driving"
feature until that review happens — this build stays limited to pre-trip
load assignment and confirmation, which is the scope the evidence
(`docs/factory-runs/2026-08-04.md`) actually supports.
