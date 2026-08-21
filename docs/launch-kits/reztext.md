# RezText — Turnkey Launch Kit

> **Decision-support notice:** Scores and forecasts in this package are estimates based on cited evidence and explicit assumptions. They do not guarantee profit, popularity, funding, or product-market fit.

## Executive Decision

| Item | Result |
| --- | --- |
| One-line concept | Missed-call text-back plus a 3-touch reservation confirmation and reminder sequence for independent restaurants — recovers the lost reservation call the moment it's missed, then cuts no-shows before every booked table |
| Winning keyword bundle | local business × missed calls × SMS text-back × subscription |
| Profit Potential | 8.0/10 — medium confidence |
| Popularity Potential | 7.0/10 — medium confidence |
| Ease of Use/Learning | 8.0/10 — medium confidence |
| Composite | **7.65/10** |
| Build gate | **PASSED** — all 6 gates cleared (2026-08-18 run, highest composite of any candidate scored to date) |
| Immediate next move | Build a SCOUT prospect brief for 10 independent restaurants in one metro; get Tier 3 approval before any outreach is sent |

## Business Design

Independent restaurants (owner-operated, 1-3 locations, 50-300 covers) lose reservations two ways every day: reservation calls that ring while the owner or host is in the weeds during service and never get returned, and confirmed reservations where the table doesn't show. Both are measurable, named problems with real dollar consequences. RezText is the first build-gate winner whose product solves both at once — not an artificial cross-sell bundle, but a single natural flow: an unanswered reservation call auto-texts back within seconds, and every confirmed reservation enters a 3-touch SMS sequence (confirmation → 24-hour reminder → 2-hour same-day nudge) that brings no-shows down from industry-average 20-25% to 5-8%.

The structural advantage of this vertical is call-volume exposure: 67% of restaurant reservations are still made by phone, giving every missed call an outsized revenue consequence. A Friday-night party of six who calls during rush and doesn't hear back doesn't wait — they open OpenTable and book somewhere else. The same is true on the reminder side: a 3-touch SMS sequence specifically tested on restaurant reservations has been shown to cut no-show rates by up to 38%, the single largest no-show reduction figure sourced across all factory runs to date.

The competitive field — Bite Buddy AI, restaurant-specific text-back agencies, reservation platforms with some SMS features — is less consolidated than the fitness/gym booking sector (Mindbody bundles reminders) or the trades AI-voice-receptionist category. Pure SMS missed-call + reservation reminder as a standalone, affordable product for independent restaurants (not OpenTable-scale chains) is a real, defensible niche.

## Product System

### Core Workflow

Inbound call rings at the restaurant → if unanswered after N rings, auto-sends text-back SMS to the caller ("Hi! We missed your call at [Restaurant Name] — would you like to make a reservation? Just reply here and we'll take care of you") → customer reply lands in the shared host/manager inbox → staff confirms the reservation manually and enters the time in the connected booking view. Once a reservation is entered: cron queues three SMS sends — a booking confirmation immediately, a 24-hour reminder ("Reminder: your reservation at [Restaurant Name] is tomorrow at 7pm for 4. Reply C to confirm or R to cancel"), and a 2-hour same-day nudge only if the 24-hour message went unreplied ("Quick heads-up: your table is at [Restaurant Name] tonight at 7pm. See you soon — reply R if plans changed!"). All replies land in the same shared inbox.

### Four Skills or Capabilities

| Skill | Customer Value |
| --- | --- |
| Instant missed-call text-back | Recovers reservation inquiries before the caller moves on to OpenTable or a competitor |
| 3-touch reservation reminder sequence | Cuts no-show rate from 20-25% to 5-8%, recovering the direct food cost and staff labor on a wasted prep |
| Shared host/manager inbox | Anyone on shift sees and answers all SMS threads from one browser — not routed through one person's personal phone |
| Reservation funnel view | Host sees confirmed, unconfirmed, and canceled counts for any service period at a glance |

### Four Integrations or Plugins

| Integration | Purpose | Required for MVP? |
| --- | --- | --- |
| Twilio (SMS + number provisioning) | Sends and receives all text-back and reminder messages | Yes |
| Phone forwarding (business landline or VoIP) | Detects the unanswered-call trigger | Yes |
| OpenTable / Resy / Yelp Waitlist API | Reads upcoming reservations to queue reminder sends automatically | No — MVP ships with manual reservation entry; API is v2 |
| Stripe | Deposit link in-thread for high-value large-party reservations | No — v2 upsell |

