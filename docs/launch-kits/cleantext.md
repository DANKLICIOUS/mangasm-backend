# CleanText — Turnkey Launch Kit

> **Decision-support notice:** Scores and forecasts in this package are estimates based on cited evidence and explicit assumptions. They do not guarantee profit, popularity, funding, or product-market fit.

## Executive Decision

| Item | Result |
| --- | --- |
| One-line concept | Missed-call text-back plus a 3-touch visit reminder sequence for residential cleaning companies — recovers lost inquiries the moment a call goes unanswered, then cuts no-shows with automated SMS before every scheduled visit |
| Winning keyword bundle | local business × missed calls × SMS text-back × subscription |
| Profit Potential | 8.0/10 — high confidence |
| Popularity Potential | 6.5/10 — medium confidence |
| Ease of Use/Learning | 8.0/10 — high confidence |
| Composite | **7.48/10** |
| Build gate | **PASSED** — all 6 gates cleared (2026-08-20 run) |
| Immediate next move | Build a SCOUT prospect brief for 10 residential cleaning companies in one metro (do not use the 5D Handyman list — that targets trades operators, not cleaning businesses); get Tier 3 approval before any outreach |

## Business Design

Independent and small residential cleaning companies (1-10 cleaners, owner-operated or with one scheduler) lose revenue two ways every day: inbound inquiries that call while the owner is cleaning and never call back, and booked visits where the customer isn't home or forgot and the cleaner shows up to an empty house. CleanText solves both with one SMS product: an automated missed-call text-back fires within seconds of any unanswered inbound call, and a three-touch reminder sequence (confirm at booking → 48-hour reminder → 2-hour reminder) replaces the manual "are you still good for Thursday?" call that most cleaning owners either forget or don't have time to make.

The dollar case is direct: without reminders, cleaning businesses commonly run 15-20% no-shows on booked visits; at roughly $150 per missed visit, four no-shows a month costs over $600 in lost revenue — not counting the cleaner's wasted drive time and the customer who cancels the recurring contract after a second missed slot. A structured reminder cadence brings the no-show rate to 2-5%. The missed-call conversion case is equally sharp: research specifically on cleaning company inbound inquiries frames automated text-back as the single infrastructure piece that separates the 20% of cleaning companies that consistently convert inbound leads from the 80% that do not.

The competitive landscape for dedicated missed-call and reminder tools in cleaning is fragmented — small cleaning-specific vendors, no single Mindbody/Booksy-class incumbent. Cleaning company scheduling software (Jobber, ZenMaid, Housecall Pro) handles invoicing, routing, and payments; SMS reminder and missed-call text-back specifically are not their core marketed feature. This is the same gap that let TextBack Local and ShopText clear the gate in their verticals.

## Product System

### Core Workflow

Inbound call rings → if unanswered after N rings, auto-sends text-back SMS ("Sorry we missed your call — we'd love to help! What's a good time for your cleaning?") → customer reply lands in shared team inbox → staff replies and schedules the booking. Separately: when a visit is booked in the connected scheduling system, a cron job queues three SMS sends — booking confirmation immediately, 48-hour reminder ("Your cleaning is scheduled for Thursday at 10am — reply C to confirm or R to reschedule"), and a 2-hour same-day nudge if the 48-hour message never got a reply. All replies land in the same shared inbox.

### Four Skills or Capabilities

| Skill | Customer Value |
| --- | --- |
| Instant missed-call text-back | Recovers lost inquiries inside the 5-minute window that drives highest conversion before a prospect calls a competitor |
| 3-touch visit reminder sequence | Cuts no-show rate from 15-20% to 2-5%, saving $600+/month on four prevented no-shows alone |
| Shared team inbox | Owner and any scheduler can see and answer all texts from one browser — no personal phone forwarding |
| Visit-outcome tagging | Owner can mark visits confirmed, rescheduled, or no-showed; dashboard shows running no-show rate at a glance |

### Four Integrations or Plugins

| Integration | Purpose | Required for MVP? |
| --- | --- | --- |
| Twilio (SMS + number provisioning) | Sends and receives all text-back messages | Yes |
| Phone forwarding (business number) | Detects the unanswered-call trigger | Yes |
| ZenMaid or Jobber (scheduling) | Reads upcoming visits to queue reminder sends | No — MVP ships with manual visit entry; scheduling API is v2 |
| Stripe | In-thread payment/deposit link for new booking conversions | No — v2 upsell |

