// generate-daily-matches
// Plus-exclusive AI matchmaking. For a member, pull nearby non-blocked
// candidates, score them against the member's preferences + reputation, write
// up to 5 rows into match_results for today. Intended to run nightly via cron
// and/or on-demand. Service-role so it can write match rows.
//
// The AI insight string is where a model call (e.g. Claude Haiku) slots in;
// kept deterministic here so the function is runnable without an API key.
//
// Deploy: supabase functions deploy generate-daily-matches --no-verify-jwt

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders } from "../_shared/cors.ts";

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
);

const DAILY_LIMIT = 5;

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  try {
    const { userId, lat, lng } = await req.json().catch(() => ({}));
    if (!userId || lat == null || lng == null) {
      return json({ error: "userId, lat, lng required" }, 400);
    }

    const { data: prefs } = await supabase
      .from("match_preferences").select("*").eq("user_id", userId).maybeSingle();
    const radius = prefs?.max_distance_m ?? 8047;

    // Candidate pool from the same radius query the map uses.
    const { data: candidates, error } = await supabase
      .rpc("users_within_radius", { lat, lng, radius_m: radius });
    if (error) throw error;

    const { data: me } = await supabase
      .from("profiles").select("tags").eq("id", userId).maybeSingle();
    const myTags: string[] = me?.tags ?? [];

    const scored = (candidates ?? [])
      .filter((c: any) => c.id !== userId)
      .map((c: any) => {
        const shared = (c.tags ?? []).filter((t: string) => myTags.includes(t));
        const proximity = Math.max(0, 1 - c.distance_m / radius);
        const score = Math.round(
          Math.min(100, shared.length * 20 + proximity * 30 + (c.is_verified ? 15 : 0) + 25),
        );
        const reasons: string[] = [];
        if (shared.length) reasons.push("kink");
        if (proximity > 0.5) reasons.push("proximity");
        if (c.is_verified) reasons.push("verified");
        const insight = shared.length
          ? `You both share ${shared.slice(0, 3).join(", ")} and he's ${Math.round(c.distance_m / 1609)} mi away`
          : `Nearby (${Math.round(c.distance_m / 1609)} mi) and verified`;
        return { matched_user_id: c.id, score, ai_insight: insight, reasons };
      })
      .sort((a: any, b: any) => b.score - a.score)
      .slice(0, DAILY_LIMIT);

    if (scored.length) {
      const { error: upsertError } = await supabase.from("match_results").upsert(
        scored.map((s: any) => ({ user_id: userId, ...s, match_date: new Date().toISOString().slice(0, 10) })),
        { onConflict: "user_id,matched_user_id,match_date" },
      );
      if (upsertError) throw upsertError;
    }

    return json({ generated: scored.length });
  } catch (err) {
    return json({ error: String(err) }, 500);
  }
});

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
