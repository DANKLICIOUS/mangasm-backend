// Shared helpers for the api/collect/* routes. Filename starts with `_` so
// Vercel's file-system router treats it as a module, not a route.

// Vercel Cron automatically sends `Authorization: Bearer $CRON_SECRET` on
// cron-triggered requests once CRON_SECRET is set as a project env var —
// this check doubles as cron auth and manual/debug-call auth with the same
// secret, no separate mechanism needed.
export function requireCronAuth(req: Request): Response | null {
  const auth = req.headers.get("authorization");
  const expected = process.env.CRON_SECRET;
  if (!expected || auth !== `Bearer ${expected}`) {
    return jsonResponse({ error: "unauthorized" }, 401);
  }
  return null;
}

export function jsonResponse(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}
