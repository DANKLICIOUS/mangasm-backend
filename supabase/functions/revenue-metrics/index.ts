// revenue-metrics
// Read-only revenue snapshot for the /admin/revenue dashboard: MRR, active
// subscriptions by plan, currently-failing payments, and 8 weekly buckets of
// new / canceled / failed activity. Numbers come straight from Stripe;
// billing_subscriptions supplies the membership cross-check.
//
// Auth: header  x-admin-token: <ADMIN_DASHBOARD_TOKEN>  (no Supabase JWT —
// this is an owner-only endpoint, deploy with --no-verify-jwt).
//
// Env (supabase secrets set …):
//   STRIPE_SECRET_KEY       sk_test_… / sk_live_…
//   ADMIN_DASHBOARD_TOKEN   any long random string; same value goes in the
//                           dashboard's settings panel
//
// Deploy: supabase functions deploy revenue-metrics --no-verify-jwt

import Stripe from "https://esm.sh/stripe@14.25.0?target=denonext";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const stripe = new Stripe(Deno.env.get("STRIPE_SECRET_KEY")!, {
  apiVersion: "2023-10-16",
  httpClient: Stripe.createFetchHttpClient(),
});

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
);

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "x-admin-token, content-type",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
};

const WEEKS = 8;
const WEEK_MS = 7 * 24 * 60 * 60 * 1000;

// Normalize any recurring price to a monthly amount in cents
// (e.g. $24.99 / 3 months → 833).
function monthlyCents(item: Stripe.SubscriptionItem): number {
  const price = item.price;
  if (!price?.unit_amount || !price.recurring) return 0;
  const { interval, interval_count = 1 } = price.recurring;
  const count = interval_count || 1;
  const months = interval === "year" ? 12 * count
    : interval === "month" ? count
    : interval === "week" ? count / 4.345
    : count / 30.44; // day
  return Math.round(price.unit_amount / months);
}

async function listAll<T>(
  page: (params: Record<string, unknown>) => Promise<Stripe.ApiList<T>>,
  params: Record<string, unknown>,
  cap = 1000,
): Promise<T[]> {
  const out: T[] = [];
  let starting_after: string | undefined;
  while (out.length < cap) {
    const res = await page({ ...params, limit: 100, starting_after });
    out.push(...res.data);
    if (!res.has_more) break;
    starting_after = (res.data[res.data.length - 1] as { id: string }).id;
  }
  return out;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  const token = req.headers.get("x-admin-token");
  const expected = Deno.env.get("ADMIN_DASHBOARD_TOKEN");
  if (!expected || token !== expected) {
    return new Response(JSON.stringify({ error: "Unauthorized" }), {
      status: 401,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const now = Date.now();
  const windowStart = now - WEEKS * WEEK_MS;
  const sinceUnix = Math.floor(windowStart / 1000);

  const [active, trialing, canceled, invoices] = await Promise.all([
    listAll<Stripe.Subscription>(
      (p) => stripe.subscriptions.list(p as Stripe.SubscriptionListParams),
      { status: "active" },
    ),
    listAll<Stripe.Subscription>(
      (p) => stripe.subscriptions.list(p as Stripe.SubscriptionListParams),
      { status: "trialing" },
    ),
    listAll<Stripe.Subscription>(
      (p) => stripe.subscriptions.list(p as Stripe.SubscriptionListParams),
      { status: "canceled", created: { gte: sinceUnix } },
    ),
    listAll<Stripe.Invoice>(
      (p) => stripe.invoices.list(p as Stripe.InvoiceListParams),
      { created: { gte: sinceUnix } },
    ),
  ]);

  const live = [...active, ...trialing];
  const mrrCents = live.reduce(
    (sum, s) => sum + s.items.data.reduce((a, i) => a + monthlyCents(i), 0),
    0,
  );

  const byPlan: Record<string, number> = {};
  for (const s of live) {
    const nick = s.items.data[0]?.price?.nickname ??
      s.items.data[0]?.price?.id ?? "unknown";
    byPlan[nick] = (byPlan[nick] ?? 0) + 1;
  }

  const pastDue = await listAll<Stripe.Subscription>(
    (p) => stripe.subscriptions.list(p as Stripe.SubscriptionListParams),
    { status: "past_due" },
  );

  // A failed payment = an invoice that has been attempted but is not paid.
  const failedInvoices = invoices.filter((inv) =>
    inv.attempt_count > 0 && !inv.paid &&
    (inv.status === "open" || inv.status === "uncollectible")
  );

  const weeks = Array.from({ length: WEEKS }, (_, i) => {
    const start = windowStart + i * WEEK_MS;
    const end = start + WEEK_MS;
    const inWeek = (unix: number | null | undefined) => {
      if (!unix) return false;
      const ms = unix * 1000;
      return ms >= start && ms < end;
    };
    return {
      week_start: new Date(start).toISOString().slice(0, 10),
      new_subs: live.concat(canceled).filter((s) => inWeek(s.created)).length,
      canceled: canceled.filter((s) => inWeek(s.canceled_at)).length,
      failed_payments: failedInvoices.filter((i) => inWeek(i.created)).length,
    };
  });

  // Cross-check: what the app itself believes.
  const { count: plusMembers } = await supabase
    .from("profiles")
    .select("*", { count: "exact", head: true })
    .in("membership", ["plus", "plus_plus"]);

  const stripeSecret = Deno.env.get("STRIPE_SECRET_KEY") ?? "";

  return new Response(
    JSON.stringify({
      generated_at: new Date(now).toISOString(),
      livemode: !stripeSecret.startsWith("sk_test"),
      mrr_cents: mrrCents,
      active_subscriptions: live.length,
      by_plan: byPlan,
      past_due: pastDue.length,
      failed_payments_open: failedInvoices.length,
      plus_members_in_db: plusMembers ?? 0,
      weeks,
    }),
    { headers: { ...corsHeaders, "Content-Type": "application/json" } },
  );
});
