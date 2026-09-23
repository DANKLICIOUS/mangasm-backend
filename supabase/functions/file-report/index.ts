// file-report
// Files a report AND applies the "spite-report shield": if the reporter blocked
// or declined the reported member within the last 2 hours, the report is marked
// timing_flag = true so it is deprioritised before human review.
//
// Called by an authenticated client; uses the caller's JWT so RLS still applies
// to the SELECTs, and the service role to set the timing_flag the client cannot.
//
// Deploy: supabase functions deploy file-report

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders } from "../_shared/cors.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get("Authorization") ?? "";
    const userClient = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      { global: { headers: { Authorization: authHeader } } },
    );

    const { data: userData } = await userClient.auth.getUser();
    const reporterId = userData.user?.id;
    if (!reporterId) {
      return new Response(JSON.stringify({ error: "unauthorized" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const { reportedId, reason, details, contentType, contentId } = await req.json();
    if (!reportedId || !reason) {
      return new Response(JSON.stringify({ error: "reportedId and reason required" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const admin = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    // Did the reporter block the reported member in the last 2 hours?
    const twoHoursAgo = new Date(Date.now() - 2 * 60 * 60 * 1000).toISOString();
    const { data: recentBlock } = await admin
      .from("blocks")
      .select("created_at")
      .eq("blocker_id", reporterId)
      .eq("blocked_id", reportedId)
      .gte("created_at", twoHoursAgo)
      .maybeSingle();

    const timingFlag = !!recentBlock;

    const { data: report, error } = await admin
      .from("reports")
      .insert({
        reporter_id: reporterId,
        reported_id: reportedId,
        reason,
        details: details ?? null,
        content_type: contentType ?? null,
        content_id: contentId ?? null,
        timing_flag: timingFlag,
      })
      .select()
      .single();

    if (error) throw error;

    return new Response(JSON.stringify({ report, timingFlag }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (err) {
    return new Response(JSON.stringify({ error: String(err) }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
