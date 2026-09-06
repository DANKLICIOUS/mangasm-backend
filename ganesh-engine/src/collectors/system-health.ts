import { getServiceClient } from "../lib/supabase-client.js";
import { ingestSignals } from "../lib/ingest.js";
import type { SignalInput, Severity } from "../types.js";

// Staleness thresholds in minutes, per watched source. If no fresh signal
// has landed within this window, that collector is likely silently broken
// upstream (rate-limited, credential expired, API shape changed, etc.) even
// though nothing threw here.
const STALENESS_MINUTES: Record<string, number> = {
  stripe: 60,
  vercel: 60,
  appstore: 24 * 60,
  supabase: 30,
};

export async function collectSystemHealth(): Promise<number> {
  const client = getServiceClient();
  const signals: SignalInput[] = [];

  for (const [source, maxAgeMinutes] of Object.entries(STALENESS_MINUTES)) {
    const { data, error } = await client
      .from("signals")
      .select("created_at")
      .eq("source", source)
      .order("created_at", { ascending: false })
      .limit(1)
      .maybeSingle();

    if (error) {
      throw new Error(`system-health staleness check for ${source} failed: ${error.message}`);
    }

    const ageMinutes = data ? (Date.now() - new Date(data.created_at as string).getTime()) / 60000 : Infinity;

    let severity: Severity = "INFO";
    if (ageMinutes > maxAgeMinutes * 3) severity = "CRITICAL";
    else if (ageMinutes > maxAgeMinutes) severity = "WARNING";

    signals.push({
      source: "system",
      // Bucketed hourly per watched source.
      external_id: `staleness:${source}:${new Date().toISOString().slice(0, 13)}`,
      event_type: "collector_staleness",
      severity,
      payload: {
        watched_source: source,
        age_minutes: Number.isFinite(ageMinutes) ? Math.round(ageMinutes) : null,
        threshold_minutes: maxAgeMinutes,
      },
    });
  }

  return ingestSignals(signals);
}
