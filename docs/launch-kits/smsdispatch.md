# SMSDispatch — Turnkey Launch Kit

> **Decision-support notice:** Scores and forecasts in this package are estimates based on cited evidence and explicit assumptions. They do not guarantee profit, popularity, funding, or product-market fit.

## Executive Decision

| Item | Result |
| --- | --- |
| One-line concept | SMS-based load dispatch for small trucking carriers — dispatchers text load assignments and route updates, drivers confirm without an app or login |
| Winning keyword bundle | frontline teams (trucking/dispatch) × missed calls × SMS text-back × usage based |
| Profit Potential | 7.5/10 — high confidence |
| Popularity Potential | 6.5/10 — medium confidence |
| Ease of Use/Learning | 8.0/10 — medium confidence |
| Composite | **7.28/10** |
| Build gate | **PASSED** — all 6 gates cleared (2026-08-04 run) |
| Immediate next move | Validate demand with 10 small-carrier prospects using the same SCOUT→FORGE→HERALD pipeline, sequenced behind TextBack Local's pilot per the portfolio priority order |

## Business Design

Small trucking carriers (91.5% of the ~3.2M-driver US market run 10 or fewer trucks) coordinate load assignments, pickup/delivery details, and route changes over phone and radio — channels that require drivers to be reachable live and dispatchers to repeat information constantly. SMSDispatch lets a dispatcher push a load assignment as a text; the driver confirms with a reply, no app, no login, no training. The buyer is the owner-operator or small dispatch office; the purchase trigger is missed handoffs or slow confirmation costing time and fuel; the differentiation is zero-friction adoption for drivers who won't install another app, priced per-message or per-driver to fit a usage-variable, thin-margin business instead of a flat SaaS fee that assumes steady headcount.

## Product System

### Core Workflow

Dispatcher enters a load (pickup, delivery, time window, notes) in a simple web console → system texts the assigned driver → driver replies with a single keyword (CONFIRM/DECLINE/EN ROUTE/DELIVERED) → dispatcher's console updates in real time → status history is logged per load for the office's own recordkeeping. No driver-side app; the entire driver interface is native SMS.

### Four Skills or Capabilities

| Skill | Customer Value |
| --- | --- |
| One-text load assignment | Dispatcher pushes a load in seconds instead of a phone call per driver |
| Keyword status replies | Driver confirms/updates status without opening any app |
| Real-time dispatch console | Office sees fleet status at a glance instead of tracking calls on a whiteboard |
| Load history log | Lightweight audit trail for disputes or billing questions, no separate TMS needed at this size |

### Four Integrations or Plugins

| Integration | Purpose | Required for MVP? |
| --- | --- | --- |
| Twilio (SMS + number provisioning) | Sends/receives dispatch texts | Yes |
| Simple web console (dispatcher side) | Where loads are entered and status is tracked | Yes |
| ELD/GPS feed | Auto-fills pickup/delivery confirmation from location | No — v2 upsell |
| Accounting export (QuickBooks-class) | Turns delivered-load history into billing records | No — v2 upsell |

## Customer Experience

First-use: dispatcher signs up, adds driver phone numbers (no driver-side signup at all), and sends a first test load same-day. Time to value is the first successful confirm-by-text, typically within hours of setup. Zero learning burden for drivers — SMS is universally familiar; the console side needs only basic web literacy, well within reach of a small dispatch office. Support is phone/email given the buyer profile skews toward people who prefer a human over a chatbot.

## Brand Directions

| Direction | Palette and Mood | Audience Fit | Risk |
| --- | --- | --- | --- |
| Dark | Steel gray/black with amber/CB-radio-style accent | Strong — echoes trucking/CB culture and road signage | Could feel dated if leaned too retro |
| Light | White with deep blue accent, clean dispatch-software look | Good — reads as serious operational software | Less differentiated from incumbent TMS dashboards |
| Rainbow | Multi-color gradient | Poor | Undermines trust with a utilitarian, safety-conscious buyer |
| Pastel cotton candy | Soft pastel palette | Poor | Actively mismatched to the trucking-dispatch buyer |
| **Selected direction** | **Dark**, amber accent | — | Matches the visual language dispatchers and drivers already associate with reliable, no-nonsense road equipment |

## Conversion Copy

**Headline:** "Dispatch by text. No app. No training. No missed loads."
**Subheadline:** "SMSDispatch lets your drivers confirm loads with a single reply — from any phone, no download required."
**Benefits:** One named carrier saw response rates jump from 71% (phone+email) to 87% with SMS alone, driving 15% revenue growth · Usage-based pricing scales with your truck count, not a flat SaaS fee · Live same day, zero driver onboarding
**Objections handled:** "My drivers won't use new tech" → they don't install anything; it's a text message, same as any other. "We already call/radio" → SMS doesn't replace radio for live routing, it replaces the repeated confirmation calls that eat dispatcher time.
**Proof plan:** 14-day free trial capped at 5 drivers, dispatcher sees their own before/after confirmation-time metric.
**Primary CTA:** "Try it free with your next 5 loads."

## Go-to-Market

Direct outreach to small carriers (≤10 trucks) via the same SCOUT→FORGE→HERALD pipeline, sourced from public carrier directories and trucking-association member lists. Secondary channel: owner-operator Facebook groups and trucking-specific forums (TruckersReport, Land Line Now community) where dispatch pain is a constant discussion topic. Given the fragmented, relationship-driven nature of small carriers, referrals between owner-operators who already know each other are expected to be a stronger channel than paid ads — TBD, unvalidated until the pilot runs.

