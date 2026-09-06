import { runCollectorSafely } from "../lib/health.js";
import { collectStripe } from "./stripe.js";
import { collectAppStore } from "./appstore.js";
import { collectVercel } from "./vercel.js";
import { collectSupabaseHealth } from "./supabase-health.js";
import { collectSystemHealth } from "./system-health.js";
import type { CollectorResult } from "../types.js";

export async function runAllCollectors(): Promise<CollectorResult[]> {
  // The 4 data collectors are independent -> run concurrently. Each is
  // wrapped in runCollectorSafely so one failure never blocks the others
  // (fail-soft, constraint 5).
  const dataResults = await Promise.all([
    runCollectorSafely("stripe", collectStripe),
    runCollectorSafely("appstore", collectAppStore),
    runCollectorSafely("vercel", collectVercel),
    runCollectorSafely("supabase", collectSupabaseHealth),
  ]);

  // Runs after the others (not concurrently with them) so its staleness
  // check reflects what this same run just wrote, not stale prior state.
  const systemResult = await runCollectorSafely("system", collectSystemHealth);

  return [...dataResults, systemResult];
}

export {
  collectStripe,
  collectAppStore,
  collectVercel,
  collectSupabaseHealth,
  collectSystemHealth,
};
