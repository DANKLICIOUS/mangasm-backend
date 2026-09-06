import { getServiceClient } from "../lib/supabase-client.js";
import { ingestSignal } from "../lib/ingest.js";
import type { Severity } from "../types.js";

// Week 1 scope: a connectivity + round-trip-latency probe against the
// ganesh schema itself. Full infra metrics (CPU, connections, replication
// lag) need the separate Supabase Management API token and are a Week 2
// addition — documented in the README rather than implied here.
export async function collectSupabaseHealth(): Promise<number> {
  const client = getServiceClient();
  const start = Date.now();
  const { error, count } = await client.from("signals").select("id", { count: "exact", head: true });
  const latencyMs = Date.now() - start;

  if (error) {
    throw new Error(`Supabase health probe query failed: ${error.message}`);
  }

  let severity: Severity = "INFO";
  if (latencyMs > 2000) severity = "CRITICAL";
  else if (latencyMs > 500) severity = "WARNING";

  await ingestSignal({
    source: "supabase",
    // Bucketed to the minute: a repeated fast poll updates the same row
    // rather than accumulating one row per check, while still keeping a
    // real time series for the reasoner to trend against.
    external_id: `probe:${new Date().toISOString().slice(0, 16)}`,
    event_type: "db.latency_probe",
    severity,
    payload: { latency_ms: latencyMs, signals_row_count: count ?? null },
  });

  return 1;
}