## Customer Experience

First-use: owner forwards their current business number or provisions a new Twilio number in under 10 minutes, enters one or two upcoming visit appointments manually (scheduling API integration is v2), and is live with both the missed-call and reminder workflows same day. Time to first value: the first recovered inquiry call, typically within 24-48 hours given normal cleaning company inbound volume. The customer-facing experience is plain SMS — no app, no login, no learning curve. The owner's side is a browser tab: one shared inbox, a simple visit list, and a weekly count of recovered calls and confirmed visits.

## Brand Directions

| Direction | Palette and Mood | Audience Fit | Risk |
| --- | --- | --- | --- |
| Light | White/light-gray with a teal or mint accent, clean and fresh | Strong — matches the "clean home" category association; signals reliability and trust | Slightly generic; must use copy, not design, to differentiate from generic SaaS |
| Dark | Charcoal with a white or light-blue accent, professional | Good — signals a serious B2B tool | Can read cold for a service-oriented buyer who associates "cleaning" with warmth |
| Rainbow | Multi-color gradient, energetic | Poor | Looks consumer, not operator-focused |
| Pastel cotton candy | Soft pink/mint | Poor | Could work for a consumer cleaning app, but cleaning business operators skew toward utility-first purchasing |
| **Selected direction** | **Light**, teal accent | — | Teal/mint reads "clean and fresh" without being playful; it's the brand palette of the cleaning category itself (Method, Clean Mama, MaidThis all use green/teal adjacent), which makes the association immediate and credible to the buyer |

## Conversion Copy

**Headline:** "Your cleaners show up. Your customers should too."
**Subheadline:** "CleanText automatically texts back every missed call and reminds every customer before their visit — so no-shows stop costing you jobs."
**Benefits:** Recover lost inquiries in under 60 seconds · Cut no-show rates from 15-20% to under 5% · No app for customers — just texts they actually read
**Objections handled:** "I already text customers manually" → manual texting doesn't work at midnight or during a job; CleanText fires automatically whether you're cleaning or sleeping. "Won't customers find it annoying?" → customers who booked a cleaning and then forgot thank you for the reminder; no-show reschedule rates climb when reminders are friendly, not pushy.
**Proof plan:** 30-day free trial with a before/after comparison of no-show count and recovered calls shown in the dashboard.
**Primary CTA:** "Start your free 30-day trial — no card required."

## Go-to-Market

Direct outreach to owner-operators of independent residential cleaning companies in one metro at a time, using the SCOUT→FORGE→HERALD pipeline: SCOUT identifies cleaning companies with public reviews mentioning scheduling issues or no-shows, FORGE builds a personalized demo showing their business name in the text-back and reminder flows, HERALD drafts the outreach. Promising secondary channels: cleaning industry Facebook groups and forums (Cleaning Business Owners on Facebook, House Cleaning Association communities), where operators actively share "what tools do you use" recommendations. Word-of-mouth within cleaning operator networks is strong — if one operator recovers three no-shows in the first week, they post about it.

## Operating Workflow and Approval Tier

SCOUT researches a named prospect (read-only) → FORGE builds a personalized demo (`spec.json` + `demo.html`, local only) → HERALD drafts the outreach email, held in `drafts/pending/` → **Tier 3 gate: owner must move the draft to `drafts/approved/` and pass `--send` explicitly** before any message reaches a real inbox. No step sends, publishes, or charges without that explicit approval.

## Three-Year Annual Operating Summary

**Currency and units:** USD, whole numbers
**Basis:** Management-based scenario; not audited actuals.

| Metric | Year 1 | Year 2 | Year 3 | Basis |
| --- | ---: | ---: | ---: | --- |
| Paying accounts (end of year) | 40 | 155 | 390 | Assumption: 3-4 new accounts/mo Y1 from direct outreach, accelerating with referral Y2-3 — TBD, unvalidated |
| Units or accounts | 40 | 155 | 390 | Cumulative net of churn |
| Average price | $99/mo | $119/mo | $129/mo | Estimated; no pricing evidence sourced — assumption based on combined product value (missed-call + reminder) above standalone text-back ($79 TextBack Local); marked TBD |
| Gross sales | $47,520 | $221,220 | $603,720 | Units × 12 × avg price (simplified, ignores mid-year ramp) |
| Direct costs | $7,200 | $27,900 | $70,200 | Twilio SMS/number fees at ~$15/account/mo blended; reminder sequence sends more messages/account than pure text-back — assumption |
| Other variable costs | $2,000 | $8,000 | $22,000 | Payment processing, support tooling — assumption |
| Fixed operating expense | $18,000 | $36,000 | $60,000 | Founder time proxy + hosting + outreach tooling — assumption |
| Net operating cash before debt and tax | $20,320 | $149,320 | $451,520 | Gross sales − direct − variable − fixed |
| Net operating cash margin | 43% | 68% | 75% | Net operating cash / gross sales |

