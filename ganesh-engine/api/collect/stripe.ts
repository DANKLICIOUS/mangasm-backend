export const config = { runtime: "edge" };

import { requireCronAuth, jsonResponse } from "../_shared.js";
import { runCollectorSafely } from "../../src/lib/health.js";
import { collectStripe } from "../../src/collectors/stripe.js";

export default async function handler(req: Request): Promise<Response> {
  const unauthorized = requireCronAuth(req);
  if (unauthorized) return unauthorized;

  const result = await runCollectorSafely("stripe", collectStripe);
  return jsonResponse(result, result.ok ? 200 : 207);
}