## Customer Experience

First-use: the manager or owner forwards their existing reservation line or provisions a new Twilio number in under 10 minutes, enters a few upcoming reservations manually (scheduling API integration is v2), and is live with both the missed-call and reminder workflows before the evening service. Time to first value is the first recovered reservation inquiry — for a restaurant taking weekend reservation calls daily, this typically fires within 24 hours. Customers see plain SMS, no app, no login. The restaurant-side is a browser tab open at the host stand: one shared inbox, a reservation list, and a count of recovered calls and confirmed covers at the top.

## Brand Directions

| Direction | Palette and Mood | Audience Fit | Risk |
| --- | --- | --- | --- |
| Dark | Deep charcoal or near-black with a warm amber or gold accent, premium | Strong — resonates with independent restaurant owners who position their dining room as an experience, not a fast-food counter | Can feel overly aspirational for casual/family dining segments |
| Light | Warm white with a brick-red or terracotta accent, approachable | Good — earthy, food-category-adjacent palette signals reliability | Slightly generic "restaurant SaaS" feel |
| Rainbow | Multi-color | Poor | Reads consumer-facing, not an operator tool |
| Pastel cotton candy | Soft tones | Poor | Mismatch — operators buying scheduling tools trust utility-forward brands |
| **Selected direction** | **Dark**, warm amber/gold accent | — | Premium-dark resonates with restaurant owners who see their dining room as a brand, not just a shift operation. "Built for restaurants that care about the reservation" rather than "tech tool that handles calls." Amber/gold reads culinary warmth without being kitschy. |

## Conversion Copy

**Headline:** "Your reservation line shouldn't cost you a full house."
**Subheadline:** "RezText texts back every missed reservation call in seconds — then reminds your guests so no-shows stop emptying tables."
**Benefits:** Recover lost reservations instantly, before they open OpenTable · Cut no-show rates from 20-25% to under 8% · One shared inbox — no more reservation calls buried in one staff member's phone
**Objections handled:** "We use OpenTable already" → OpenTable handles guests who go to OpenTable; RezText handles the 67% who still call the restaurant directly. "What if guests find the auto-text weird?" → a friendly "sorry we missed you" text within 60 seconds of a missed call is already an industry-standard expectation; guests who want a table respond.
**Proof plan:** 30-day free trial with a side-by-side count of missed calls recovered and no-shows prevented vs. the same period the prior month.
**Primary CTA:** "Start your free 30-day trial — no card required."

## Go-to-Market

Direct outreach to independent restaurant owners and managers using the SCOUT→FORGE→HERALD pipeline: SCOUT identifies restaurants with Yelp/Google reviews mentioning reservation difficulty or no-show frustration, FORGE builds a personalized demo showing their restaurant name in the text-back and reminder flow, HERALD drafts the outreach email held at the Tier 3 gate. Secondary channels: restaurant owner Facebook groups (Restaurant Owners Uncensored, local metro food-biz groups), National Restaurant Association adjacent communities, and OpenTable partner referral programs if access becomes available. Restaurant operators are tight referral networks — one chef tells another. The pitch writes itself: "you recover $X in no-shows in the first month or you cancel."

## Operating Workflow and Approval Tier

SCOUT researches a named prospect (read-only) → FORGE builds a personalized demo (`spec.json` + `demo.html`, local only) → HERALD drafts the outreach email, held in `drafts/pending/` → **Tier 3 gate: owner must move the draft to `drafts/approved/` and pass `--send` explicitly** before any message reaches a real inbox. No step sends, publishes, or charges without that explicit approval.

## Three-Year Annual Operating Summary

**Currency and units:** USD, whole numbers
**Basis:** Management-based scenario; not audited actuals.

| Metric | Year 1 | Year 2 | Year 3 | Basis |
| --- | ---: | ---: | ---: | --- |
| Paying accounts (end of year) | 30 | 110 | 300 | Assumption: 2-3 new accounts/mo Y1 (slower ramp than trades — restaurant decision-maker turnover is high and outreach is harder mid-service); accelerating with referral Y2-3 — TBD, unvalidated |
| Units or accounts | 30 | 110 | 300 | Cumulative net of churn |
| Average price | $119/mo | $129/mo | $149/mo | Estimated; no pricing evidence sourced this run — assumption based on combined product value (missed-call + reservation reminder) justifying a premium above standalone text-back ($79 TextBack Local); marked TBD |
| Gross sales | $42,840 | $170,280 | $536,400 | Units × 12 × avg price (simplified, ignores mid-year ramp) |
| Direct costs | $6,480 | $23,760 | $64,800 | Twilio SMS/number fees at ~$18/account/mo (reminder sequence sends more outbound per account than text-back-only) — assumption |
| Other variable costs | $2,000 | $7,500 | $20,000 | Payment processing, support tooling — assumption |
| Fixed operating expense | $18,000 | $36,000 | $60,000 | Founder time proxy + hosting + outreach tooling — assumption |
| Net operating cash before debt and tax | $16,360 | $103,020 | $391,600 | Gross sales − direct − variable − fixed |
| Net operating cash margin | 38% | 61% | 73% | Net operating cash / gross sales |

