import { ingestSignals } from "../lib/ingest.js";
import type { SignalInput, Severity } from "../types.js";

const VERCEL_API = "https://api.vercel.com";

function classifySeverity(state: string): Severity {
  if (state === "ERROR" || state === "CANCELED") return "WARNING";
  return "INFO";
}

// Deployment UIDs are unique and stable -> the natural idempotency key.
export async function collectVercel(): Promise<number> {
  const token = process.env.VERCEL_API_TOKEN;
  const projectId = process.env.VERCEL_PROJECT_ID;
  if (!token || !projectId) {
    throw new Error("VERCEL_API_TOKEN and VERCEL_PROJECT_ID must be set");
  }
  const teamId = process.env.VERCEL_TEAM_ID; // optional

  const params = new URLSearchParams({ projectId, limit: "20" });
  if (teamId) params.set("teamId", teamId);

  const res = await fetch(`${VERCEL_API}/v6/deployments?${params.toString()}`, {
    headers: { Authorization: `Bearer ${token}` },
  });
  if (!res.ok) {
    throw new Error(`Vercel deployments fetch failed: ${res.status} ${await res.text()}`);
  }

  const data = (await res.json()) as {
    deployments: Array<{ uid: string; state: string; created: number; url: string; target?: string }>;
  };

  const signals: SignalInput[] = data.deployments.map((d) => ({
    source: "vercel",
    external_id: d.uid,
    event_type: `deployment.${d.state.toLowerCase()}`,
    severity: classifySeverity(d.state),
    payload: { url: d.url, target: d.target ?? null, created: d.created, state: d.state },
  }));

  return ingestSignals(signals);
}
