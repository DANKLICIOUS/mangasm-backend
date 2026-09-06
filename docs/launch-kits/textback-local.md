# TextBack Local — Turnkey Launch Kit

> **Decision-support notice:** Scores and forecasts in this package are estimates based on cited evidence and explicit assumptions. They do not guarantee profit, popularity, funding, or product-market fit.

## Executive Decision

| Item | Result |
| --- | --- |
| One-line concept | Missed-call text-back for local service businesses — an unanswered call auto-sends an SMS within seconds to capture the lead instead of losing it |
| Winning keyword bundle | local business × missed calls × SMS text-back × subscription |
| Profit Potential | 7.5/10 — medium confidence |
| Popularity Potential | 6.5/10 — medium confidence |
| Ease of Use/Learning | 8.5/10 — medium confidence |
| Composite | **7.40/10** |
| Build gate | **PASSED** — all 6 gates cleared (2026-08-02 run) |
| Immediate next move | Ship the 7-day validation sprint below to the parked 5D Handyman (Fresno, CA) prospect — package exists at `ecosystem-builder/drafts/prospects/5d-handyman/`, held at the Tier 3 owner-approval gate |

## Business Design

Local service businesses (HVAC, plumbing, electrical, landscaping, garage doors, locksmiths — one- to ten-truck operators) lose jobs every day to calls they can't pick up because the owner or the one dispatcher is on a ladder, under a sink, or driving. Missed-call text-back auto-replies to any unanswered inbound call within seconds with a friendly SMS ("Sorry we missed you — what can we help with today?"), captures the reply in a simple inbox, and routes it into the owner's existing booking/bid workflow. The buyer is the owner-operator or office manager, the purchase trigger is a recent lost job they can point to, and the differentiation is speed-to-text plus zero setup complexity versus general-purpose CRM/marketing suites that bundle this as an afterthought feature.

## Product System

### Core Workflow

Inbound call rings through as normal → if unanswered after N rings, the provisioned business number auto-sends the text-back SMS → customer reply lands in a shared web/SMS inbox the owner or dispatcher already checks → a manual or template reply closes the loop → the thread is tagged won/lost for a lightweight funnel view. No app to install for the customer; the business side needs only a phone number and a browser.

### Four Skills or Capabilities

| Skill | Customer Value |
| --- | --- |
| Instant missed-call text-back | Recovers leads inside the 5-minute response window that drives up to 8x higher conversion |
| Shared team inbox | Any staff member can see and answer texts from one place instead of a personal phone |
| Template + quick-reply library | Common answers (pricing ranges, service area, booking link) sent in one tap |
| Lead tagging and simple funnel view | Owner sees recovered-vs-lost calls without needing a full CRM |

### Four Integrations or Plugins

| Integration | Purpose | Required for MVP? |
| --- | --- | --- |
| Twilio (SMS + number provisioning) | Sends/receives the text-back messages | Yes |
| Existing business phone forwarding | Detects the unanswered-call trigger | Yes |
| Calendar/booking link (Calendly-class) | Converts a warm reply into a scheduled job | No — v2 upsell |
| Stripe | Deposit/invoice link inside the text thread | No — v2 upsell |

## Customer Experience

First-use: business owner forwards their existing number or ports a new one in under 10 minutes, sets one auto-reply template, and is live same-day. Time to value is the first recovered call, typically within 24-48 hours given normal call volume. No customer-facing learning curve — the end customer just receives a text like any other. Support is a shared inbox plus a short FAQ; accessibility is inherently high since SMS requires no app or account.

## Brand Directions

| Direction | Palette and Mood | Audience Fit | Risk |
| --- | --- | --- | --- |
| Dark | Charcoal/near-black with a single safety-orange accent, utilitarian | Strong — matches trades' existing truck-wrap and tool-brand aesthetic | Can read "too techy" to older owner-operators if overdone |
| Light | White/light-gray with navy accent, clean SaaS look | Good — signals trustworthy software, not a gimmick | Slightly generic, harder to stand out against CRM incumbents |
| Rainbow | Multi-color gradient, energetic | Poor | Reads consumer-app, undermines trust with a 55+ trades buyer |
| Pastel cotton candy | Soft pink/mint, playful | Poor | Actively mismatched to the trades buyer persona |
| **Selected direction** | **Dark**, safety-orange accent | — | Trades owners already trust this palette family (Milwaukee Tool, Ryobi, road-crew signage); reinforces "built for people who work with their hands," not another SaaS dashboard |

## Conversion Copy

**Headline:** "Every missed call is a lost job. Not anymore."
**Subheadline:** "TextBack Local auto-texts anyone who calls and doesn't reach you — so the lead doesn't hang up and call your competitor."
**Benefits:** Recover 25-60% of missed calls into booked jobs · Reply within 60 seconds gets a 35-50% response rate · No app, no new number to give out, live same day
**Objections handled:** "I already have a CRM" → most trades CRMs bundle this poorly or not at all; this is a 10-minute add-on, not a replacement. "Will it sound robotic?" → the first text is templated but every reply after is a real person in the shared inbox.
**Proof plan:** 7-day free trial with a before/after missed-call recovery count shown directly in the dashboard.
**Primary CTA:** "Start your free 7-day trial — no card required."

## Go-to-Market

