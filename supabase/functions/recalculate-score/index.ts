// recalculate-score
// Recomputes a member's reputation score from observed behaviour and caches it
// in public.reputation_scores. Intended to run on a schedule (pg_cron / cron
// trigger) and/or be invoked for a single user after a relevant event.
//
// This is a STUB with the real scoring shape wired up. Tune the weights as the
// product matures. Runs with the service-role key so it can write scores
// (clients cannot — see RLS in 0002_rls_policies.sql).
//
// No Postgres trigger calls this function after vouches/reports/blocks/events.
// Invoke on a schedule (empty body → sweep) or on-demand `{ userId }`.
// Cached `tier` is what 0009 uses to unlock ProfileStyle themes.
//
// Local run:  supabase functions serve recalculate-score
// Deploy:     supabase functions deploy recalculate-score --no-verify-jwt

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders } from "../_shared/cors.ts";

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
);

function tierFor(score: number): string {
  if (score >= 85) return "verified";
  if (score >= 65) return "reliable";
  if (score >= 40) return "building";
  return "new";
}

async function scoreForUser(userId: string): Promise<number> {
  // Positive signals
  const { count: vouchCount } = await supabase
    .from("vouches").select("*", { count: "exact", head: true })
    .eq("vouchee_id", userId);

  const { count: eventsHosted } = await supabase
    .from("events").select("*", { count: "exact", head: true })
    .eq("host_id", userId);

  // Negative signals — reports that survived the spite-report shield only.
  const { count: validReports } = await supabase
    .from("reports").select("*", { count: "exact", head: true })
    .eq("reported_id", userId).eq("timing_flag", false);

  const { count: blockCount } = await supabase
    .from("blocks").select("*", { count: "exact", head: true })
    .eq("blocked_id", userId);

  const base = 50;
  const score =
    base +
    (vouchCount ?? 0) * 3 +
    (eventsHosted ?? 0) * 2 -
    (validReports ?? 0) * 8 -
    (blockCount ?? 0) * 1;

  return Math.max(0, Math.min(100, Math.round(score)));
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { userId } = await req.json().catch(() => ({ userId: null }));

    // Single user, or sweep everyone when no userId is given.
    const ids: string[] = [];
    if (userId) {
      ids.push(userId);
    } else {
      const { data } = await supabase.from("profiles").select("id");
      for (const row of data ?? []) ids.push(row.id);
    }

    for (const id of ids) {
      const score = await scoreForUser(id);
      await supabase.from("reputation_scores").upsert({
        user_id: id,
        score,
        tier: tierFor(score),
        updated_at: new Date().toISOString(),
      });
    }

    return new Response(JSON.stringify({ updated: ids.length }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (err) {
    return new Response(JSON.stringify({ error: String(err) }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