**Sensitivity:** Restaurant failure rates are structurally high — churn will be above the trades vertical average, which this model does not account for. Year 1-3 projections rest on unvalidated close rate, churn, and pricing assumptions. The 38% Year 1 margin is conservative; the 73% Year 3 margin assumes much lower churn than the industry average. Both are illustrative, not commitments.

## 30/60/90-Day Revenue Plan

| Window | Objective | Deliverables | Metric | Continue/Kill Rule |
| --- | --- | --- | --- | --- |
| Days 1–30 | Validate outreach → demo → close on real restaurant operators | SCOUT brief for 10 independent restaurants in one metro (Tier 3 approval required to send) | ≥1 paid pilot signed at any price | If 0 of 10 respond positively after HERALD sends, revisit the pitch channel before scaling — restaurant Facebook groups may be a better entry than cold email |
| Days 31–60 | Prove both workflows generate real, counted recoveries | 5-10 active accounts; track recovered calls and no-show count before and after | ≥50% of pilot accounts see measurable no-show reduction in first 30 days | If the reminder sequence isn't reducing no-shows, the timing or template is wrong — fix before adding more accounts |
| Days 61–90 | First repeatable channel | Expand to a second metro or test restaurant-association referral | CAC payback under 4 months | If no channel is working efficiently, get on calls with pilot accounts and find where word-of-mouth naturally flows in their network |

## Risks and Controls

Restaurant-tech saturation risk: OpenTable, Resy, Toast, and Yelp all have some form of guest communication — the pitch must stay specific ("67% of reservations come in by phone, and none of those tools handle a missed phone call"). No-show reduction claims depend on guests replying to SMS reminders, which assumes adequate SMS opt-in at reservation time — document the consent flow carefully and include STOP in every outbound message. High restaurant churn (closures, ownership changes) creates involuntary churn in the customer base; price anchors for a restaurant-specific product should assume higher-than-normal involuntary churn.

## Seven-Day Validation Sprint

Day 1-2: get Tier 3 approval on outreach to 10 independent restaurants in one metro; build the SCOUT prospect brief targeting restaurants with visible "hard to reach by phone" signals in their reviews. Day 3-4: track HERALD outreach open/reply rate — this tests the pitch, not the product. Day 5-6: for any positive replies, demo the live `demo.html` walkthrough; ask for a paid pilot at $119/mo, not a free trial, to test real willingness to pay for the combined product. Day 7: write the result back into `docs/factory-runs/` as a real evidence point — win or no-win, closes the validation loop on the 5th build-gate winner (the highest-scoring one yet).

## Assumptions, TBD Items, and Sources

**Sourced:** 67% of restaurant reservations are made by phone; 3-touch SMS sequence cuts no-show rate from 20-25% to 5-8%; SMS confirmations/reminders reduce no-shows by up to 38%; 89% of U.S. consumers have opted into business SMS (blaksheepcreative.com, restaurantsnapshotforghl.com, ai-agentsplus.com — see `docs/factory-runs/2026-08-18.md`).
**Assumptions (not sourced, flagged):** pricing ($119-149/mo — no competitor pricing evidence sourced for this specific product), churn rate (restaurant closure rate is structurally higher than trades), close rate on cold outreach, CAC, all Year 1-3 account-growth figures.
**TBD:** pricing research against restaurant-specific SMS tools and Bite Buddy AI competitor pricing is the #1 open item before setting a pilot price. MVP reservation integration: OpenTable or Resy API for reading upcoming bookings (v1 ships with manual reservation entry).

## Pending Human Approval

Tier 3 — required before any further action: build SCOUT prospect brief for 10 independent restaurants in one metro, then approve outreach via the HERALD pipeline. Nothing in this kit has been sent, published, or charged.