Direct outreach to owner-operators in one metro at a time (starting with the already-researched 5D Handyman, Fresno CA), using the existing SCOUT→FORGE→HERALD pipeline: SCOUT identifies businesses with public reviews mentioning slow response/missed calls, FORGE builds a personalized demo showing their own business name in the text-back flow, HERALD sends the pitch. Secondary channel: trade-association Facebook groups and local trade Slack/Discord communities where owner-operators already ask each other for tool recommendations. Shareability is inherently word-of-mouth within tight trade networks once one operator sees a recovered job.

## Operating Workflow and Approval Tier

> Subscription or request → orchestrator → specialist agent with selected skills and integrations → evidence and scorecard → approval tier → customer output

SCOUT researches a named prospect (read-only) → FORGE builds a personalized demo (`spec.json` + `demo.html`, local only) → HERALD drafts the outreach email, held in `drafts/pending/` → **Tier 3 gate: owner must move the draft to `drafts/approved/` and pass `--send` explicitly** before any message reaches a real inbox. No step in this pipeline sends, publishes, or charges without that explicit approval.

## Three-Year Annual Operating Summary

**Currency and units:** USD, whole numbers
**Basis:** Management-based scenario; not audited actuals.

| Metric | Year 1 | Year 2 | Year 3 | Basis |
| --- | ---: | ---: | ---: | --- |
| Paying accounts (end of year) | 40 | 150 | 400 | Assumption: 3-5 new accounts/mo Y1, accelerating with referrals Y2-3 — TBD, unvalidated |
| Units or accounts | 40 | 150 | 400 | Cumulative net of churn |
| Average price | $79/mo | $89/mo | $99/mo | Sourced pricing band for standalone text-back tools is $30-300/mo; positioned mid-low to undercut CRM bundles |
| Gross sales | $37,920 | $160,200 | $475,200 | Units × 12 × avg price (simplified, ignores mid-year ramp) |
| Direct costs | $6,000 | $18,000 | $42,000 | Twilio SMS/number fees at ~$15/account/mo blended — assumption |
| Other variable costs | $2,000 | $7,500 | $20,000 | Payment processing, support tooling — assumption |
| Fixed operating expense | $18,000 | $36,000 | $60,000 | Founder time proxy + hosting + outreach tooling — assumption |
| Net operating cash before debt and tax | $11,920 | $98,700 | $353,200 | Gross sales − direct − variable − fixed |
| Net operating cash margin | 31% | 62% | 74% | Net operating cash / gross sales |

**Sensitivity:** Entire Year 1-3 build rests on an unvalidated churn assumption (not sourced) and an unvalidated close rate on outbound outreach — both are the actual purpose of the 7-day validation sprint below, not settled facts.

## 30/60/90-Day Revenue Plan

| Window | Objective | Deliverables | Metric | Continue/Kill Rule |
| --- | --- | --- | --- | --- |
| Days 1–30 | Validate outreach → demo → close conversion on real prospects | Send the parked 5D Handyman package + 9 more in the same metro (Tier 3 approved) | ≥1 paid pilot signed | If 0 of 10 respond positively, revisit messaging/channel before scaling spend |
| Days 31–60 | Prove retained usage, not just signup | 5-10 active accounts using the shared inbox weekly | ≥60% weekly-active rate | If usage collapses after week 1, fix onboarding before adding accounts |
| Days 61–90 | First repeatable acquisition channel | Expand to a second metro using whichever channel (direct outreach vs. trade-group) converted better | CAC payback under 3 months | If neither channel is efficient, pause paid growth and return to referral-only |

## Risks and Controls

Commodity-category risk (existing text-back tools already exist) is controlled by competing on trades-specific onboarding speed and pricing, not novelty. CAN-SPAM/outreach compliance is controlled by HERALD's built-in suppression list, daily send cap, and mandatory footer. Twilio number reputation/deliverability risk is controlled by warmup practices already documented in the outreach sender. No customer PII beyond what's needed for the text thread is stored beyond the minimum retention window — TBD exact policy pending legal review before scaling past pilot.

## Seven-Day Validation Sprint

Day 1-2: get Tier 3 approval and send the 5D Handyman package plus 9 additional Fresno-area prospects. Day 3-4: track open/reply rate on outreach itself (not the product) — this validates HERALD's pitch, separate from product-market fit. Day 5-6: for any prospect who replies positively, get on a call and demo the live `demo.html` walkthrough; ask for a paid pilot at $79/mo, not a free trial, to test real willingness to pay. Day 7: write the result back into `docs/factory-runs/` as a real evidence point — win or no-win, this closes the loop that has been open since 2026-08-02.

## Assumptions, TBD Items, and Sources

**Sourced:** missed-call text-back recovers 25-60% of missed calls into booked jobs; 60-second reply gets 35-50% response rate; 8x conversion lift within a 5-minute window; standalone tools price $30-300/mo (blog.automatedsalesmachine.com, netpartners.marketing, getaira.io — see `docs/factory-runs/2026-08-02.md`).
**Assumptions (not sourced, flagged):** churn rate, close rate on cold outreach, CAC, Twilio per-account cost blend, all Year 1-3 account-growth figures.
**TBD:** exact PII retention policy at scale; whether a second SMS provider is needed as Twilio backup for deliverability.

## Pending Human Approval

Tier 3 — required before any further action: approve and send the 5D Handyman outreach package (`ecosystem-builder/drafts/prospects/5d-handyman/`) and the 9 additional prospects needed to run the validation sprint above. Nothing in this kit has been sent, published, or charged.
