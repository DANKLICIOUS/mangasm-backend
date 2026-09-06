import { ingestSignals } from "../lib/ingest.js";
import type { SignalInput, Severity } from "../types.js";

const STRIPE_API = "https://api.stripe.com/v1";

function classifySeverity(eventType: string): Severity {
  if (eventType === "charge.dispute.created" || eventType === "radar.early_fraud_warning.created") {
    return "CRITICAL";
  }
  if (
    eventType === "invoice.payment_failed" ||
    eventType === "customer.subscription.deleted" ||
    eventType === "charge.failed"
  ) {
    return "WARNING";
  }
  return "INFO";
}

// Pulls the last 24h of Stripe Events. Stripe's own event IDs (`evt_...`)
// are globally unique and stable, so they're used directly as the
// idempotency key — a re-run naturally upserts rather than duplicates.
export async function collectStripe(): Promise<number> {
  const key = process.env.STRIPE_SECRET_KEY;
  if (!key) throw new Error("STRIPE_SECRET_KEY is not set");

  const since = Math.floor(Date.now() / 1000) - 24 * 60 * 60;
  const params = new URLSearchParams({ limit: "100", "created[gte]": String(since) });

  const res = await fetch(`${STRIPE_API}/events?${params.toString()}`, {
    headers: { Authorization: `Bearer ${key}` },
  });
  if (!res.ok) {
    throw new Error(`Stripe events fetch failed: ${res.status} ${await res.text()}`);
  }

  const data = (await res.json()) as {
    data: Array<{ id: string; type: string; created: number; data: unknown }>;
  };

  const signals: SignalInput[] = data.data.map((event) => ({
    source: "stripe",
    external_id: event.id,
    event_type: event.type,
    severity: classifySeverity(event.type),
    payload: { created: event.created, object: event.data },
  }));

  return ingestSignals(signals);
}
