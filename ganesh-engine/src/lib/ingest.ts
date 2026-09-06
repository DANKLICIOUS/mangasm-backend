import { getServiceClient } from "./supabase-client.js";
import type { SignalInput } from "../types.js";

// Idempotent by (source, external_id) — the unique constraint from the
// migration. Re-running a collector against the same external event UPDATES
// the row in place (event_type/severity/payload reflect the latest observed
// state) rather than inserting a duplicate. `created_at` is intentionally
// left untouched on conflict so it keeps meaning "first observed", not
// "last observed" (constraint 3).
export async function ingestSignal(signal: SignalInput): Promise<void> {
  const client = getServiceClient();
  const { error } = await client.from("signals").upsert(
    {
      source: signal.source,
      external_id: signal.external_id,
      event_type: signal.event_type,
      severity: signal.severity,
      payload: signal.payload,
    },
    { onConflict: "source,external_id" },
  );
  if (error) {
    throw new Error(
      `ingestSignal failed (${signal.source}/${signal.external_id}): ${error.message}`,
    );
  }
}

export async function ingestSignals(signals: SignalInput[]): Promise<number> {
  if (signals.length === 0) return 0;
  const client = getServiceClient();
  const { error } = await client.from("signals").upsert(
    signals.map((s) => ({
      source: s.source,
      external_id: s.external_id,
      event_type: s.event_type,
      severity: s.severity,
      payload: s.payload,
    })),
    { onConflict: "source,external_id" },
  );
  if (error) throw new Error(`ingestSignals batch failed: ${error.message}`);
  return signals.length;
}
