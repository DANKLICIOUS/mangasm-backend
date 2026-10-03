# AGENTS.md — shared context for any AI working in this repo

> This file is the **handshake** between AI assistants (Claude Code, Grok CLI,
> and the no-code agent tools). Read it first, every session. It is the shared
> brain so two different models stay in sync through the repo instead of talking
> to each other directly.

## Who owns what

- **Owner:** `gothamgodzilla` ("Mangasm Enterprises").
- **This repo:** `gothamgodzilla/mangasm-backend` — the Supabase data + server
  layer for Mangasm. See `README.md` and `MANGASM_MAP.md` for specifics.

## The empire (6 ventures)

| Venture | Domain | What it is | Tier |
|---------|--------|-----------|------|
| **Luxury Mastermind AI Ecosystem Builder** | Ganesh.guru (demo) + slay.llc (outreach) | Productized AI agency: scrape a business → auto-build its AI ecosystem → sell turnkey $499/$1499+ | ⭐ KEYSTONE |
| **Helping.LLC** | Helping.LLC | Handyman/task service, needs customers; template guinea pig | 🟢 fastest revenue |
| **Mangasm** | Mangasm.app | 18+ LGBTQ+ social/dating (Supabase, this repo) | 🟢 built |
| **Nostalgia** | Nostalgia.sh | AI astrology life-coach (animated Ganesh persona) | 🟢 shippable |
| **Rambo INK** | rambo.ink | Autonomous tattoo booth, robot arm + artist | 🔴 moonshot |
| **Diabolic** | — | Original dark ARPG in Unreal (see legal note) | 🔴 moonshot |

Full per-venture plans, priority, and Grok prompts: **`docs/EMPIRE.md`**.

## The agent crew (`.claude/agents/`)

Named workers, one job each — dispatch by name (GANESH-orchestrator pattern):

| Agent | Job | Hard limit |
|-------|-----|-----------|
| **ganesh** | Orchestrator: plans, dispatches, holds approval gates | Stops at Tier 3 (public/financial/outreach) until owner approves |
| **scout** | Research: prospects, markets, pricing, competitors | Gathers only; never contacts anyone |
| **forge** | Builder: demos, spec.json, generated artifacts | Local builds only; hosting/deploying = Tier 3 |
| **herald** | Pitch/outreach drafts (slay.llc) | DRAFTS only; never sends; CAN-SPAM-shaped by default |
| **warden** | Mangasm trust & safety analysis | Recommends actions; never bans/deletes itself |
| **oracle** | Nostalgia daily readings (soul layer) | Interprets computed facts; never calculates astrology |
| **ledger** | Metrics, $349/day target, run-record hygiene | Never touches real balances or the private net-worth file |

Full strategy, tool choices, and starter tasks live in **`docs/EMPIRE.md`**.

## Operating rules for AI agents

1. **Plan in plain English first**, then the exact steps/code, then how to test
   and what "done" looks like. The owner is semi-technical and wants the
   simplest thing that works.
2. **Never mix data between brands.** One workspace/project per brand.
3. **Never commit real secrets.** Keys live in gitignored files
   (`Config.xcconfig`, `supabase/.env.local`). See the Security TODO in
   `MANGASM_MAP.md` — rotate leaked keys before shipping new features.
4. **The model is the brain; the tool is the body.** Grok 4.5 (xAI) is the
   default model plugged into every no-code tool (AnythingLLM, Sim, Dify).
5. **Commit small, push often.** The next AI only sees what you pushed.

## How the two terminals stay linked

```
CLAUDE (web) ──push──► GitHub repo ◄──push── GROK CLI (local)
                          │
             AGENTS.md + docs/EMPIRE.md = shared context
```

- Claude Code (web) works on branch `claude/grok-empire-systems-setup-x4bdg3`.
- Grok CLI clones the same repo, reads this file + `docs/EMPIRE.md`, and
  continues. Whoever pushes, the other pulls. That is the whole link.

## Cursor Cloud specific instructions

Local proof of this repo is the same path as `.github/workflows/db-ci.yml`:
PostgreSQL 16 + PostGIS + pgvector, not the hosted Supabase project and not
`supabase start` (that needs Docker and a linked project).

- Install once: `bash .cursor/install.sh` (Postgres packages + `npm ci` in
  `ganesh-engine`). Cloud Agents run this from the environment install step.
- Database: `bash .cursor/start.sh` starts a trust-auth cluster as user `pgci`
  on port **5433**, socket `/tmp`, data dir `/var/lib/mangasm-pg`, then applies
  `supabase/tests/shim.sql` and `supabase/migrations/*.sql`. Re-running it is
  safe. Connect with:
  `psql -h /tmp -p 5433 -U pgci -d postgres`
- Smoke test (inserts fixture rows; run on a fresh cluster, not twice):
  `psql -h /tmp -p 5433 -U pgci -d postgres -v ON_ERROR_STOP=1 -f supabase/tests/ci_smoke.sql`
  To reset first: stop the cluster, `sudo rm -rf /var/lib/mangasm-pg`, then
  start again.
- Ganesh engine check: `npm run typecheck --prefix ganesh-engine`
- Hosted keys (`supabase/.env.local`, Stripe, admin tokens) are not required
  for the local cluster or the smoke test. Never commit them.
