export const config = { runtime: "edge" };

import { requireCronAuth, jsonResponse } from "../_shared.js";
import { runCollectorSafely } from "../../src/lib/health.js";
import { collectSupabaseHealth } from "../../src/collectors/supabase-health.js";

export default async function handler(req: Request): Promise<Response> {
  const unauthorized = requireCronAuth(req);
  if (unauthorized) return unauthorized;

  const result = await runCollectorSafely("supabase", collectSupabaseHealth);
  return jsonResponse(result, result.ok ? 200 : 207);
}
