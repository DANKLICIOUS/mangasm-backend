import { getServiceClient } from "./supabase-client.js";
import type { Severity, CollectorResult } from "../types.js";

// Logs a collector failure as its own signal row (audit trail of errors —
// intentionally NOT idempotent/upserted like business signals, since each
// failure is a distinct event). Escalates to ganesh.alerts on CRITICAL.
// Never throws: a failure to log health must not itself crash the caller
// (constraint 5 — fail-soft all the way down).
export async function logHealthSignal(
  source: string,
  severity: Severity,
  message: string,
  detail?: Record<string, unknown>,
): Promise<void> {
  try {
    const client = getServiceClient();
    await client.from("signals").upsert(
      {
        source,
        external_id: `health:${source}:${new Date().toISOString()}`,
        event_type: "collector_error",
        severity,
        payload: { message, ...detail },
      },
      { onConflict: "source,external_id" },
    );
    if (severity === "CRITICAL") {
      await client.from("alerts").insert({
        severity,
        message: `[${source}] ${message}`,
      });
    }
  } catch (err) {
    // Last resort — logging the failure must never itself throw.
    console.error(`logHealthSignal failed for ${source}:`, err);
  }
}

// Wraps a collector so external API failures never propagate as unhandled
// rejections: catch, log a WARNING signal, and return a clean result object
// instead (constraint 5).
export async function runCollectorSafely(
  source: string,
  fn: () => Promise<number>,
): Promise<CollectorResult> {
  try {
    const signalsIngested = await fn();
    return { source, ok: true, signalsIngested };
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    await logHealthSignal(source, "WARNING", `Collector run failed: ${message}`);
    return { source, ok: false, signalsIngested: 0, error: message };
  }
}
