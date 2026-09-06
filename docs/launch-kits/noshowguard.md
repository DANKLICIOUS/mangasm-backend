# NoShowGuard — Turnkey Launch Kit

> **Decision-support notice:** Scores and forecasts in this package are estimates based on cited evidence and explicit assumptions. They do not guarantee profit, popularity, funding, or product-market fit.

## Executive Decision

| Item | Result |
| --- | --- |
| One-line concept | SMS appointment reminders and two-way confirmations for local, appointment-based service businesses — cuts no-shows before they happen instead of recovering missed calls after |
| Winning keyword bundle | local business × care coordination × SMS text-back × subscription |
| Profit Potential | 7.5/10 — high confidence |
| Popularity Potential | 6.5/10 — medium confidence |
| Ease of Use/Learning | 8.0/10 — medium confidence |
| Composite | **7.28/10** |
| Build gate | **PASSED** — all 6 gates cleared (2026-08-05 run) |
| Immediate next move | Sequence as vertical #2 behind TextBack Local once trades validates — same core SMS engine, proactive instead of reactive, so most of the build is shared infrastructure |

## Business Design

Appointment-based local businesses (salons, clinics, contractors doing scheduled estimates, auto-repair shops) lose revenue every time a booked customer simply doesn't show up — a slot that can't be resold on short notice. NoShowGuard sends an automatic SMS ahead of the appointment ("Reminder: your appointment is tomorrow at 2pm — reply C to confirm or R to reschedule"), letting the business recover a reschedule instead of an empty slot. The buyer is the owner or office manager who already runs a calendar/booking system; the purchase trigger is a recent costly no-show; the differentiation is a two-way confirm-or-reschedule loop rather than a one-way reminder blast, which is what most existing tools in this crowded category actually do.

## Product System

### Core Workflow

Business connects its existing calendar/booking system → NoShowGuard schedules a reminder text at a configurable lead time (24h, then optionally a shorter same-day nudge) → customer replies C (confirm) or R (reschedule) → a confirm updates the calendar status, a reschedule routes to a booking link or notifies staff to call back → no-show rate and recovered-reschedule count roll up into a simple dashboard.

### Four Skills or Capabilities

| Skill | Customer Value |
| --- | --- |
| Two-way confirm/reschedule reminders | Turns a passive reminder into an active recovery of the slot |
| Configurable lead-time sequencing | 24h + same-day nudge fits both quick-turn (salon) and longer-lead (contractor estimate) businesses |
| Calendar-status sync | Confirms/reschedules reflect in the business's existing calendar without manual re-entry |
| No-show recovery dashboard | Owner sees dollars-recovered, not just messages-sent |

### Four Integrations or Plugins

| Integration | Purpose | Required for MVP? |
| --- | --- | --- |
| Twilio (SMS + number provisioning) | Sends/receives reminder and confirm/reschedule texts | Yes |
| Calendar/booking system (Calendly, Square Appointments, Vagaro-class) | Source of truth for appointment times | Yes |
| Booking link (self-serve reschedule) | Lets a "R" reply self-serve into a new slot without staff time | No — v2 upsell |
| Payment/deposit link (Stripe) | Optional no-show-deposit collection for chronic offenders | No — v2 upsell |

## Customer Experience

First-use: business connects its existing calendar (OAuth or CSV import for less common systems) and sets one reminder template and lead time — live same-day. Time to value is the first recovered reschedule, typically within the first week given normal appointment volume. Customer-facing experience is a single, familiar text exchange, no app or account needed. Support and learning burden are low on both sides; the harder part is calendar-integration coverage across many booking-system vendors, which is the actual engineering risk in this kit, not the SMS layer itself.

## Brand Directions

| Direction | Palette and Mood | Audience Fit | Risk |
| --- | --- | --- | --- |
| Dark | Deep teal/near-black with a warm accent, calm-professional | Good for clinics/salons wanting a premium feel | Slightly heavier than a fast, transactional tool needs |
| Light | White with soft blue/green accent, clean and approachable | Strong — matches the trustworthy, appointment-reminder tone customers expect from a clinic or salon | Similar to many incumbent reminder tools' look |
| Rainbow | Multi-color gradient | Poor for clinics; possibly acceptable for salons only | Inconsistent across the full buyer range (clinic to contractor) |
| Pastel cotton candy | Soft pink/mint, playful | Only for the salon/beauty slice of the buyer base | Mismatched for clinics and contractors, too narrow to be the default |
| **Selected direction** | **Light**, soft blue/green accent | — | Works across the full buyer range (salon, clinic, contractor) without alienating any one vertical; premium-but-approachable tone fits the "protecting your schedule" positioning |

## Conversion Copy

**Headline:** "Stop losing slots to no-shows."
**Subheadline:** "NoShowGuard texts your customers before their appointment and lets them confirm or reschedule with one reply — so an empty slot becomes a recovered one."
**Benefits:** SMS reminders cut no-shows by 25-58% depending on industry and lead time · 98% SMS open rate vs. ~20% for email · Two-way confirm/reschedule recovers the slot instead of just reminding
**Objections handled:** "I already send email reminders" → email open rates are a fraction of SMS; most no-shows never opened the email. "Customers will find texting annoying" → one well-timed reminder they can act on in one reply is the opposite of spam — it's positioned as a convenience.
**Proof plan:** 14-day free trial with a before/after no-show-rate comparison shown directly in the dashboard.
**Primary CTA:** "See your no-show rate drop — start free."

## Go-to-Market

