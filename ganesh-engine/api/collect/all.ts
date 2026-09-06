export const config = { runtime: "edge" };

import { requireCronAuth, jsonResponse } from "../_shared.js";
import { runAllCollectors } from "../../src/collectors/index.js";

export default async function handler(req: Request): Promise<Response> {
  const unauthorized = requireCronAuth(req);
  if (unauthorized) return unauthorized;

  const results = await runAllCollectors();
  const anyFailed = results.some((r) => !r.ok);

  // 207 Multi-Status: some collectors failed but the run itself completed
  // cleanly (each failure was caught, logged, and reported — never thrown).
  return jsonResponse({ results }, anyFailed ? 207 : 200);
}
