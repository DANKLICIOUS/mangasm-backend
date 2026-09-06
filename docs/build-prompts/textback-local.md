# Grok Build Prompt — TextBack Local (vertical config)

Build `docs/build-prompts/sms-core-engine.md` first. This prompt adds only
what's specific to TextBack Local — config data, not new architecture. Full
business spec: `docs/launch-kits/textback-local.md`.

## Trigger

`trigger_type = 'missed_call'`. Source: business's phone-forwarding webhook
fires on an unanswered call after N rings (N configurable per business,
default 4). `trigger_ref` = the telephony provider's call SID (naturally
unique, gives idempotency for free).

## Keyword vocabulary (`config/verticals.ts` entry)

| Inbound keyword | Status transition |
| --- | --- |
| (any reply at all) | `replied_matched` → tag as "lead captured", no further keyword logic needed — for this vertical, a reply of any kind is success; TextBack Local doesn't need confirm/decline, it needs "did the lead respond" |
| `STOP` | opt-out, suppress future sends to this contact (required — carrier compliance, not optional) |

This vertical's keyword layer is intentionally the simplest of the three:
the entire value proposition is "did we get a reply at all," so there is no
branching logic to build beyond opt-out handling. Do not add confirm/decline
states here — that would be scope creep against a vertical whose evidence
base (`docs/factory-runs/2026-08-02.md`) is about reply-rate, not
booking-state tracking.

## Outbound template

```
Sorry we missed your call! This is {{business_name}} — what can we help you
with today? Reply STOP to opt out.
```

One template, no variants needed for MVP. A/B copy testing is a v2 item, not
a Week 1 build task.

## Dashboard label overrides

"Thread" → "Lead". "replied_matched" → "Lead responded". "stale" (no reply
after 24h) → "Lead lost".

## Nothing else to build

No calendar integration (not in this vertical's MVP scope per its launch
kit's Integration table). No booking-link auto-send. Ship the shared-engine
feature set as-is; this vertical is the cheapest of the three to stand up
precisely because it needs zero extra logic beyond the engine default —
that's a feature of the design, not a gap.