**Sensitivity:** Year 1-3 projections rest entirely on unvalidated close rate, churn, and pricing assumptions — none of the three is sourced. The pricing point especially is a gap: no competitor pricing evidence was pulled in the 08-20 factory run. Running a quick pricing search on dedicated cleaning-sector SMS and reminder tools is the first step before setting a price.

## 30/60/90-Day Revenue Plan

| Window | Objective | Deliverables | Metric | Continue/Kill Rule |
| --- | --- | --- | --- | --- |
| Days 1–30 | Validate outreach → demo → close on real cleaning company operators | Build SCOUT prospect brief for 10 residential cleaning companies in one metro (Tier 3 approval required to send) | ≥1 paid pilot signed at any price | If 0 of 10 respond positively, revisit the pitch channel before scaling; cleaning owners are reachable on Facebook groups if direct outreach fails |
| Days 31–60 | Prove both workflows (missed-call and reminder) generate real recoveries | 5-10 active accounts using the shared inbox weekly; track no-show count before and after | ≥50% of pilot accounts see measurable no-show reduction in their first 30 days | If no-show reduction isn't visible, the reminder timing or template copy needs fixing, not the product model |
| Days 61–90 | First repeatable channel | Expand to a second metro or begin cleaning industry forum seeding | CAC payback under 4 months | If neither outreach nor forum channel is working, pull back and get on calls with pilot accounts to find where referrals actually come from |

## Risks and Controls

No-show reduction is real but the claimed magnitude (15-20% → 2-5%) depends on customers consistently replying to SMS reminders — if the cleaning company's customer base skews older or less SMS-active, the reduction may be lower. Control: build the before/after no-show count into the dashboard from day one so the result is measured, not assumed. CAN-SPAM and TCPA compliance on reminder SMS requires that the customer opted into SMS at booking time — document this in the onboarding flow and include STOP support. Cleaning company churn risk is real (small businesses fail or pause service); pricing must account for churn with a long enough trial to confirm genuine product value before a 12-month subscription lock.

## Seven-Day Validation Sprint

Day 1-2: get Tier 3 approval on outreach to 10 residential cleaning companies in one metro (build the SCOUT brief, no sends without approval). Day 3-4: track open/reply rate on outreach to validate HERALD's pitch, separate from product-market fit. Day 5-6: for any positive replies, demo the live `demo.html` walkthrough of the shared inbox + reminder sequence; ask for a paid pilot at $99/mo, not a free trial, to test real willingness to pay. Day 7: write the result back into `docs/factory-runs/` as a real evidence point — win or no-win, this closes the validation loop on the 7th build-gate winner.

## Assumptions, TBD Items, and Sources

**Sourced:** Cleaning businesses without reminders run 15-20% no-show/missed-visit rate; at $150/visit, 4 no-shows/month = $600+ loss; structured 3-touch SMS reminder cadence (confirm at booking → 48h → 2h) reduces no-show rate to 2-5% (miocommerce.com, leadduo.io — see `docs/factory-runs/2026-08-20.md`). Automated text-back is "the single infrastructure piece that separates the 20% of cleaning companies that convert inbound inquiries from the 80% that do not" (ustechautomations.com — same run). SMS open rates ~98% vs 20-35% for email (cross-vertical, cited in prior runs).
**Assumptions (not sourced, flagged):** pricing ($99-129/mo — no competitor pricing evidence sourced), churn rate, close rate on cold outreach, CAC, Twilio per-account cost blend, all Year 1-3 account-growth figures.
**TBD:** pricing research against dedicated cleaning-sector SMS tools is the #1 open item before pricing the pilot. MVP scheduling integration: ZenMaid or Jobber API for reading upcoming visits (v1 ships with manual visit entry). Exact TCPA SMS consent wording at booking time.

## Pending Human Approval

Tier 3 — required before any further action: build SCOUT prospect brief for 10 residential cleaning companies in one metro, then approve outreach via the HERALD pipeline. Nothing in this kit has been sent, published, or charged.
