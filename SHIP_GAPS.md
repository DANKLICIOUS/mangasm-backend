# SHIP_GAPS.md — Production Deployment & Human Readiness Checklist

This document tracks all remaining **human-required steps** to take Mangasm backend, Ganesh Engine, and the Ecosystem Builder live to production. 

AI agents cannot (and must not) manage real credit cards, bank accounts, production credentials, or live database modifications. Complete these steps in order before public launch.

---

## 1. Supabase Production Database & Migrations

- [ ] **Confirm Target Project Reference**:
  - The live Mangasm project is `hcpzbxplnkyythzwkovy`.
  - Confirm whether `ganesh-engine` will share this project under its isolated `ganesh` schema, or if it will run in a dedicated standalone Supabase project (recommended if strict cross-portfolio service-role isolation is desired).
- [ ] **Apply Canonical Database Migrations**:
  ```bash
  # Ensure Supabase CLI is linked to production:
  supabase link --project-ref <PROJECT_REF>

  # Push all 9 canonical migrations:
  supabase db push
  ```
- [ ] **Apply Ganesh Schema (if using shared or dedicated DB)**:
  ```bash
  psql "$DATABASE_URL" -f ganesh-engine/migrations/001_create_ganesh_schema.sql
  ```
- [ ] **Expose `ganesh` Schema in PostgREST**:
  - Open Supabase Dashboard → **Project Settings** → **API** → **Exposed schemas**.
  - Add `ganesh` to the list alongside `public` so `supabase-js` service-role calls can query `ganesh.*` via REST API.

---

## 2. Supabase Edge Functions & Production Secrets

- [ ] **Set Hosted Function Secrets**:
  ```bash
  supabase secrets set \
    STRIPE_SECRET_KEY="sk_live_..." \
    STRIPE_WEBHOOK_SECRET="whsec_..." \
    STRIPE_PRICE_MONTHLY="price_..." \
    STRIPE_PRICE_QUARTERLY="price_..." \
    STRIPE_PAYMENT_METHOD_CONFIGURATION="pmc_..." \
    ADMIN_DASHBOARD_TOKEN="<random-secure-string>" \
    CHECKOUT_SUCCESS_URL="https://mangasm.app/plus/success" \
    CHECKOUT_CANCEL_URL="https://mangasm.app/plus"
  ```
- [ ] **Deploy Edge Functions**:
  ```bash
  # Deploy client-facing authed functions (JWT verified):
  supabase functions deploy recalculate-score
  supabase functions deploy file-report
  supabase functions deploy generate-daily-matches
  supabase functions deploy delete-account
  supabase functions deploy stripe-checkout

  # Deploy public webhook & dashboard endpoints (--no-verify-jwt):
  supabase functions deploy stripe-webhook --no-verify-jwt
  supabase functions deploy revenue-metrics --no-verify-jwt
  ```

---

## 3. Stripe Live Setup & Webhooks

- [ ] **Activate Live Mode**: Complete KYC and link payout bank account at [dashboard.stripe.com](https://dashboard.stripe.com).
- [ ] **Recreate Live Products & Prices**:
  - Product: `Mangasm+`
  - Monthly Price: `$9.99 / month`
  - 3-Month Price: `$24.99 / 3 months`
  - Update `STRIPE_PRICE_MONTHLY` and `STRIPE_PRICE_QUARTERLY` secrets with live price IDs (`price_...`).
- [ ] **Configure Stripe Webhook Endpoint**:
  - Destination URL: `https://<PROJECT_REF>.supabase.co/functions/v1/stripe-webhook`
  - Events to listen for:
    - `customer.subscription.created`
    - `customer.subscription.updated`
    - `customer.subscription.deleted`
    - `invoice.payment_failed`
  - Copy Signing Secret (`whsec_...`) into `STRIPE_WEBHOOK_SECRET` Supabase secret.
- [ ] **Configure Dunning & Smart Retries**:
  - Enable Stripe Smart Retries in Dashboard → Settings → Billing → Subscriptions and emails.

---

## 4. Ganesh Engine Deployment (Vercel)

- [ ] **Deploy `ganesh-engine` to Vercel**:
  - Set root directory to `ganesh-engine` or link the repository.
- [ ] **Set Vercel Environment Variables**:
  - `SUPABASE_URL`: Production Supabase URL
  - `SUPABASE_SERVICE_ROLE_KEY`: Secret service-role key
  - `STRIPE_SECRET_KEY`: `sk_live_...`
  - `APPSTORE_CONNECT_KEY_ID`: App Store Connect API Key ID
  - `APPSTORE_CONNECT_ISSUER_ID`: App Store Connect Issuer UUID
  - `APPSTORE_CONNECT_PRIVATE_KEY`: Raw contents of `.p8` key file
  - `APPSTORE_APP_ID`: Mangasm Apple App ID (numeric)
  - `VERCEL_API_TOKEN`: Vercel Personal Access Token
  - `VERCEL_PROJECT_ID`: Target Vercel Project ID
  - `VERCEL_TEAM_ID`: (Optional) Team ID if applicable
  - `CRON_SECRET`: Random 32+ character string for authorizing Vercel Cron and manual triggers
- [ ] **Verify Cron Schedule**:
  - Review `vercel.json` cron intervals. Sub-daily cron execution requires a Vercel Pro plan (Hobby permits 1/day).

---

## 5. Apple App Store & Client App Alignment

- [ ] **Client App Configuration**:
  - Confirm `Config.xcconfig` in the iOS repository points to the live `SUPABASE_URL` and `SUPABASE_ANON_KEY`.
  - Verify service-role key is nowhere in client app binaries.
- [ ] **Guideline 1.2 UGC Safety Verification**:
  - Ensure iOS registration flow records EULA agreement into `terms_acceptances`.
  - Ensure message and event UI report buttons pass `reportedId`, `reason`, `contentType`, and `contentId` to `file-report`.
- [ ] **Guideline 4.3(b) Appeal & App Store Metadata**:
  - Use the resolution copy in `docs/APP_STORE_RESOLUTION.md` when responding to App Store Review.
  - Position metadata around safety, map feed, events, and community reputation.
- [ ] **Apple In-App Purchases (IAP)**:
  - Complete App Store Connect Agreements, Tax, and Banking forms for Apple IAP payouts.

---

## 6. Ecosystem Builder & Email Deliverability (slay.llc / ganesh.guru)

- [ ] **Resend DNS Setup**:
  - Verify sending domain `ganesh.guru` in Resend by adding SPF, DKIM, and DMARC DNS records.
- [ ] **Configure CAN-SPAM Sender Identity**:
  - Ensure `FROM_EMAIL` (e.g. `Mangasm Enterprises <hello@ganesh.guru>`) and a real `PHYSICAL_ADDRESS` (street/box) are configured in `ecosystem-builder/.env`.
- [ ] **Warmup & Daily Send Cap**:
  - Maintain `DAILY_SEND_CAP=10` on initial cold outreach and scale gradually by ~20% weekly.