## Operating Workflow and Approval Tier

> Subscription or request → orchestrator → specialist agent with selected skills and integrations → evidence and scorecard → approval tier → customer output

SCOUT researches named small-carrier prospects (read-only, public directories only) → FORGE builds a personalized demo console mockup → HERALD drafts outreach, held in `drafts/pending/` → **Tier 3 gate: owner must explicitly approve and move to `drafts/approved/` before any send.** No load-management or driver contact data is collected until a business is a paying pilot with its own consent flow.

## Three-Year Annual Operating Summary

**Currency and units:** USD, whole numbers
**Basis:** Management-based scenario; not audited actuals.

| Metric | Year 1 | Year 2 | Year 3 | Basis |
| --- | ---: | ---: | ---: | --- |
| Paying carrier accounts (end of year) | 25 | 100 | 280 | Assumption — smaller/slower funnel than trades given a more fragmented, referral-dependent buyer; unvalidated |
| Units or accounts | 25 | 100 | 280 | Cumulative net of churn |
| Average price | $0.05/msg or $15/driver/mo blended to ~$120/mo/account | $135/mo/account | $150/mo/account | Usage-based pricing point is TBD — no exact figure sourced, only the response-rate/revenue case study (flagged 2026-08-04) |
| Gross sales | $36,000 | $162,000 | $504,000 | Units × 12 × avg blended price |
| Direct costs | $4,500 | $16,000 | $42,000 | Twilio per-message costs scale with load volume, not flat per account — assumption |
| Other variable costs | $1,800 | $7,000 | $18,000 | Payment processing, support tooling — assumption |
| Fixed operating expense | $18,000 | $34,000 | $55,000 | Founder time proxy + hosting + outreach tooling — assumption |
| Net operating cash before debt and tax | $11,700 | $105,000 | $389,000 | Gross sales − direct − variable − fixed |
| Net operating cash margin | 33% | 65% | 77% | Net operating cash / gross sales |

**Sensitivity:** The entire revenue line depends on an unsourced usage-based price point — the case study evidence is response-rate and revenue-impact, not a pricing benchmark. Treat Year 1-3 figures as illustrative until the validation sprint below produces a real price test.

## 30/60/90-Day Revenue Plan

| Window | Objective | Deliverables | Metric | Continue/Kill Rule |
| --- | --- | --- | --- | --- |
| Days 1–30 | Validate outreach → demo → close with small carriers | Send 10 prospect packages (Tier 3 approved) | ≥1 paid pilot signed | If 0 of 10 respond, revisit whether trucking dispatch offices trust an unfamiliar vendor for something operationally sensitive |
| Days 31–60 | Establish a real usage-based price point | Run at least 2 pilots at different price structures (per-message vs. per-driver) | Pilot renews at month 2 | If neither structure clears willingness-to-pay, reconsider flat-rate pricing instead |
| Days 61–90 | Confirm the trades-vs-trucking sequencing decision | Compare trades vs. trucking pilot conversion side by side | Relative CAC and close rate delta | If trucking underperforms trades meaningfully, deprioritize trucking behind trades expansion |

## Risks and Controls

Regulatory/safety exposure: dispatch communication that could be construed as instructing drivers while operating is controlled by scoping SMSDispatch to pre-trip/at-rest confirmations, not live in-cab messaging — this needs explicit legal review before any pilot, flagged as a hard control, not a suggestion. Deliverability/carrier-filtering risk (SMS from a new business number can get flagged as spam by carriers) is controlled by the same Twilio warmup practices used for TextBack Local. Fragmented buyer risk (many tiny, hard-to-reach accounts) is controlled by leaning on association/directory-sourced outreach rather than broad cold prospecting.

## Seven-Day Validation Sprint

Day 1-2: get Tier 3 approval and send 10 small-carrier prospect packages sourced from public directories. Day 3-4: track outreach reply rate separately from product interest. Day 5-6: for replies, demo the console mockup live and propose a paid pilot at a stated usage-based price to test real willingness to pay, not just interest. Day 7: write the result into `docs/factory-runs/` — this is the second of two winning SMS concepts now needing the same real-world test that TextBack Local's sprint is also waiting on; sequence trucking behind trades per the portfolio recommendation unless capacity allows both in parallel.

## Assumptions, TBD Items, and Sources

**Sourced:** small-carrier response rate jumped from 71% (phone+email) to 87% with SMS alone for a named carrier (DFH Transportation), driving 15% revenue growth; ~3.2M professional drivers in the US; 91.5% of carriers run 10 or fewer trucks (ajot.com, eztexting.com, textus.com — see `docs/factory-runs/2026-08-04.md`).
**Assumptions (not sourced, flagged):** usage-based pricing point, churn rate, close rate on cold outreach, all Year 1-3 account-growth figures.
**TBD:** legal review of in-transit messaging exposure; whether an all-in-one dispatch/ELD/accounting platform absorbs this as a bundled feature before a standalone product can gain share (counter-signal noted in the original 2026-08-04 evidence notes).

## Pending Human Approval

Tier 3 — required before any further action: approve and send the 10-prospect trucking outreach batch. Nothing in this kit has been sent, published, or charged. No driver PII has been collected.