Direct outreach to appointment-based local businesses via the same SCOUT→FORGE→HERALD pipeline, targeting businesses with public review mentions of scheduling friction or a visible cancellation policy (a proxy for no-show pain). Secondary channel: partnerships with the booking-system vendors themselves (many lack a strong native two-way SMS confirm flow) as a potential integration/referral partner rather than pure competitor. Given the category is more crowded than trades text-back, differentiation messaging leans on the two-way confirm/reschedule mechanic specifically, not "SMS reminders" generically.

## Operating Workflow and Approval Tier

> Subscription or request → orchestrator → specialist agent with selected skills and integrations → evidence and scorecard → approval tier → customer output

SCOUT researches named appointment-based prospects (read-only) → FORGE builds a personalized demo of the confirm/reschedule flow → HERALD drafts outreach, held in `drafts/pending/` → **Tier 3 gate: owner must explicitly approve and move to `drafts/approved/` before any send.** Calendar-integration credentials are only requested from a business that has already agreed to a pilot, never collected speculatively.

## Three-Year Annual Operating Summary

**Currency and units:** USD, whole numbers
**Basis:** Management-based scenario; not audited actuals.

| Metric | Year 1 | Year 2 | Year 3 | Basis |
| --- | ---: | ---: | ---: | --- |
| Paying accounts (end of year) | 35 | 140 | 380 | Assumption, modeled close to TextBack Local's trajectory given the shared engine and buyer profile — unvalidated |
| Units or accounts | 35 | 140 | 380 | Cumulative net of churn |
| Average price | $69/mo | $79/mo | $89/mo | No exact price point sourced this run (flagged 2026-08-05); positioned slightly below TextBack Local given a more crowded competitive set |
| Gross sales | $28,980 | $132,720 | $405,840 | Units × 12 × avg price |
| Direct costs | $5,000 | $16,500 | $38,000 | Twilio SMS/number fees + calendar-integration maintenance overhead — assumption |
| Other variable costs | $2,000 | $7,000 | $19,000 | Payment processing, support tooling — assumption |
| Fixed operating expense | $18,000 | $35,000 | $58,000 | Founder time proxy + hosting + outreach tooling — assumption |
| Net operating cash before debt and tax | $3,980 | $74,220 | $290,840 | Gross sales − direct − variable − fixed |
| Net operating cash margin | 14% | 56% | 72% | Net operating cash / gross sales |

**Sensitivity:** Year 1 margin is thin because calendar-integration engineering cost is front-loaded and not amortized here — this is the single biggest execution risk in the kit, more than acquisition or pricing. If integration coverage lags, Year 1 figures should be treated as optimistic.

## 30/60/90-Day Revenue Plan

| Window | Objective | Deliverables | Metric | Continue/Kill Rule |
| --- | --- | --- | --- | --- |
| Days 1–30 | Validate outreach → demo → close on appointment-based prospects | Send 10 prospect packages (Tier 3 approved), covering at least 2 sub-verticals (e.g. salon + contractor) | ≥1 paid pilot signed | If 0 of 10 respond, test whether the two-way-confirm differentiation actually lands vs. generic "SMS reminders" messaging |
| Days 31–60 | Prove the calendar-integration path is buildable at pilot scale | Live integration with the pilot's actual booking system | Reminder-to-confirm sync works with zero manual re-entry | If integration effort blows the budget for one pilot, narrow MVP to a single supported calendar system before expanding |
| Days 61–90 | Confirm sequencing behind trades | Compare pilot conversion and integration effort against TextBack Local's Days 61-90 results | Relative build cost per dollar of recovered revenue | If integration overhead makes this materially more expensive than trades per dollar recovered, keep it a lower-priority vertical #2 as planned |

## Risks and Controls

Category crowding (appointment-reminder SMS is a known, competitive SMB space — SimpleTexting, Weave, SmileSnap-class incumbents) is controlled by leading with the two-way confirm/reschedule mechanic rather than competing as a generic reminder tool. Calendar-integration fragmentation risk is controlled by launching with one well-supported system first (TBD which) rather than promising broad compatibility at MVP. CAN-SPAM/TCPA-adjacent SMS-consent risk is controlled by requiring explicit opt-in language at calendar-integration setup — this needs legal review before any pilot collects real customer phone numbers, flagged as a hard control.

## Seven-Day Validation Sprint

Day 1-2: get Tier 3 approval and send 10 appointment-based prospect packages across at least 2 sub-verticals. Day 3-4: track outreach reply rate separately from product interest, same as the other two kits. Day 5-6: for replies, demo the confirm/reschedule flow live and propose a paid pilot to test real willingness to pay against the stated $69/mo price point. Day 7: write the result into `docs/factory-runs/` — this closes the loop on the third build-gate SMS winner and gives the portfolio its first real read on whether the proactive-reminder mechanic converts as well as the reactive-recovery mechanic already being tested by TextBack Local.

## Assumptions, TBD Items, and Sources

**Sourced:** SMS appointment reminders reduce no-shows by 25-58% depending on industry and lead time; SMS open rates run ~98% vs. ~20% for email; two-way confirm-or-reschedule sequences perform best (see `docs/factory-runs/2026-08-05.md`).
**Assumptions (not sourced, flagged):** exact SMS-reminder tool pricing point, churn rate, close rate on cold outreach, calendar-integration engineering cost, all Year 1-3 account-growth figures.
**TBD:** which calendar/booking system to support first at MVP; TCPA-adjacent consent-language legal review.

## Pending Human Approval

Tier 3 — required before any further action: approve and send the 10-prospect appointment-based outreach batch. Nothing in this kit has been sent, published, or charged. No calendar credentials or customer phone numbers have been collected.
