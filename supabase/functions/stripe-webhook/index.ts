// stripe-webhook
// Stripe calls this on subscription lifecycle events. Verifies the signature,
// then upserts billing_subscriptions; the 0007 trigger flips
// profiles.membership between 'free' and 'plus' from that state.
//
// Handled: customer.subscription.created / .updated / .deleted,
//          invoice.payment_failed (state refresh — Stripe also emits
//          subscription.updated with status past_due).
//
// Env (supabase secrets set …):
//   STRIPE_SECRET_KEY          sk_test_… / sk_live_…
//   STRIPE_WEBHOOK_SECRET      whsec_… from the Stripe webhook endpoint
//
// Deploy WITHOUT JWT verification (Stripe signs, it doesn't log in):
//   supabase functions deploy stripe-webhook --no-verify-jwt
// Then point a Stripe webhook endpoint at:
//   https://<project-ref>.functions.supabase.co/stripe-webhook

import Stripe from "https://esm.sh/stripe@14.25.0?target=denonext";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const stripe = new Stripe(Deno.env.get("STRIPE_SECRET_KEY")!, {
  apiVersion: "2023-10-16",
  httpClient: Stripe.createFetchHttpClient(),
});
const cryptoProvider = Stripe.createSubtleCryptoProvider();

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
);

async function userIdForCustomer(customerId: string): Promise<string | null> {
  const { data } = await supabase
    .from("billing_customers")
    .select("user_id").eq("stripe_customer_id", customerId).maybeSingle();
  return data?.user_id ?? null;
}

async function upsertSubscription(sub: Stripe.Subscription) {
  const userId =
    sub.metadata?.mangasm_user_id ??
    (await userIdForCustomer(sub.customer as string));
  if (!userId) {
    console.error(`No Mangasm user for Stripe customer ${sub.customer}`);
    return;
  }
  await supabase.from("billing_subscriptions").upsert({
    id: sub.id,
    user_id: userId,
    source: "stripe",
    status: sub.status,
    price_id: sub.items.data[0]?.price?.id ?? null,
    current_period_end: sub.current_period_end
      ? new Date(sub.current_period_end * 1000).toISOString()
      : null,
    cancel_at_period_end: sub.cancel_at_period_end,
  });
}

Deno.serve(async (req) => {
  const signature = req.headers.get("stripe-signature");
  if (!signature) return new Response("Missing signature", { status: 400 });

  const body = await req.text();
  let event: Stripe.Event;
  try {
    event = await stripe.webhooks.constructEventAsync(
      body,
      signature,
      Deno.env.get("STRIPE_WEBHOOK_SECRET")!,
      undefined,
      cryptoProvider,
    );
  } catch (err) {
    console.error("Signature verification failed", err);
    return new Response("Bad signature", { status: 400 });
  }

  switch (event.type) {
    case "customer.subscription.created":
    case "customer.subscription.updated":
    case "customer.subscription.deleted":
      await upsertSubscription(event.data.object as Stripe.Subscription);
      break;
    case "invoice.payment_failed": {
      const invoice = event.data.object as Stripe.Invoice;
      if (invoice.subscription) {
        const sub = await stripe.subscriptions.retrieve(
          invoice.subscription as string,
        );
        await upsertSubscription(sub);
      }
      break;
    }
    default:
      // Unhandled event types are fine — acknowledge so Stripe stops retrying.
      break;
  }

  return new Response(JSON.stringify({ received: true }), {
    headers: { "Content-Type": "application/json" },
  });
});
